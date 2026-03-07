import 'app_bootstrap.dart';
import 'boot_build_info_text.dart';

/// 生成可复制的启动失败详情文本。
String buildBootFailurePayload({
  required BootFailure failure,
  required String bootLog,
}) {
  final out = StringBuffer()
    ..writeln('BootFailure')
    ..writeln(buildBootPayloadInfoText())
    ..writeln('step=${failure.stepName}')
    ..writeln('error=${failure.error}')
    ..writeln('')
    ..writeln('stack:')
    ..writeln(failure.stack.toString());
  if (bootLog.trim().isNotEmpty) {
    out
      ..writeln('')
      ..writeln('boot_log:')
      ..writeln(bootLog.trim());
  }
  return out.toString().trim();
}
