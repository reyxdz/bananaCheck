import 'dart:io';

import 'package:image/image.dart' as img;

import '../models/classification_result.dart';

abstract interface class InferenceService {
  Future<ClassificationResult> classify(File imageFile);
}

/// Classifies an already-decoded image region rather than a file on disk.
///
/// A bundle scan runs the model over a hundred-odd crops of one photo, so it
/// cannot go through [InferenceService.classify] — that would re-read and
/// re-decode the file every time. Keeping this separate from
/// [InferenceService] leaves the §9 contract untouched: the single-scan flow
/// still only knows about `classify(File)`.
abstract interface class RegionClassifier {
  ClassificationResult classifyRegion(img.Image region);
}
