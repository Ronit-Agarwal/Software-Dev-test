class PrivacySettings {
  static bool crashReportingEnabled = false;
  static bool analyticsEnabled = false;
  static bool cloudAiEnabled = false;

  static void update({
    required bool crashReporting,
    required bool analytics,
    required bool cloudAi,
  }) {
    crashReportingEnabled = crashReporting;
    analyticsEnabled = analytics;
    cloudAiEnabled = cloudAi;
  }
}
