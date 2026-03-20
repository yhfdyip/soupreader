import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/database_service.dart';
import '../services/exception_log_service.dart';
import '../services/settings_service.dart';

part 'core_providers.g.dart';

/// 数据库服务（全局单例）。
///
/// 项目中所有需要数据库访问的地方，通过 `ref.watch(databaseServiceProvider)`
/// 获取实例，替代直接调用 `DatabaseService()` 工厂构造函数。
@Riverpod(keepAlive: true)
DatabaseService databaseService(Ref ref) => DatabaseService();

/// 应用设置服务（全局单例）。
///
/// 管理 [ReadingSettings] 和 [AppSettings] 两大配置域。
/// View 层推荐通过 [settingsProviders] 中的派生 Provider 精确订阅。
@Riverpod(keepAlive: true)
SettingsService settingsService(Ref ref) => SettingsService();

/// 异常日志服务（全局单例）。
///
/// 记录应用运行时异常并提供 UI 查看入口。
/// 业务代码推荐通过 [AppLogger] 门面间接使用。
@Riverpod(keepAlive: true)
ExceptionLogService exceptionLogService(Ref ref) => ExceptionLogService();
