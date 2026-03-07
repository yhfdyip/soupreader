import 'package:flutter/foundation.dart';

import '../../core/bootstrap/boot_log.dart';
import '../../core/config/migration_exclusions.dart';
import '../../core/database/database_service.dart';
import '../../core/database/repositories/book_repository.dart';
import '../../core/database/repositories/replace_rule_repository.dart';
import '../../core/database/repositories/source_repository.dart';
import '../../core/services/cookie_store.dart';
import '../../core/services/exception_log_service.dart';
import '../../core/services/settings_service.dart';

/// 启动阶段依赖集合，用于集中注入可替换服务。
@immutable
class BootDependencies {
  /// 提供数据库与仓储初始化所需的数据库服务。
  final DatabaseService databaseService;

  /// 负责记录启动阶段异常与错误信息。
  final ExceptionLogService exceptionLogService;

  /// 提供应用设置加载与访问能力。
  final SettingsService settingsService;

  const BootDependencies({
    required this.databaseService,
    required this.exceptionLogService,
    required this.settingsService,
  });

  /// 使用默认实现创建启动依赖，也支持按需覆盖单个依赖。
  factory BootDependencies.defaults({
    DatabaseService? databaseService,
    ExceptionLogService? exceptionLogService,
    SettingsService? settingsService,
  }) {
    return BootDependencies(
      databaseService: databaseService ?? DatabaseService(),
      exceptionLogService: exceptionLogService ?? ExceptionLogService(),
      settingsService: settingsService ?? SettingsService(),
    );
  }
}

/// 描述启动失败的步骤、错误对象与堆栈。
@immutable
class BootFailure {
  /// 发生失败的启动步骤名。
  final String stepName;

  /// 原始错误对象。
  final Object error;

  /// 对应错误的调用堆栈。
  final StackTrace stack;

  const BootFailure({
    required this.stepName,
    required this.error,
    required this.stack,
  });

  /// 由错误对象快速构造启动失败结果。
  factory BootFailure.fromError({
    required String stepName,
    required Object error,
    required StackTrace stackTrace,
  }) {
    return BootFailure(
      stepName: stepName,
      error: error,
      stack: stackTrace,
    );
  }

  /// 使用默认的 `unknown` 步骤名构造失败结果。
  factory BootFailure.unknown({
    required Object error,
    required StackTrace stackTrace,
  }) {
    return BootFailure(
      stepName: 'unknown',
      error: error,
      stack: stackTrace,
    );
  }
}

class _BootStepException implements Exception {
  final String stepName;
  final Object error;
  final StackTrace stack;

  const _BootStepException({
    required this.stepName,
    required this.error,
    required this.stack,
  });

  @override
  String toString() => 'BootStepException($stepName): $error';
}

@immutable
class _BootStep {
  final String name;
  final AsyncCallback action;

  const _BootStep({required this.name, required this.action});
}

/// 按既定顺序执行应用启动步骤，失败时返回失败信息。
Future<BootFailure?> bootstrapApp({
  ValueChanged<String>? onStepChanged,
  BootDependencies? dependencies,
}) async {
  final resolvedDependencies = dependencies ?? BootDependencies.defaults();
  try {
    final steps = _buildBootSteps(resolvedDependencies);
    await _runBootSteps(
      steps,
      exceptionLogService: resolvedDependencies.exceptionLogService,
      onStepChanged: onStepChanged,
    );
    return null;
  } on _BootStepException catch (error) {
    return BootFailure.fromError(
      stepName: error.stepName,
      error: error.error,
      stackTrace: error.stack,
    );
  } catch (error, stackTrace) {
    return BootFailure.fromError(
      stepName: 'unknown',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

List<_BootStep> _buildBootSteps(BootDependencies dependencies) {
  return <_BootStep>[
    _BootStep(
      name: 'DatabaseService.init',
      action: dependencies.databaseService.init,
    ),
    _BootStep(
      name: 'ExceptionLogService.bootstrap',
      action: dependencies.exceptionLogService.bootstrap,
    ),
    _BootStep(
      name: 'SourceRepository.bootstrap',
      action: () => SourceRepository.bootstrap(dependencies.databaseService),
    ),
    _BootStep(
      name: 'MigrationExclusions.bootstrapRssRepositories',
      action: () => _bootstrapRssRepositories(dependencies.databaseService),
    ),
    _BootStep(
      name: 'BookRepository.bootstrap',
      action: () => BookRepository.bootstrap(dependencies.databaseService),
    ),
    _BootStep(
      name: 'ChapterRepository.bootstrap',
      action: () => ChapterRepository.bootstrap(dependencies.databaseService),
    ),
    _BootStep(
      name: 'ReplaceRuleRepository.bootstrap',
      action: () =>
          ReplaceRuleRepository.bootstrap(dependencies.databaseService),
    ),
    _BootStep(
      name: 'SettingsService.init',
      action: dependencies.settingsService.init,
    ),
    _BootStep(
      name: 'CookieStore.setup',
      action: CookieStore.setup,
    ),
  ];
}

Future<void> _bootstrapRssRepositories(DatabaseService databaseService) async {
  if (MigrationExclusions.excludeRss) {
    BootLog.add(
      '[boot] skip rss bootstrap (excluded) '
      'config=${MigrationExclusions.summary()}',
    );
    return;
  }
  await MigrationExclusions.bootstrapRssRepositories(databaseService);
}

Future<void> _runBootSteps(
  List<_BootStep> steps, {
  required ExceptionLogService exceptionLogService,
  ValueChanged<String>? onStepChanged,
}) async {
  for (final step in steps) {
    await _runBootStep(
      step,
      exceptionLogService: exceptionLogService,
      onStepChanged: onStepChanged,
    );
  }
}

Future<void> _runBootStep(
  _BootStep step, {
  required ExceptionLogService exceptionLogService,
  ValueChanged<String>? onStepChanged,
}) async {
  onStepChanged?.call(step.name);
  BootLog.add('[boot] ${step.name} start');
  try {
    await step.action();
    BootLog.add('[boot] ${step.name} ok');
  } catch (error, stackTrace) {
    BootLog.add('[boot] ${step.name} failed: $error');
    exceptionLogService.record(
      node: 'bootstrap.${step.name}',
      message: '启动步骤失败',
      error: error,
      stackTrace: stackTrace,
    );
    throw _BootStepException(
      stepName: step.name,
      error: error,
      stack: stackTrace,
    );
  }
}
