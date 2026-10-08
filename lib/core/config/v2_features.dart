import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_config.dart';

/// The V2 modules — AI analysis, AI tutor, courses — have no API in V1
/// (docs/MOBILE_API_CONTRACT.md "Out of scope — V2"). Their code and mock
/// data stay, but their entry points are hidden and their routes closed
/// unless switched on, so mock AI or course content never reaches real
/// users.
class V2Features {
  const V2Features({
    required this.aiAnalysis,
    required this.aiTutor,
    required this.courses,
  });

  /// From the `*_API_AVAILABLE` dart-defines — all off in V1.
  static const fromConfig = V2Features(
    aiAnalysis: AppConfig.isAiAnalysisApiAvailable,
    aiTutor: AppConfig.isAiTutorApiAvailable,
    courses: AppConfig.isCourseApiAvailable,
  );

  /// Everything on — for tests of the V2 screens themselves.
  static const all = V2Features(aiAnalysis: true, aiTutor: true, courses: true);

  final bool aiAnalysis;
  final bool aiTutor;
  final bool courses;
}

final v2FeaturesProvider = Provider<V2Features>((ref) => V2Features.fromConfig);
