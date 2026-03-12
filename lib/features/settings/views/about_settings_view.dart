import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';

import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_sheet_panel.dart';
import '../../../app/widgets/app_ui_kit.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/services/settings_service.dart';
import 'app_help_dialog.dart';
import 'exception_logs_view.dart';

class AboutSettingsView extends StatefulWidget {
  const AboutSettingsView({super.key});

  @override
  State<AboutSettingsView> createState() => _AboutSettingsViewState();
}

class _AboutSettingsViewState extends State<AboutSettingsView> {
  static const String _fallbackAppName = 'SoupReader';
  static const String _appShareDescription =
      'SoupReader 下载链接：\nhttps://github.com/Inighty/soupreader/releases';
  static const String _contributorsUrl =
      'https://github.com/gedoor/legado/graphs/contributors';

  final SettingsService _settingsService = SettingsService();
  final ExceptionLogService _exceptionLogService = ExceptionLogService();

  String _version = '—';
  String _versionSummary = '版本 —';
  String _appName = _fallbackAppName;
  String _packageName = '';

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      final appName = info.appName.trim();
      final version = info.version.trim();
      setState(() {
        _appName = appName.isEmpty ? _fallbackAppName : appName;
        _version = version.isEmpty ? '—' : version;
        _versionSummary = '版本 $_version';
        _packageName = info.packageName.trim();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _appName = _fallbackAppName;
        _version = '—';
        _versionSummary = '版本 —';
        _packageName = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '关于',
      trailing: _buildTrailingActions(),
      child: ValueListenableBuilder<List<ExceptionLogEntry>>(
        valueListenable: _exceptionLogService.listenable,
        builder: (context, logs, _) {
          return AppListView(
            children: [
              _buildAboutHeroCard(),
              AppListSection(
                hasLeading: false,
                children: [
                  AppListTile(
                    title: const Text('开发人员'),                    onTap: _openContributors,
                  ),
                  AppListTile(
                    title: const Text('更新日志'),
                    additionalInfo: Text(_versionSummary),
                    onTap: _openUpdateLog,
                  ),
                  AppListTile(
                    title: const Text('检查更新'),
                    onTap: _checkUpdate,
                  ),
                ],
              ),
              AppListSection(
                header: const Text('其它'),
                hasLeading: false,
                children: [
                  AppListTile(
                    title: const Text('崩溃日志'),
                    additionalInfo: Text('${logs.length} 条'),
                    onTap: _openCrashLogs,
                  ),
                  AppListTile(
                    title: const Text('保存日志'),
                    onTap: _saveLog,
                  ),
                  AppListTile(
                    title: const Text('创建堆转储'),
                    onTap: _createHeapDump,
                  ),
                  AppListTile(
                    title: const Text('用户隐私与协议'),
                    onTap: _openPrivacyPolicy,
                  ),
                  AppListTile(
                    title: const Text('开源许可'),
                    onTap: _openLicense,
                  ),
                  AppListTile(
                    title: const Text('免责声明'),
                    onTap: _openDisclaimer,
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTrailingActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppNavBarButton(
          onPressed: _handleShare,
          child: const Icon(CupertinoIcons.share, size: 22),
        ),
        AppNavBarButton(
          onPressed: _openScoring,
          child: const Icon(CupertinoIcons.hand_thumbsup, size: 22),
        ),
      ],
    );
  }

  Widget _buildAboutHeroCard() {
    final tokens = AppUiTokens.resolve(context);
    final theme = CupertinoTheme.of(context);
    final packageName = _packageName.trim();
    final packageText = packageName.isEmpty ? '包名未读取' : packageName;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        borderColor: tokens.colors.separator.withValues(alpha: 0.72),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tokens.colors.accent,
              ),
              child: const SizedBox(
                width: 42,
                height: 42,
                child: Icon(
                  CupertinoIcons.info_circle_fill,
                  color: CupertinoColors.white,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _appName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.textStyle.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.24,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _versionSummary,
                    style: theme.textTheme.textStyle.copyWith(
                      fontSize: 12,
                      color: tokens.colors.secondaryLabel,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    packageText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.textStyle.copyWith(
                      fontSize: 11,
                      color: tokens.colors.tertiaryLabel,
                      letterSpacing: -0.16,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              'v$_version',
              style: theme.textTheme.textStyle.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: tokens.colors.accent,
                letterSpacing: -0.16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleShare() async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: _appShareDescription,
          subject: _appName,
        ),
      );
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'about.menu_share_it',
        message: '分享动作触发失败',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      await _showMessage('分享失败：${_errorSummary(error)}');
    }
  }

  Future<void> _openScoring() async {
    final packageName = _packageName.trim();
    if (packageName.isEmpty) {
      await _showMessage('未获取到应用包名，无法打开评分入口');
      return;
    }

    final marketUri = Uri.parse('market://details?id=$packageName');
    final webUri =
        Uri.parse('https://play.google.com/store/apps/details?id=$packageName');

    try {
      final marketStarted = await launchUrl(
        marketUri,
        mode: LaunchMode.externalApplication,
      );
      if (marketStarted) return;

      final webStarted = await launchUrl(
        webUri,
        mode: LaunchMode.externalApplication,
      );
      if (webStarted) return;

      await _showMessage('未找到可用的评分入口');
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'about.menu_scoring',
        message: '评分入口打开失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'packageName': packageName,
        },
      );
      if (!mounted) return;
      await _showMessage('评分入口打开失败：${_errorSummary(error)}');
    }
  }

  Future<void> _openContributors() async {
    await _openExternalUrl(
      _contributorsUrl,
      node: 'about.contributors',
      failureMessage: '打开开发人员页面失败',
    );
  }

  Future<void> _openCrashLogs() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => const ExceptionLogsView(
          title: '崩溃日志',
          emptyHint: '暂无崩溃日志',
        ),
      ),
    );
  }

  Future<void> _openUpdateLog() async {
    await _openDoc(
      title: '更新日志',
      assetPath: 'assets/docs/update_log.md',
      node: 'about.update_log',
    );
  }

  Future<void> _openPrivacyPolicy() async {
    await _openDoc(
      title: '用户隐私与协议',
      assetPath: 'assets/docs/privacy_policy.md',
      node: 'about.privacy_policy',
    );
  }

  Future<void> _openLicense() async {
    await _openDoc(
      title: '开源许可',
      assetPath: 'assets/docs/LICENSE.md',
      node: 'about.license',
    );
  }

  Future<void> _openDisclaimer() async {
    await _openDoc(
      title: '免责声明',
      assetPath: 'assets/docs/disclaimer.md',
      node: 'about.disclaimer',
    );
  }

  Future<void> _openDoc({
    required String title,
    required String assetPath,
    required String node,
  }) async {
    try {
      final markdownText = await rootBundle.loadString(assetPath);
      if (!mounted) return;
      await showAppHelpDialog(
        context,
        title: title,
        markdownText: markdownText,
      );
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: node,
        message: '文档加载失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{'assetPath': assetPath},
      );
      if (!mounted) return;
      await _showMessage('文档加载失败：${_errorSummary(error)}');
    }
  }

