import 'dart:io';

import '../models/classification_result.dart';

abstract interface class InferenceService {
  Future<ClassificationResult> classify(File imageFile);
}
