import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:hand_landmarker/hand_landmarker.dart';

import 'hand_sign_classifier.dart';

class SignDetectionResult {
  const SignDetectionResult({required this.text, required this.confidence});

  final String text;
  final double confidence;
}

class SignDetectionService {
  static const double confidenceThreshold = 0.65;

  HandLandmarkerPlugin? _handLandmarker;
  final HandSignClassifier _classifier = HandSignClassifier();
  StreamSubscription<List<Hand>>? _landmarkSubscription;
  String _statusMessage =
      'Hand tracking runs on Android using MediaPipe landmarks.';

  bool get hasModel => _handLandmarker != null;
  String get statusMessage => _statusMessage;
  Stream<List<Hand>>? get landmarkStream => _handLandmarker?.landmarkStream;

  Future<void> initialize() async {
    if (_handLandmarker != null) {
      return;
    }

    if (!Platform.isAndroid) {
      _statusMessage =
          'Live sign detection is available on Android. Use the text field and speaker on other platforms.';
      return;
    }

    try {
      _handLandmarker = HandLandmarkerPlugin.create(
        numHands: 1,
        minHandDetectionConfidence: 0.65,
        delegate: HandLandmarkerDelegate.cpu,
      );
      _statusMessage = 'Hand tracker ready. Show ASL letters in the frame.';
    } catch (error) {
      _statusMessage = 'Could not start hand tracker: $error';
      if (kDebugMode) {
        debugPrint('SignDetectionService initialize error: $error');
      }
    }
  }

  void processFrame(CameraImage image, int sensorOrientation) {
    _handLandmarker?.processFrame(image, sensorOrientation);
  }

  SignDetectionResult? classifyHands(List<Hand> hands) {
    if (hands.isEmpty) {
      return null;
    }

    final result = _classifier.classify(hands.first.landmarks);
    if (result == null || result.confidence < confidenceThreshold) {
      return null;
    }

    return SignDetectionResult(text: result.label, confidence: result.confidence);
  }

  void resetClassifier() {
    _classifier.reset();
  }

  void dispose() {
    _landmarkSubscription?.cancel();
    _landmarkSubscription = null;
    _handLandmarker?.dispose();
    _handLandmarker = null;
    _classifier.reset();
  }
}
