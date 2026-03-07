import '../../core/build/build_info.dart';

/// 生成启动阶段展示用的构建信息文案。
String buildBootInfoText({bool includeBootHostPrefix = false}) {
  final prefix = includeBootHostPrefix ? 'BOOT HOST  ' : '';
  return '${prefix}ref=${BuildInfo.gitRef}  '
      'sha=${BuildInfo.gitShaShort}  '
      'build=${BuildInfo.buildNumber}  '
      '${BuildInfo.isRelease ? 'release' : 'debug'}';
}

/// 生成启动失败日志中使用的构建信息文案。
String buildBootPayloadInfoText() {
  return 'build: ref=${BuildInfo.gitRef} sha=${BuildInfo.gitSha} '
      'build=${BuildInfo.buildNumber} '
      '${BuildInfo.isRelease ? 'release' : 'debug'}';
}
