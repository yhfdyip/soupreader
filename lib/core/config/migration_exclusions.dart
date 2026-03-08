import '../database/database_service.dart';
import '../database/repositories/rss_article_repository.dart';
import '../database/repositories/rss_source_repository.dart';
import '../database/repositories/rss_star_repository.dart';

/// 迁移排除配置（集中式）。
///
/// 设计目标：
/// - 在迁移阶段按模块维度“硬排除”未完成能力，避免启动链路回流；
/// - 配置应集中、可检索、可被守卫脚本约束；
/// - 默认以当前大目标为“排除态”，需要启用时通过构建参数显式放开。
///
/// 约定：
/// - 值为 `true` 表示“排除”（默认值），即当前构建下该模块不可用；
/// - 值为 `false` 表示“未排除”，允许进入业务链路与启动流程。
///
/// 覆盖方式（Flutter 构建参数）：
/// - `--dart-define=SOUPREADER_EXCLUDE_RSS=false`
/// - `--dart-define=SOUPREADER_EXCLUDE_TTS=false`
/// - `--dart-define=SOUPREADER_EXCLUDE_MANGA=false`
/// - `--dart-define=SOUPREADER_EXCLUDE_WEBSERVICE=false`
/// - `--dart-define=SOUPREADER_EXCLUDE_REMOTE_BOOKS=false`
///
/// 注意：
/// - 这些开关属于“迁移级别”控制，不等同于用户设置（`AppSettings`）里的开关。
class MigrationExclusions {
  const MigrationExclusions._();

  static const String _keyExcludeRss = 'SOUPREADER_EXCLUDE_RSS';
  static const String _keyExcludeTts = 'SOUPREADER_EXCLUDE_TTS';
  static const String _keyExcludeManga = 'SOUPREADER_EXCLUDE_MANGA';
  static const String _keyExcludeWebService = 'SOUPREADER_EXCLUDE_WEBSERVICE';
  static const String _keyExcludeRemoteBooks =
      'SOUPREADER_EXCLUDE_REMOTE_BOOKS';

  /// 订阅源 / RSS（EX-02）。
  static const bool excludeRss = bool.fromEnvironment(
    _keyExcludeRss,
    defaultValue: true,
  );

  /// 朗读 / TTS（EX-03）。
  static const bool excludeTts = bool.fromEnvironment(
    _keyExcludeTts,
    defaultValue: false,
  );

  /// 漫画（EX-04）。
  static const bool excludeManga = bool.fromEnvironment(
    _keyExcludeManga,
    defaultValue: true,
  );

  /// WebService（远程服务/局域网服务等）。
  static const bool excludeWebService = bool.fromEnvironment(
    _keyExcludeWebService,
    defaultValue: true,
  );

  /// 远程书籍（WebDav 远端书架能力）。
  static const bool excludeRemoteBooks = bool.fromEnvironment(
    _keyExcludeRemoteBooks,
    defaultValue: true,
  );

  /// 用于启动日志的配置摘要（避免在多个位置重复拼接）。
  static String summary() {
    return 'excludeRss=$excludeRss, '
        'excludeTts=$excludeTts, '
        'excludeManga=$excludeManga, '
        'excludeWebService=$excludeWebService, '
        'excludeRemoteBooks=$excludeRemoteBooks';
  }

  /// RSS 仓储集中 bootstrap。
  ///
  /// 说明：
  /// - 该方法仅负责执行“初始化动作本身”，是否允许执行应由调用方根据 [excludeRss]
  ///   做硬跳过（迁移排除构建下必须跳过）；
  /// - 异常直接向上抛出，交由启动编排方统一记录与熔断，避免吞错导致状态不一致。
  static Future<void> bootstrapRssRepositories(DatabaseService db) async {
    await RssSourceRepository.bootstrap(db);
    await RssArticleRepository.bootstrap(db);
    await RssStarRepository.bootstrap(db);
    await RssReadRecordRepository.bootstrap(db);
  }
}
