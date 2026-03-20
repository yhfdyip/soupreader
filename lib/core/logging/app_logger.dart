import 'package:flutter/foundation.dart';

import '../services/exception_log_service.dart';

/// 统一日志门面，桥接 [ExceptionLogService] 与 debugPrint。
///
/// 每个业务类通过 `AppLogger(tag: 'ReaderView')` 创建带标签实例，
/// 替代散落的 `debugPrint` + `ExceptionLogService().record(...)` 调用。
///
/// 三级日志：
/// - [debug]：仅控制台输出（开发调试用）。
/// - [warning]：控制台 + 持久化记录。
/// - [error]：全量记录（控制台 + 持久化 + 可选上下文）。
class AppLogger {
  /// 日志标签，标识来源模块。
  final String tag;

  final ExceptionLogService _logService;

  AppLogger({
    required this.tag,
    ExceptionLogService? logService,
  }) : _logService = logService ?? ExceptionLogService();

  /// 记录调试信息（仅 debugPrint，不写持久化日志）。
  void debug(String message) {
    debugPrint('[$tag] $message');
  }

  /// 记录警告（debugPrint + ExceptionLogService）。
  void warning(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    debugPrint('[$tag] WARN: $message');
    _logService.record(
      node: tag,
      message: message,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// 记录错误（debugPrint + ExceptionLogService + 可选上下文）。
  void error(
    String message, {
    required Object error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    debugPrint('[$tag] ERROR: $message ($error)');
    _logService.record(
      node: tag,
      message: message,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }
}
