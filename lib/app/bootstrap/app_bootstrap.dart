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

@immutable
class BootFailure {
  final String stepName;
  final Object error;
  final StackTrace stack;

  const BootFailure({
    required this.stepName,
    required this.error,
    required this.stack,
  });
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

Future<BootFailure?> bootstrapApp({
  ValueChanged<String>? onStepChanged,
}) async {
  try {
    await _bootstrapCore(onStepChanged);
    await _bootstrapRepositories(onStepChanged);
    await _bootstrapServices(onStepChanged);
    return null;
  } on _BootStepException catch (e) {
    return BootFailure(
      stepName: e.stepName,
      error: e.error,
      stack: e.stack,
    );
  } catch (e, st) {
    return BootFailure(
      stepName: 'unknown',
      error: e,
      stack: st,
    );
  }
}

Future<void> _bootstrapCore(ValueChanged<String>? onStepChanged) async {
  await _runBootStep('DatabaseService.init', () async {
    await DatabaseService().init();
  }, onStepChanged: onStepChanged);
  await _runBootStep('ExceptionLogService.bootstrap', () async {
    await ExceptionLogService().bootstrap();
  }, onStepChanged: onStepChanged);
}

Future<void> _bootstrapRepositories(ValueChanged<String>? onStepChanged) async {
  await _runBootStep('SourceRepository.bootstrap', () async {
    await SourceRepository.bootstrap(DatabaseService());
  }, onStepChanged: onStepChanged);
  await _runBootStep(
    'MigrationExclusions.bootstrapRssRepositories',
    () async {
      if (MigrationExclusions.excludeRss) {
        BootLog.add(
          '[boot] skip rss bootstrap (excluded) '
          'config=${MigrationExclusions.summary()}',
        );
        return;
      }
      await MigrationExclusions.bootstrapRssRepositories(DatabaseService());
    },
    onStepChanged: onStepChanged,
  );
  await _runBootStep('BookRepository.bootstrap', () async {
    await BookRepository.bootstrap(DatabaseService());
  }, onStepChanged: onStepChanged);
  await _runBootStep('ChapterRepository.bootstrap', () async {
    await ChapterRepository.bootstrap(DatabaseService());
  }, onStepChanged: onStepChanged);
  await _runBootStep('ReplaceRuleRepository.bootstrap', () async {
    await ReplaceRuleRepository.bootstrap(DatabaseService());
  }, onStepChanged: onStepChanged);
}

Future<void> _bootstrapServices(ValueChanged<String>? onStepChanged) async {
  await _runBootStep('SettingsService.init', () async {
    await SettingsService().init();
  }, onStepChanged: onStepChanged);
  await _runBootStep('CookieStore.setup', () async {
    await CookieStore.setup();
  }, onStepChanged: onStepChanged);
}

Future<void> _runBootStep(
  String name,
  Future<void> Function() action, {
  ValueChanged<String>? onStepChanged,
}) async {
  onStepChanged?.call(name);
  BootLog.add('[boot] $name start');
  try {
    await action();
    BootLog.add('[boot] $name ok');
  } catch (e, st) {
    BootLog.add('[boot] $name failed: $e');
    ExceptionLogService().record(
      node: 'bootstrap.$name',
      message: '启动步骤失败',
      error: e,
      stackTrace: st,
    );
    throw _BootStepException(
      stepName: name,
      error: e,
      stack: st,
    );
  }
}
