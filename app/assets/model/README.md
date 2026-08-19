# Model assets

This directory will contain the validated TensorFlow Lite model and final
`labels.txt` file produced during the model-integration milestone.

The setup scaffold deliberately ships without a fake model binary. The Flutter
application uses `MockInferenceService` until the trained model has passed its
accuracy and on-device validation checks.