  Future<void> _saveLog() async {
    final settings = _settingsService.appSettings;
    final backupPath = settings.backupPath.trim();
    if (backupPath.isEmpty) {
      await _showMessage('未设置备份目录');
      return;
    }

    if (!settings.recordLog) {
      final shouldContinue = await _confirmAction(
        title: '记录日志未开启',
        message: '当前“记录日志”未开启，仍将导出当前已采集日志。',
        confirmText: '继续',
      );
      if (!shouldContinue) return;
    }

    try {
      final filePath = await _writeLogsToBackup(backupPath);
      _exceptionLogService.record(
        node: 'about.save_log',
        message: '日志保存成功',
        context: <String, dynamic>{
          'filePath': filePath,
          'entries': _exceptionLogService.count,
        },
      );
      await _showMessage('已保存至备份目录\n$filePath');
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'about.save_log',
        message: '日志保存失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'backupPath': backupPath,
        },
      );
      if (!mounted) return;
      await _showMessage('保存日志失败：${_errorSummary(error)}');
    }
  }

  Future<void> _createHeapDump() async {
    final settings = _settingsService.appSettings;
    final backupPath = settings.backupPath.trim();
    if (backupPath.isEmpty) {
      await _showMessage('未设置备份目录');
      return;
    }

    if (!settings.recordHeapDump) {
      final shouldContinue = await _confirmAction(
        title: '堆转储未开启',
        message: '当前“记录堆转储”未开启，仍将尝试创建诊断堆快照。',
        confirmText: '继续',
      );
      if (!shouldContinue) return;
    }

    try {
      final filePath = await _writeHeapDumpToBackup(backupPath);
      _exceptionLogService.record(
        node: 'about.create_heap_dump',
        message: '堆转储保存成功',
        context: <String, dynamic>{
          'filePath': filePath,
        },
      );
      await _showMessage('已保存至备份目录\n$filePath');
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'about.create_heap_dump',
        message: '创建堆转储失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'backupPath': backupPath,
        },
      );
      if (!mounted) return;
      await _showMessage('创建堆转储失败：${_errorSummary(error)}');
    }
  }

  Future<String> _writeLogsToBackup(String backupPath) async {
    final backupDir = Directory(backupPath);
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    final logsDir = Directory(p.join(backupDir.path, 'logs'));
    if (!await logsDir.exists()) {
      await logsDir.create(recursive: true);
    }

    final fileName = 'soupreader_logs_${_fileTimestamp()}.json';
    final file = File(p.join(logsDir.path, fileName));

    final payload = <String, dynamic>{
      'generatedAt': DateTime.now().toIso8601String(),
      'appName': _appName,
      'packageName': _packageName,
      'version': _version,
      'entries': _exceptionLogService.entries
          .map((entry) => entry.toJson())
          .toList(growable: false),
    };

    final content = const JsonEncoder.withIndent('  ').convert(payload);
    await file.writeAsString(content, flush: true);
    return file.path;
  }

  Future<String> _writeHeapDumpToBackup(String backupPath) async {
    final backupDir = Directory(backupPath);
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    final dumpDir = Directory(p.join(backupDir.path, 'heapDump'));
    if (!await dumpDir.exists()) {
      await dumpDir.create(recursive: true);
    }

    final fileName = 'soupreader_heap_dump_${_fileTimestamp()}.json';
    final file = File(p.join(dumpDir.path, fileName));

    final payload = <String, dynamic>{
      'generatedAt': DateTime.now().toIso8601String(),
      'note': 'Flutter 暂不支持原生 HPROF，本文件为运行时堆快照信息。',
      'currentRssBytes': ProcessInfo.currentRss,
      'maxRssBytes': ProcessInfo.maxRss,
      'logCount': _exceptionLogService.count,
      'recentLogNodes': _exceptionLogService.entries
          .take(20)
          .map((entry) => entry.node)
          .toList(growable: false),
    };

    final content = const JsonEncoder.withIndent('  ').convert(payload);
    await file.writeAsString(content, flush: true);
    return file.path;
  }

  String _fileTimestamp() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    String three(int v) => v.toString().padLeft(3, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}${three(now.millisecond)}';
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    required String confirmText,
  }) async {
    if (!mounted) return false;
    final confirmed = await showCupertinoBottomDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _openExternalUrl(
    String url, {
    required String node,
    required String failureMessage,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      await _showMessage('$failureMessage：链接无效');
      return;
    }

    try {
      final started = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (started) return;
      await _showMessage('$failureMessage：未找到可处理的应用');
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: node,
        message: failureMessage,
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{'url': url},
      );
      if (!mounted) return;
      await _showMessage('$failureMessage：${_errorSummary(error)}');
    }
  }

  Future<void> _checkUpdate() async {
    if (!mounted) return;
    showCupertinoBottomDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CupertinoActivityIndicator()),
    );

    _AppUpdateInfo? updateInfo;
    String? errorMessage;

    try {
      final response = await Dio().get(
        'https://github-action-cf.mcshr.workers.dev/latest',
      );
      if (response.statusCode != 200) {
        errorMessage = '检查更新失败：HTTP ${response.statusCode ?? '-'}';
      } else {
        final parsed = _parseUpdateInfo(response.data);
        if (parsed == null) {
          errorMessage = '检查更新失败：响应解析失败';
        } else if (parsed.downloadUrl.trim().isEmpty) {
          errorMessage = '检查更新失败：未找到安装包';
        } else if (parsed.updateBody.trim().isEmpty) {
          errorMessage = '检查更新失败：更新说明为空';
        } else {
          updateInfo = parsed;
        }
      }
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'app_update.check_update',
        message: '检查更新失败',
        error: error,
        stackTrace: stackTrace,
      );
      errorMessage = '检查更新失败：${_errorSummary(error)}';
    }

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    if (!mounted) return;

    if (updateInfo != null) {
      _showUpdateInfo(updateInfo);
      return;
    }
    await _showMessage(errorMessage ?? '检查更新失败');
  }

  Future<void> _showMessage(String message) async {
    if (!mounted) return;
    await showCupertinoBottomDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  String _errorSummary(Object error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      if (statusCode != null) {
        return 'HTTP $statusCode';
      }
      final message = error.message?.trim();
      if (message != null && message.isNotEmpty) {
        return message;
      }
    }
    final text = error.toString().trim();
    if (text.isEmpty) return '未知错误';
    if (text.length <= 120) return text;
    return '${text.substring(0, 120)}...';
  }

  _AppUpdateInfo? _parseUpdateInfo(dynamic rawData) {
    Map<String, dynamic>? map;
    if (rawData is Map) {
      map = rawData.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    } else if (rawData is String) {
      final rawText = rawData.trim();
      if (rawText.isEmpty) return null;
      try {
        final decoded = jsonDecode(rawText);
        if (decoded is Map) {
          map = decoded.map(
            (key, value) => MapEntry(key.toString(), value),
          );
        }
      } catch (_) {
        return null;
      }
    }
    if (map == null) return null;

    final tagName = _firstNonEmptyString([
          _readString(map, 'tag'),
          _readString(map, 'tagName'),
          _readString(map, 'version'),
        ]) ??
        'nightly';
    final name = _readString(map, 'name') ?? 'Nightly Build';
    final publishedAtText = _formatPublishedAt(_readString(map, 'publishedAt'));
    final updateBody = _firstNonEmptyString([
          _readString(map, 'updateLog'),
          _readString(map, 'body'),
          _readString(map, 'note'),
          _readString(map, 'description'),
          _readString(map, 'info'),
        ]) ??
        [
          name,
          if (publishedAtText != null && publishedAtText.isNotEmpty)
            publishedAtText,
        ].join('\n');
    final downloadUrl = _firstNonEmptyString([
          _readString(map, 'downloadUrl'),
          _readString(map, 'apkUrl'),
          _readString(map, 'url'),
          _readString(map, 'browser_download_url'),
        ]) ??
        '';
    final fileName = _firstNonEmptyString([
          _readString(map, 'fileName'),
          _readString(map, 'name'),
        ]) ??
        _fallbackApkName(tagName);
    return _AppUpdateInfo(
      tagName: tagName,
      updateBody: updateBody,
      downloadUrl: downloadUrl,
      fileName: fileName,
    );
  }

  String? _readString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  String? _firstNonEmptyString(List<String?> values) {
    for (final value in values) {
      final text = value?.trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  String? _formatPublishedAt(String? publishedAt) {
    final text = publishedAt?.trim() ?? '';
    if (text.isEmpty) return null;
    try {
      final date = DateTime.parse(text).toLocal();
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return text;
    }
  }

  String _fallbackApkName(String tagName) {
    final normalized = tagName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return 'soupreader_$normalized.apk';
  }

  void _showUpdateInfo(_AppUpdateInfo updateInfo) {
    showCupertinoBottomDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _AppUpdateDialog(
        updateInfo: updateInfo,
        onDownload: () => _handleDownloadAction(updateInfo),
      ),
    );
  }

  Future<void> _handleDownloadAction(_AppUpdateInfo updateInfo) async {
    final downloadUrl = updateInfo.downloadUrl.trim();
    final fileName = updateInfo.fileName.trim();
    if (downloadUrl.isEmpty || fileName.isEmpty) {
      return;
    }

    final uri = Uri.tryParse(downloadUrl);
    if (uri == null) {
      _exceptionLogService.record(
        node: 'app_update.menu_download',
        message: '更新下载链接无效',
        context: {
          'downloadUrl': downloadUrl,
          'fileName': fileName,
        },
      );
      await _showMessage('下载启动失败');
      return;
    }

    try {
      final started = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!started) {
        _exceptionLogService.record(
          node: 'app_update.menu_download',
          message: '更新下载未能启动',
          context: {
            'downloadUrl': downloadUrl,
            'fileName': fileName,
          },
        );
        await _showMessage('下载启动失败');
        return;
      }
      if (!mounted) return;
      await _showMessage('开始下载');
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'app_update.menu_download',
        message: '更新下载触发失败',
        error: error,
        stackTrace: stackTrace,
        context: {
          'downloadUrl': downloadUrl,
          'fileName': fileName,
        },
      );
      if (!mounted) return;
      await _showMessage('下载启动失败');
    }
  }
}

