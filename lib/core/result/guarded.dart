import '../logging/app_logger.dart';
import 'result.dart';

/// 异步操作守卫：将 try-catch 统一转换为 [Result] 模式。
///
/// 用法：
/// ```dart
/// final result = await guarded(
///   () => repository.fetchChapters(bookId),
///   logger: _logger,
///   message: '加载章节列表',
/// );
/// switch (result) {
///   case Success(value: final chapters): useChapters(chapters);
///   case Failure(message: final msg): showError(msg);
/// }
/// ```
Future<Result<T>> guarded<T>(
  Future<T> Function() action, {
  AppLogger? logger,
  String? message,
}) async {
  try {
    return Success(await action());
  } catch (error, stackTrace) {
    logger?.error(
      message ?? '操作失败',
      error: error,
      stackTrace: stackTrace,
    );
    return Failure(
      error: error,
      stackTrace: stackTrace,
      message: message,
    );
  }
}

/// 同步操作守卫。
Result<T> guardedSync<T>(
  T Function() action, {
  AppLogger? logger,
  String? message,
}) {
  try {
    return Success(action());
  } catch (error, stackTrace) {
    logger?.error(
      message ?? '操作失败',
      error: error,
      stackTrace: stackTrace,
    );
    return Failure(
      error: error,
      stackTrace: stackTrace,
      message: message,
    );
  }
}
