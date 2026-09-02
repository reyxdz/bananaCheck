import 'dart:io';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'models/scan_record.dart';
import 'screens/camera_screen.dart';
import 'screens/history_screen.dart';
import 'screens/results_screen.dart';
import 'services/inference_service.dart';
import 'services/mock_inference_service.dart';
import 'services/sqflite_storage_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storageService = await SqfliteStorageService.instance();

  runApp(
    BananaClassifierApp(
      inferenceService: MockInferenceService(),
      storageService: storageService,
    ),
  );
}

class BananaClassifierApp extends StatelessWidget {
  const BananaClassifierApp({
    required this.inferenceService,
    required this.storageService,
    super.key,
  });

  final InferenceService inferenceService;
  final StorageService storageService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Banana Check',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: _HomeScreen(
        inferenceService: inferenceService,
        storageService: storageService,
      ),
    );
  }
}

class _HomeScreen extends StatelessWidget {
  const _HomeScreen({
    required this.inferenceService,
    required this.storageService,
  });

  final InferenceService inferenceService;
  final StorageService storageService;

  @override
  Widget build(BuildContext context) {
    return CameraScreen(
      onScan: (capturedFile) => _handleScan(context, capturedFile),
      onHistory: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const HistoryScreen(),
          ),
        );
      },
    );
  }

  Future<void> _handleScan(BuildContext context, File capturedFile) async {
    final result = await inferenceService.classify(capturedFile);
    if (!context.mounted) return;

    // ── A12: persist the scan result to local storage ──
    final record = ScanRecord(
      id: const Uuid().v4(),
      imagePath: capturedFile.path,
      result: result,
      scannedAt: DateTime.now(),
    );
    await storageService.saveRecord(record);

    if (!context.mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ResultsScreen(
          result: result,
          imagePath: capturedFile.path,
          onScanAgain: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}
