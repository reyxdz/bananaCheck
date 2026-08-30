import 'dart:io';

import 'package:flutter/material.dart';
import 'screens/camera_screen.dart';
import 'screens/history_screen.dart';
import 'screens/results_screen.dart';
import 'services/inference_service.dart';
import 'services/mock_inference_service.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(BananaClassifierApp(inferenceService: MockInferenceService()));
}

class BananaClassifierApp extends StatelessWidget {
  const BananaClassifierApp({required this.inferenceService, super.key});

  final InferenceService inferenceService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Banana Check',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: _HomeScreen(inferenceService: inferenceService),
    );
  }
}

class _HomeScreen extends StatelessWidget {
  const _HomeScreen({required this.inferenceService});

  final InferenceService inferenceService;

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
