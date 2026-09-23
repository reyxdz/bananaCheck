import 'dart:io';

import 'package:flutter/material.dart';

import 'screens/analyzing_screen.dart';
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
      title: 'Bananalyze',
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
            builder: (_) => HistoryScreen(storageService: storageService),
          ),
        );
      },
    );
  }

  /// Navigate to the AnalyzingScreen which handles classification, storage,
  /// and then forwards to ResultsScreen on success (A15 + A12).
  void _handleScan(BuildContext context, File capturedFile) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AnalyzingScreen(
          inferenceService: inferenceService,
          storageService: storageService,
          capturedFile: capturedFile,
          onComplete: (result, imagePath) {
            // Replace the AnalyzingScreen with the ResultsScreen.
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => ResultsScreen(
                  result: result,
                  imagePath: imagePath,
                  onScanAgain: () => Navigator.of(context).pop(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
