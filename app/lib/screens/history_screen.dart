import 'dart:io';

import 'package:flutter/material.dart';

import '../models/app_exception.dart';
import '../models/scan_record.dart';
import '../services/storage_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/error_view.dart';
import 'results_screen.dart';

/// Screen displaying past banana scan records saved in local storage.
///
/// Per §7.1: One tap away from the camera screen.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    this.storageService,
    super.key,
  });

  /// Optional storage service instance. If null, loads empty state.
  final StorageService? storageService;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<ScanRecord> _records = [];
  bool _isLoading = true;

  /// Non-null when loading history failed (A16).
  AppException? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final service = widget.storageService;
    if (service == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await service.getRecords();
      if (mounted) {
        setState(() {
          _records = items;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = const StorageException();
        });
      }
    }
  }

  Future<void> _deleteItem(String id) async {
    final service = widget.storageService;
    if (service != null) {
      try {
        await service.deleteRecord(id);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Couldn\'t delete this scan — please try again.'),
            ),
          );
        }
        return;
      }
    }
    await _loadHistory();
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Scan History?'),
        content: const Text(
          'This will delete all past scan records from your phone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: DesignTokens.confidenceLow,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.storageService != null) {
      try {
        await widget.storageService!.clearRecords();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Couldn\'t clear your history — please try again.'),
            ),
          );
        }
        return;
      }
      await _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan History'),
        actions: [
          if (_records.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear All',
              onPressed: _clearAll,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: DesignTokens.primary),
            )
          : _error != null
              ? ErrorView(
                  exception: _error!,
                  onRetry: _loadHistory,
                  retryLabel: 'Try Again',
                )
              : _records.isEmpty
                  ? _buildEmptyState(context)
                  : _buildRecordList(context),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(DesignTokens.spacingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
              child: Image.asset(
                'assets/images/logo.png',
                width: DesignTokens.logoMedium * 1.5,
                height: DesignTokens.logoMedium * 1.5,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.history_toggle_off_rounded,
                  size: 64,
                  color: DesignTokens.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: DesignTokens.spacingLarge),
            Text(
              'No Saved Scans Yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: DesignTokens.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: DesignTokens.spacingSmall),
            const Text(
              'Your past banana classification results will be saved here so you can review them anytime.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: DesignTokens.bodyTextSize,
                color: DesignTokens.textSecondary,
              ),
            ),
            const SizedBox(height: DesignTokens.spacingExtraLarge),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('Scan a Banana Now'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordList(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(DesignTokens.spacingLarge),
      itemCount: _records.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: DesignTokens.spacingMedium),
      itemBuilder: (context, index) {
        final record = _records[index];
        return _HistoryCard(
          record: record,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ResultsScreen(
                  result: record.result,
                  imagePath: record.imagePath,
                  onScanAgain: () => Navigator.of(context).pop(),
                ),
              ),
            );
          },
          onDelete: () => _deleteItem(record.id),
        );
      },
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.record,
    required this.onTap,
    required this.onDelete,
  });

  final ScanRecord record;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  Color _ripenessColor(String ripeness) {
    switch (ripeness.toLowerCase()) {
      case 'unripe':
        return DesignTokens.ripenessUnripe;
      case 'ripe':
        return DesignTokens.ripenessRipe;
      case 'overripe':
        return DesignTokens.ripenessOverripe;
      default:
        return DesignTokens.primary;
    }
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final month = months[dt.month - 1];
    final day = dt.day;
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$month $day, ${dt.year} • $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final color = _ripenessColor(record.result.ripeness);

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.spacingMedium),
          child: Row(
            children: [
              // Image thumbnail or icon
              ClipRRect(
                borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: Image.file(
                    File(record.imagePath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: DesignTokens.primaryLight,
                      child: const Icon(
                        Icons.eco,
                        color: DesignTokens.primary,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: DesignTokens.spacingMedium),

              // Title & Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${record.result.variety} — ${record.result.ripeness}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: DesignTokens.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        record.result.ripeness,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatDate(record.scannedAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: DesignTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Delete button
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: DesignTokens.textSecondary,
                ),
                onPressed: onDelete,
                tooltip: 'Delete scan record',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
