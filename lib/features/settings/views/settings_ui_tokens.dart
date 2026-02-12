class SettingsUiTokens {
  static const String plannedLabel = '计划中';

  static String normalizePlannedText(String text) {
    return text.replaceAll('暂未实现', plannedLabel);
  }

  static String status(String left, String right) => '$left · $right';
}
