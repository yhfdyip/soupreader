import '../../core/build/build_info.dart';

const String _kReleaseModeLabel = 'release';
const String _kDebugModeLabel = 'debug';

String _buildModeLabel() {
  return BuildInfo.isRelease ? _kReleaseModeLabel : _kDebugModeLabel;
}

String _buildIdentityText({required bool shortSha}) {
  final gitSha = shortSha ? BuildInfo.gitShaShort : BuildInfo.gitSha;
  return 'ref=${BuildInfo.gitRef} sha=$gitSha build=${BuildInfo.buildNumber}';
}

/// 生成启动阶段展示用的构建信息文案。
String buildBootInfoText({bool includeBootHostPrefix = false}) {
  final prefix = includeBootHostPrefix ? 'BOOT HOST  ' : '';
  return '${prefix}${_buildIdentityText(shortSha: true)}  ${_buildModeLabel()}';
}

/// 生成启动失败日志中使用的构建信息文案。
String buildBootPayloadInfoText() {
  return 'build: ${_buildIdentityText(shortSha: false)} ${_buildModeLabel()}';
}