class _AppUpdateInfo {
  final String tagName;
  final String updateBody;
  final String downloadUrl;
  final String fileName;

  const _AppUpdateInfo({
    required this.tagName,
    required this.updateBody,
    required this.downloadUrl,
    required this.fileName,
  });
}

class _AppUpdateDialog extends StatefulWidget {
  final _AppUpdateInfo updateInfo;
  final Future<void> Function() onDownload;

  const _AppUpdateDialog({
    required this.updateInfo,
    required this.onDownload,
  });

  @override
  State<_AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<_AppUpdateDialog> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final width = math.min(screenSize.width * 0.92, 680.0);
    final height = math.min(screenSize.height * 0.82, 760.0);
    final ui = AppUiTokens.resolve(context);
    final separator = ui.colors.separator.withValues(alpha: 0.78);

    return Center(
      child: SizedBox(
        width: width,
        height: height,
        child: AppSheetPanel(
          contentPadding: EdgeInsets.zero,
          radius: ui.radii.sheet,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                  child: Row(
                    children: [
                      CupertinoButton(
                        padding: const EdgeInsets.all(4),
                        onPressed: () => Navigator.of(context).pop(),
                        minimumSize: const Size(30, 30),
                        child: const Icon(CupertinoIcons.xmark),
                      ),
                      Expanded(
                        child: Text(
                          widget.updateInfo.tagName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        onPressed: widget.onDownload,
                        minimumSize: const Size(30, 30),
                        child: const Text('下载'),
                      ),
                    ],
                  ),
                ),
                Container(height: ui.sizes.dividerThickness, color: separator),
                Expanded(
                  child: CupertinoScrollbar(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
                      child: SelectableRegion(
                        focusNode: _focusNode,
                        selectionControls: cupertinoTextSelectionControls,
                        child: Text(
                          widget.updateInfo.updateBody,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.48,
                            color: ui.colors.label,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
