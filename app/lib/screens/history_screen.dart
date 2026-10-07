import 'dart:io';

import 'package:flutter/material.dart';

import '../models/banana_info_data.dart';
import '../models/scan_record.dart';
import '../services/storage_service.dart';
import '../theme/design_tokens.dart';
import '../theme/ripeness_helpers.dart';
import '../widgets/empty_state.dart';
import '../widgets/info_pill.dart';
import '../widgets/primary_button.dart';
import '../widgets/screen_header.dart';
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
  bool _hasError = false;

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
      _hasError = false;
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
          _hasError = true;
        });
      }
    }
  }

  Future<void> _deleteItem(String id) async {
    final service = widget.storageService;
    if (service != null) {
      await service.deleteRecord(id);
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
              backgroundColor: DesignTokens.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.storageService != null) {
      await widget.storageService!.clearRecords();
      await _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Scan History',
              onBack: () => Navigator.of(context).maybePop(),
              actions: [
                if (_records.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined),
                    tooltip: 'Clear All',
                    onPressed: _clearAll,
                  ),
              ],
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _hasError
                      ? _buildErrorState(context)
                      : _records.isEmpty
                          ? _buildEmptyState(context)
                          : _buildRecordList(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline_rounded,
      iconColor: DesignTokens.error,
      iconBackground: DesignTokens.errorBackground,
      title: 'Something went wrong',
      message: 'We could not load your scan history. Please try again.',
      primaryAction: PrimaryButton(
        icon: Icons.refresh_rounded,
        label: 'Try Again',
        onPressed: _loadHistory,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return EmptyState(
      icon: Icons.history_rounded,
      title: 'No Saved Scans Yet',
      message: 'Your past banana classification results will be saved here '
          'so you can review them anytime.',
      primaryAction: PrimaryButton(
        icon: Icons.camera_alt_rounded,
        label: 'Scan a Banana Now',
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }

  Widget _buildRecordList(BuildContext context) {
    final count = _records.length;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        DesignTokens.spacingMedium,
        DesignTokens.spacingSmall,
        DesignTokens.spacingMedium,
        DesignTokens.spacingLarge,
      ),
      // Header row + one row per record.
      itemCount: count + 1,
      separatorBuilder: (_, index) => SizedBox(
        height: index == 0
            ? DesignTokens.spacingSmall
            : DesignTokens.spacingSmall + 4,
      ),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spacingExtraSmall,
            ),
            child: Text(
              count == 1
                  ? '1 saved scan · newest first'
                  : '$count saved scans · newest first',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          );
        }
        final record = _records[index - 1];
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
    final color = RipenessHelpers.colorFor(record.result.ripeness);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.spacingSmall + 4),
          child: Row(
            children: [
              // Photo thumbnail, or a leaf if the file is gone.
              ClipRRect(
                borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                child: SizedBox(
                  width: DesignTokens.historyThumbnailSize,
                  height: DesignTokens.historyThumbnailSize,
                  child: Image.file(
                    File(record.imagePath),
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                    errorBuilder: (_, __, ___) => const ColoredBox(
                      color: DesignTokens.primaryLight,
                      child: Icon(
                        Icons.eco,
                        color: DesignTokens.primary,
                        size: DesignTokens.iconHistoryFallback,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: DesignTokens.spacingMedium),

              // Title, ripeness badge, date.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayVarietyName(record.result.variety),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: DesignTokens.spacingExtraSmall + 2),
                    InfoPill(
                      icon: RipenessHelpers.iconFor(record.result.ripeness),
                      label: record.result.ripeness,
                      color: color,
                      outlined: true,
                      compact: true,
                    ),
                    const SizedBox(height: DesignTokens.spacingExtraSmall + 2),
                    Text(
                      _formatDate(record.scannedAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),

              // Delete button (48dp target from the theme).
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
