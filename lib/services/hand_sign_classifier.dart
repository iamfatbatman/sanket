import 'dart:math' as math;

import 'package:hand_landmarker/hand_landmarker.dart';

class HandSignMatch {
  const HandSignMatch({required this.label, required this.confidence});

  final String label;
  final double confidence;
}

/// Rule-based ASL fingerspelling classifier using 21 MediaPipe hand landmarks.
class HandSignClassifier {
  static const _tips = [4, 8, 12, 16, 20];

  final List<String> _recentLabels = [];
  static const _smoothingWindow = 6;
  static const _smoothingVotes = 4;

  void reset() {
    _recentLabels.clear();
  }

  HandSignMatch? classify(List<Landmark> landmarks) {
    if (landmarks.length < 21) {
      return null;
    }

    final raw = _classifyFrame(landmarks);
    if (raw == null) {
      return null;
    }

    _recentLabels.add(raw.label);
    if (_recentLabels.length > _smoothingWindow) {
      _recentLabels.removeAt(0);
    }

    final counts = <String, int>{};
    for (final label in _recentLabels) {
      counts[label] = (counts[label] ?? 0) + 1;
    }

    var bestLabel = raw.label;
    var bestCount = 0;
    for (final entry in counts.entries) {
      if (entry.value > bestCount) {
        bestLabel = entry.key;
        bestCount = entry.value;
      }
    }

    if (bestCount < _smoothingVotes) {
      return null;
    }

    final confidence = math.min(
      0.98,
      raw.confidence * (bestCount / _smoothingWindow),
    );
    return HandSignMatch(label: bestLabel, confidence: confidence);
  }

  HandSignMatch? _classifyFrame(List<Landmark> lm) {
    final thumb = _isFingerExtended(lm, 4, 3, 2);
    final index = _isFingerExtended(lm, 8, 6, 5);
    final middle = _isFingerExtended(lm, 12, 10, 9);
    final ring = _isFingerExtended(lm, 16, 14, 13);
    final pinky = _isFingerExtended(lm, 20, 18, 17);
    final extendedCount = [index, middle, ring, pinky].where((v) => v).length;

    final indexMiddleSpread = _dist(lm[8], lm[12]);
    final thumbIndexDistance = _dist(lm[4], lm[8]);
    final thumbMiddleDistance = _dist(lm[4], lm[12]);
    final palmWidth = _dist(lm[5], lm[17]).clamp(0.05, 1.0);

    // Open palm → word break.
    if (thumb && index && middle && ring && pinky) {
      return const HandSignMatch(label: 'SPACE', confidence: 0.88);
    }

    // Thumbs down → delete last character.
    if (!index &&
        !middle &&
        !ring &&
        !pinky &&
        thumb &&
        lm[4].y > lm[2].y + 0.04) {
      return const HandSignMatch(label: 'DELETE', confidence: 0.82);
    }

    // Four fingers up, thumb folded.
    if (index && middle && ring && pinky && !thumb) {
      return const HandSignMatch(label: 'B', confidence: 0.85);
    }

    // W — three fingers up (index, middle, ring).
    if (index && middle && ring && !pinky && !thumb) {
      return const HandSignMatch(label: 'W', confidence: 0.82);
    }

    // V vs U — two fingers up.
    if (index && middle && !ring && !pinky && !thumb) {
      if (indexMiddleSpread / palmWidth > 0.45) {
        return const HandSignMatch(label: 'V', confidence: 0.82);
      }
      return const HandSignMatch(label: 'U', confidence: 0.78);
    }

    // D — index only.
    if (index && !middle && !ring && !pinky && !thumb) {
      return const HandSignMatch(label: 'D', confidence: 0.8);
    }

    // I vs Y — pinky only, optional thumb.
    if (pinky && !index && !middle && !ring) {
      if (thumb) {
        return const HandSignMatch(label: 'Y', confidence: 0.8);
      }
      return const HandSignMatch(label: 'I', confidence: 0.8);
    }

    // L — thumb + index.
    if (thumb && index && !middle && !ring && !pinky) {
      return const HandSignMatch(label: 'L', confidence: 0.8);
    }

    // F — OK sign with three fingers up.
    if (middle && ring && pinky && !index && thumbIndexDistance < 0.12) {
      return const HandSignMatch(label: 'F', confidence: 0.75);
    }

    // O — fingertips form a circle with thumb.
    if (_isOShape(lm)) {
      return const HandSignMatch(label: 'O', confidence: 0.76);
    }

    // R — index crosses middle.
    if (_isCrossed(lm[8], lm[12], lm[10])) {
      return const HandSignMatch(label: 'R', confidence: 0.74);
    }

    // K — V with thumb between index and middle.
    if (index &&
        middle &&
        !ring &&
        !pinky &&
        thumb &&
        thumbIndexDistance < 0.18 &&
        thumbMiddleDistance < 0.18) {
      return const HandSignMatch(label: 'K', confidence: 0.72);
    }

    // H — index and middle extended side by side horizontally.
    if (index &&
        middle &&
        !ring &&
        !pinky &&
        !thumb &&
        (lm[8].y - lm[12].y).abs() < 0.04 &&
        indexMiddleSpread / palmWidth > 0.35) {
      return const HandSignMatch(label: 'H', confidence: 0.7);
    }

    // G — index and thumb point forward, others closed.
    if (thumb &&
        index &&
        !middle &&
        !ring &&
        !pinky &&
        lm[4].x < lm[8].x) {
      return const HandSignMatch(label: 'G', confidence: 0.7);
    }

    // X — hooked index.
    if (_isHookedIndex(lm) && !middle && !ring && !pinky) {
      return const HandSignMatch(label: 'X', confidence: 0.7);
    }

    // Closed fist variants.
    if (extendedCount == 0) {
      if (_dist(lm[4], lm[9]) < 0.1 || _dist(lm[4], lm[5]) < 0.1) {
        return const HandSignMatch(label: 'S', confidence: 0.74);
      }
      if (_dist(lm[4], lm[7]) < 0.08) {
        return const HandSignMatch(label: 'T', confidence: 0.68);
      }
      if (_dist(lm[4], lm[10]) < 0.09 && _dist(lm[4], lm[14]) < 0.11) {
        return const HandSignMatch(label: 'M', confidence: 0.66);
      }
      if (_dist(lm[4], lm[10]) < 0.09) {
        return const HandSignMatch(label: 'N', confidence: 0.66);
      }
      return const HandSignMatch(label: 'A', confidence: 0.72);
    }

    // C — curved hand, partial extension.
    if (_isCShape(lm)) {
      return const HandSignMatch(label: 'C', confidence: 0.65);
    }

    // E — fingertips curl toward palm.
    if (_isEShape(lm)) {
      return const HandSignMatch(label: 'E', confidence: 0.64);
    }

    return null;
  }

