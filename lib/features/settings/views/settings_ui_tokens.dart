class SettingsUiTokens {
  static const String plannedLabel = '扩展阶段';

  static String normalizePlannedText(String text) {
    return text.replaceAll('暂未实现', '将在扩展阶段实现');
  }

  static String status(String left, String right) => '$left · $right';
}
