import 'package:flutter/foundation.dart';

/// 统一操作结果类型，替代散落的 try-catch + 字符串返回模式。
///
/// 使用 Dart 3 密封类实现穷举 switch：
/// ```dart
/// final result = await someOperation();
/// switch (result) {
///   case Success(value: final v): handleSuccess(v);
///   case Failure(message: final m): showError(m);
/// }
/// ```
@immutable
sealed class Result<T> {
  const Result();

  /// 是否为成功结果。
  bool get isSuccess => this is Success<T>;

  /// 是否为失败结果。
  bool get isFailure => this is Failure<T>;

  /// 成功时返回值，否则返回 null。
  T? get valueOrNull => switch (this) {
    Success(value: final v) => v,
    Failure() => null,
  };

  /// 成功时返回值，否则调用 [fallback] 返回默认值。
  T getOrElse(T Function() fallback) => switch (this) {
    Success(value: final v) => v,
    Failure() => fallback(),
  };

  /// 成功时变换值，失败时保持原样。
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Success(value: final v) => Success(transform(v)),
    Failure(
      error: final e,
      stackTrace: final s,
      message: final m,
    ) =>
      Failure(error: e, stackTrace: s, message: m),
  };

  /// 按 success / failure 分支处理，返回统一类型。
  R when<R>({
    required R Function(T value) success,
    required R Function(Object error, String? message) failure,
  }) =>
    switch (this) {
      Success(value: final v) => success(v),
      Failure(error: final e, message: final m) => failure(e, m),
    };
}

/// 操作成功，携带结果值。
@immutable
final class Success<T> extends Result<T> {
  /// 操作产出的值。
  final T value;

  const Success(this.value);

  @override
  String toString() => 'Success($value)';
}

/// 操作失败，携带错误信息。
@immutable
final class Failure<T> extends Result<T> {
  /// 原始错误对象。
  final Object error;

  /// 对应错误的调用堆栈。
  final StackTrace? stackTrace;

  /// 面向用户的简短描述，可为空。
  final String? message;

  const Failure({
    required this.error,
    this.stackTrace,
    this.message,
  });

  @override
  String toString() => 'Failure($message, $error)';
}