  bool _isFingerExtended(
    List<Landmark> lm,
    int tip,
    int pip,
    int mcp,
  ) {
    final tipDist = _dist(lm[tip], lm[0]);
    final pipDist = _dist(lm[pip], lm[0]);
    final mcpDist = _dist(lm[mcp], lm[0]);
    return tipDist > pipDist * 1.08 && pipDist > mcpDist * 0.92;
  }

  bool _isOShape(List<Landmark> lm) {
    final cluster = [
      _dist(lm[4], lm[8]),
      _dist(lm[4], lm[12]),
      _dist(lm[4], lm[16]),
      _dist(lm[4], lm[20]),
    ];
    final avg = cluster.reduce((a, b) => a + b) / cluster.length;
    return avg < 0.14 &&
        !_isFingerExtended(lm, 8, 6, 5) &&
        !_isFingerExtended(lm, 12, 10, 9);
  }

  bool _isCShape(List<Landmark> lm) {
    final partiallyExtended = _tips
        .where((tip) {
          final pip = tip - 1;
          final mcp = tip - 2;
          final tipDist = _dist(lm[tip], lm[0]);
          final pipDist = _dist(lm[pip], lm[0]);
          final mcpDist = _dist(lm[mcp], lm[0]);
          return tipDist > mcpDist * 0.95 && tipDist < pipDist * 1.15;
        })
        .length;
    return partiallyExtended >= 3;
  }

  bool _isEShape(List<Landmark> lm) {
    final curled = _tips.where((tip) {
      final pip = tip - 1;
      return _dist(lm[tip], lm[0]) < _dist(lm[pip], lm[0]) * 1.05;
    }).length;
    return curled >= 4 && _dist(lm[4], lm[8]) < 0.12;
  }

  bool _isHookedIndex(List<Landmark> lm) {
    final tipDist = _dist(lm[8], lm[0]);
    final pipDist = _dist(lm[6], lm[0]);
    final mcpDist = _dist(lm[5], lm[0]);
    return tipDist > mcpDist * 0.85 &&
        tipDist < pipDist * 1.05 &&
        !_isFingerExtended(lm, 8, 6, 5);
  }

  bool _isCrossed(Landmark indexTip, Landmark middleTip, Landmark middlePip) {
    return _dist(indexTip, middlePip) < 0.08 &&
        _dist(indexTip, middleTip) < 0.07;
  }

  double _dist(Landmark a, Landmark b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    final dz = a.z - b.z;
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }
}
