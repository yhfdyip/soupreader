import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_popover_menu.dart';
import '../../../app/widgets/app_toast.dart';
import '../../../app/widgets/app_ui_kit.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import 'package:flutter/services.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/models/backup_restore_ignore_config.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/services/backup_restore_ignore_service.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/webdav_service.dart';
import 'app_help_dialog.dart';
import 'app_log_dialog.dart';

class BackupSettingsView extends StatefulWidget {
  const BackupSettingsView({super.key});

  @override
  State<BackupSettingsView> createState() => _BackupSettingsViewState();
}

class _BackupSettingsViewState extends State<BackupSettingsView> {
  static const int _autoCheckPromptGapMs = 60 * 1000;

  final GlobalKey _moreMenuKey = GlobalKey();
  final BackupService _backupService = BackupService();
  final BackupRestoreIgnoreService _backupRestoreIgnoreService =
      BackupRestoreIgnoreService();
  final ExceptionLogService _exceptionLogService = ExceptionLogService();
  final SettingsService _settingsService = SettingsService();
  final WebDavService _webDavService = WebDavService();
  bool _loadingHelp = false;
  bool _checkingAutoCheckNewBackup = false;
  bool _autoCheckNewBackupTriggered = false;
  bool _restoringDetectedBackup = false;
  bool _lastAutoCheckNewBackupEnabled = false;
  String? _autoCheckNewBackupError;
  WebDavRemoteEntry? _detectedNewBackup;
  BackupRestoreIgnoreConfig _restoreIgnoreConfig =
      const BackupRestoreIgnoreConfig();

  @override
  void initState() {
    super.initState();
    _restoreIgnoreConfig = _backupRestoreIgnoreService.load();
    _lastAutoCheckNewBackupEnabled =
        _settingsService.appSettings.autoCheckNewBackup;
    _settingsService.appSettingsListenable.addListener(_onSettingsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerAutoCheckNewBackupOnPageEnter();
    });
  }

  @override
  void dispose() {
    _settingsService.appSettingsListenable.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    final enabled = _settingsService.appSettings.autoCheckNewBackup;
    if (!enabled) {
      _autoCheckNewBackupTriggered = false;
      setState(() {
        _detectedNewBackup = null;
        _autoCheckNewBackupError = null;
        _checkingAutoCheckNewBackup = false;
      });
      _lastAutoCheckNewBackupEnabled = enabled;
      return;
    }
    if (enabled && !_lastAutoCheckNewBackupEnabled) {
      _triggerAutoCheckNewBackupOnPageEnter(force: true);
    } else if (!_autoCheckNewBackupTriggered && !_checkingAutoCheckNewBackup) {
      _triggerAutoCheckNewBackupOnPageEnter();
    }
    _lastAutoCheckNewBackupEnabled = enabled;
    setState(() {});
  }

  Future<void> _onAutoCheckNewBackupChanged(bool enabled) async {
    await _settingsService.saveAutoCheckNewBackup(enabled);
    if (!mounted) return;
    if (!enabled) {
      setState(() {
        _detectedNewBackup = null;
        _autoCheckNewBackupError = null;
        _checkingAutoCheckNewBackup = false;
      });
      return;
    }
    await _triggerAutoCheckNewBackupOnPageEnter(force: true);
  }

  /// 进入备份页时自动检查“是否存在比本地记录更新的 WebDav 备份”。
  ///
  /// 对齐 legado `MainActivity.backupSync` 的核心语义：
  /// 1) 开关关闭时不检查；
  /// 2) 仅比较最新备份时间与本地记录时间；
  /// 3) 差值超过 1 分钟判定为“新备份”；
  /// 4) 命中新备份时先写入“已提示时间”，再展示恢复提示，避免重复弹出。
  Future<void> _triggerAutoCheckNewBackupOnPageEnter({
    bool force = false,
  }) async {
    final settings = _settingsService.appSettings;
    if (!settings.autoCheckNewBackup) return;
    if (_checkingAutoCheckNewBackup) return;
    if (_autoCheckNewBackupTriggered && !force) return;
    if (!_hasWebDavCredential(settings)) {
      if (mounted) {
        setState(() {
          _detectedNewBackup = null;
          _autoCheckNewBackupError = null;
          _checkingAutoCheckNewBackup = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _checkingAutoCheckNewBackup = true;
        _autoCheckNewBackupError = null;
      });
    }

    try {
      final backups = await _webDavService.listBackupFiles(settings: settings);
      if (!mounted) return;
      _autoCheckNewBackupTriggered = true;

      if (backups.isEmpty) {
        setState(() {
          _detectedNewBackup = null;
        });
        return;
      }

      final latestBackup = backups.first;
      final remoteLastModify = latestBackup.lastModify;
      if (remoteLastModify <= 0) {
        setState(() {
          _detectedNewBackup = null;
        });
        return;
      }

      final lastSeenMillis = _settingsService.getLastSeenWebDavBackupMillis();
      final hasNewerBackup =
          remoteLastModify - lastSeenMillis > _autoCheckPromptGapMs;
      if (!hasNewerBackup) {
        setState(() {
          _detectedNewBackup = null;
        });
        return;
      }

      // 与 legado 一致：提示前先更新本地“已提示时间”，避免同一远端备份重复提示。
      await _settingsService.saveLastSeenWebDavBackupMillis(remoteLastModify);
      if (!mounted) return;
      setState(() {
        _detectedNewBackup = latestBackup;
      });
    } catch (error, stackTrace) {
      _autoCheckNewBackupTriggered = true;
      _exceptionLogService.record(
        node: 'backup_settings.auto_check_new_backup',
        message: '进入备份页自动检查远端新备份失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'webDavUrl': settings.webDavUrl,
          'hasAccount': settings.webDavAccount.trim().isNotEmpty,
          'hasPassword': settings.webDavPassword.trim().isNotEmpty,
        },
      );
      if (!mounted) return;
      setState(() {
        _detectedNewBackup = null;
        _autoCheckNewBackupError = _normalizeErrorMessage(error);
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _checkingAutoCheckNewBackup = false;
      });
    }
  }

  List<Widget> _buildAutoCheckNewBackupPromptTiles() {
    final enabled = _settingsService.appSettings.autoCheckNewBackup;
    if (!enabled) return const <Widget>[];

    if (_checkingAutoCheckNewBackup) {
      return <Widget>[
        const AppListTile(
          title: Text('自动检查新备份'),
          additionalInfo: Text('正在检查 WebDav 远端备份'),
          trailing: CupertinoActivityIndicator(),
          showChevron: false,
        ),
      ];
    }

    final detected = _detectedNewBackup;
    if (detected != null) {
      return <Widget>[
        AppListTile(
          title: const Text('检测到较新的 WebDav 备份'),
          additionalInfo: Text(_backupEntrySummary(detected)),
          trailing: _restoringDetectedBackup
              ? const CupertinoActivityIndicator()
              : null,
          onTap: _restoringDetectedBackup
              ? null
              : () => _confirmRestoreDetectedBackup(detected),
        ),
      ];
    }

    if (_autoCheckNewBackupError != null &&
        _autoCheckNewBackupError!.trim().isNotEmpty) {
      return <Widget>[
        AppListTile(
          title: const Text('自动检查失败'),
          additionalInfo: Text(_brief(_autoCheckNewBackupError!)),
          onTap: () => _triggerAutoCheckNewBackupOnPageEnter(force: true),
        ),
      ];
    }
    return const <Widget>[];
  }

  Future<void> _confirmRestoreDetectedBackup(WebDavRemoteEntry entry) async {
    final confirmed = await showCupertinoBottomSheetDialog<bool>(
          context: context,
          builder: (dialogContext) => CupertinoAlertDialog(
            title: const Text('恢复'),
            content: Text(
              '检测到 WebDav 备份比本地更新，是否恢复？\n'
              '${entry.displayName}\n'
              '${_backupEntrySummary(entry)}',
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('恢复'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    setState(() {
      _restoringDetectedBackup = true;
      _autoCheckNewBackupError = null;
      _detectedNewBackup = null;
    });

    final restored = await _restoreSelectedWebDavBackup(entry);
    if (!mounted) return;
    setState(() {
      _restoringDetectedBackup = false;
      if (!restored) {
        // 恢复失败时保留提示入口，允许用户重试。
        _detectedNewBackup = entry;
      }
    });
  }

  bool _hasWebDavCredential(AppSettings settings) {
    return settings.webDavAccount.trim().isNotEmpty &&
        settings.webDavPassword.trim().isNotEmpty;
  }

  String _normalizeErrorMessage(Object error) {
    final raw = error.toString().trim();
    if (raw.isEmpty) {
      return '未知错误';
    }
    const prefixes = <String>[
      'Exception:',
      'WebDavOperationException:',
    ];
    for (final prefix in prefixes) {
      if (raw.startsWith(prefix)) {
        final message = raw.substring(prefix.length).trim();
        if (message.isNotEmpty) {
          return message;
        }
      }
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settingsService.appSettings;
    return AppCupertinoPageScaffold(
      title: '备份与恢复',
      trailing: _buildTrailingActions(),
      child: AppListView(
        children: [
          AppListSection(
            header: const Text('导出'),
            hasLeading: false,
            children: [
              AppListTile(
                title: const Text('导出备份（推荐）'),                onTap: () => _export(includeOnlineCache: false),
              ),
              AppListTile(
                title: const Text('导出（含在线缓存）'),                onTap: () => _export(includeOnlineCache: true),
              ),
            ],
          ),
          AppListSection(
            header: const Text('导入'),
            hasLeading: false,
            children: [
              AppListTile(
                title: const Text('从文件导入（合并）'),                onTap: () => _import(overwrite: false),
              ),
              AppListTile(
                title: const Text('从文件导入（覆盖）'),                onTap: () => _import(overwrite: true),
              ),
            ],
          ),
          AppListSection(
            header: const Text('WebDav 同步'),
            hasLeading: false,
            children: [
              AppListTile(
                title: const Text('服务器地址'),
                additionalInfo: Text(
                  _brief(settings.webDavUrl),
                ),
                onTap: () => _editWebDavField(
                  title: '服务器地址',
                  placeholder: 'https://dav.example.com/dav/',
                  initialValue: settings.webDavUrl,
                  onSave: (value) async {
                    await _settingsService.saveAppSettings(
                      _settingsService.appSettings.copyWith(webDavUrl: value),
                    );
                  },
                ),
              ),
              AppListTile(
                title: const Text('账号'),
                additionalInfo: Text(
                  _brief(settings.webDavAccount),
                ),
                onTap: () => _editWebDavField(
                  title: 'WebDav 账号',
                  placeholder: '请输入账号',
                  initialValue: settings.webDavAccount,
                  onSave: (value) async {
                    await _settingsService.saveAppSettings(
                      _settingsService.appSettings
                          .copyWith(webDavAccount: value),
                    );
                  },
                ),
              ),
              AppListTile(
                title: const Text('密码'),
                additionalInfo: Text(
                  _maskSecret(settings.webDavPassword),
                ),
                onTap: () => _editWebDavField(
                  title: 'WebDav 密码',
                  placeholder: '请输入密码',
                  initialValue: settings.webDavPassword,
                  obscureText: true,
                  onSave: (value) async {
                    await _settingsService.saveAppSettings(
                      _settingsService.appSettings
                          .copyWith(webDavPassword: value),
                    );
                  },
                ),
              ),
              AppListTile(
                title: const Text('同步目录'),
                additionalInfo: Text(
                  _brief(settings.webDavDir, fallback: 'legado'),
                ),
                onTap: () => _editWebDavField(
                  title: '同步目录',
                  placeholder: '可留空，例如 booksync',
                  initialValue: settings.webDavDir,
                  onSave: (value) async {
                    await _settingsService.saveAppSettings(
                      _settingsService.appSettings.copyWith(webDavDir: value),
                    );
                  },
                ),
              ),
              AppListTile(
                title: const Text('设备名称'),
                additionalInfo: Text(_brief(settings.webDavDeviceName)),
                onTap: () => _editWebDavField(
                  title: '设备名称',
                  placeholder: '可留空，用于区分备份来源设备',
                  initialValue: settings.webDavDeviceName,
                  onSave: _settingsService.saveWebDavDeviceName,
                ),
              ),
              AppListTile(
                title: const Text('同步阅读进度'),                trailing: CupertinoSwitch(
                  value: settings.syncBookProgress,
                  onChanged: _settingsService.saveSyncBookProgress,
                ),
              ),
              AppListTile(
                title: const Text('同步增强'),                trailing: CupertinoSwitch(
                  value: settings.syncBookProgressPlus,
                  onChanged: settings.syncBookProgress
                      ? _settingsService.saveSyncBookProgressPlus
                      : null,
                ),
              ),
              AppListTile(
                title: const Text('测试连接'),                onTap: _testWebDavConnection,
              ),
            ],
          ),
          AppListSection(
            header: const Text('备份恢复'),
            hasLeading: false,
            children: [
              AppListTile(
                title: const Text('备份路径'),
                additionalInfo: Text(
                  _brief(settings.backupPath, fallback: '请选择备份路径'),
                ),
                onTap: _editBackupPath,
              ),
              AppListTile(
                title: const Text('备份到 WebDav'),                onTap: _backupToWebDav,
              ),
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onLongPress: _restoreFromLocal,
                child: AppListTile(
                  title: const Text('从 WebDav 恢复'),                  onTap: _restoreFromWebDav,
                ),
              ),
              ..._buildAutoCheckNewBackupPromptTiles(),
              AppListTile(
                title: const Text('恢复时忽略'),
                additionalInfo: Text(_brief(_restoreIgnoreConfig.summary())),
                onTap: _editRestoreIgnore,
              ),
              AppListTile(
                key: const Key('import_old'),
                title: const Text('导入旧数据'),                onTap: _importOldData,
              ),
              AppListTile(
                title: const Text('仅保留最新备份'),                trailing: CupertinoSwitch(
                  value: settings.onlyLatestBackup,
                  onChanged: _settingsService.saveOnlyLatestBackup,
                ),
              ),
              AppListTile(
                title: const Text('自动检查新备份'),                trailing: CupertinoSwitch(
                  value: settings.autoCheckNewBackup,
                  onChanged: _onAutoCheckNewBackupChanged,
                ),
              ),
            ],
          ),
          const AppListSection(
            header: Text('说明'),
            hasLeading: false,
            children: [
              AppListTile(
                title: Text('备份包含：设置、书源、书架、本地书籍章节内容，以及“本书独立阅读设置”。'),
                showChevron: false,
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTrailingActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_loadingHelp)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: CupertinoActivityIndicator(radius: 9),
          )
        else
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _openWebDavHelp,
            child: const Icon(CupertinoIcons.question_circle, size: 22),
            minimumSize: Size(30, 30),
          ),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _showMoreActions,
          key: _moreMenuKey,
          child: const Icon(CupertinoIcons.ellipsis_circle, size: 22),
          minimumSize: Size(30, 30),
        ),
      ],
    );
  }

  Future<void> _openWebDavHelp() async {
    if (_loadingHelp) return;
    setState(() => _loadingHelp = true);
    try {
      final markdownText =
          await rootBundle.loadString('assets/web/help/md/webDavBookHelp.md');
      if (!mounted) return;
      await showAppHelpDialog(
        context,
        markdownText: markdownText,
      );
    } catch (error) {
      if (!mounted) return;
      await showCupertinoBottomSheetDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('帮助'),
          content: Text('帮助文档加载失败：$error'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() => _loadingHelp = false);
    }
  }

  Future<void> _showMoreActions() async {
    final selected = await showAppPopoverMenu<_BackupMoreAction>(
      context: context,
      anchorKey: _moreMenuKey,
      items: const [
        AppPopoverMenuItem(
          value: _BackupMoreAction.logs,
          icon: CupertinoIcons.doc_text,
          label: '日志',
        ),
      ],
    );
    if (selected == _BackupMoreAction.logs && mounted) {
      await showAppLogDialog(context);
    }
  }

  Future<void> _export({required bool includeOnlineCache}) async {
    showCupertinoBottomSheetDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CupertinoActivityIndicator()),
    );
    final result = await _backupService.exportToFile(
      includeOnlineCache: includeOnlineCache,
    );
    if (!mounted) return;
    Navigator.pop(context);
    if (result.cancelled) return;
    if (result.success) {
      await _syncBackupCompareBaselineNow(reason: 'export_to_file');
      unawaited(showAppToast(context, message: '导出成功'));
      return;
    }
    _exceptionLogService.record(
      node: 'backup_settings.export_file',
      message: '导出备份失败',
      context: <String, dynamic>{
        'includeOnlineCache': includeOnlineCache,
        'errorMessage': result.errorMessage,
      },
    );
    _showMessage(result.errorMessage ?? '导出失败');
  }

  Future<void> _import({required bool overwrite}) async {
    final ignoreConfig = _backupRestoreIgnoreService.load();
    if (mounted) {
      setState(() {
        _restoreIgnoreConfig = ignoreConfig;
      });
    }

    if (overwrite) {
      final confirmed = await showCupertinoBottomSheetDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('确认覆盖导入？'),
          content: const Text('\n将清空当前书架、书源与缓存，再从备份恢复。此操作不可撤销。'),
          actions: [
            CupertinoDialogAction(
              child: const Text('取消'),
              onPressed: () => Navigator.pop(context, false),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text('继续'),
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    if (!mounted) return;
    showCupertinoBottomSheetDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CupertinoActivityIndicator()),
    );
    final result = await _backupService.importFromFile(
      overwrite: overwrite,
      ignoreConfig: ignoreConfig,
    );
    if (!mounted) return;
    Navigator.pop(context);
    if (result.cancelled) return;
    if (!result.success) {
      _exceptionLogService.record(
        node: 'backup_settings.import_file',
        message: '从文件导入备份失败',
        context: <String, dynamic>{
          'overwrite': overwrite,
          'errorMessage': result.errorMessage,
        },
      );
      _showMessage(result.errorMessage ?? '导入失败');
      return;
    }
    await _syncBackupCompareBaselineNow(
      reason: overwrite ? 'import_file_overwrite' : 'import_file_merge',
    );
    _showImportResult(
      result,
      prefix:
          '导入完成：书源 ${result.sourcesImported} 条，书籍 ${result.booksImported} 本，章节 ${result.chaptersImported} 章',
    );
  }

  Future<void> _backupToWebDav() async {
    final settings = _settingsService.appSettings;
    showCupertinoBottomSheetDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CupertinoActivityIndicator()),
    );
    String message;
    try {
      final payload = _backupService.buildUploadPayload(
        onlyLatestBackup: settings.onlyLatestBackup,
        deviceName: settings.webDavDeviceName,
      );
      final remoteUrl = await _webDavService.uploadBackupBytes(
        settings: settings,
        fileName: payload.fileName,
        bytes: payload.bytes,
      );
      await _syncBackupCompareBaselineNow(reason: 'backup_to_webdav');
      message = 'WebDav 备份成功\n文件：${payload.fileName}\n远端：$remoteUrl';
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'backup_settings.backup_to_webdav',
        message: '备份到 WebDav 失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'webDavUrl': settings.webDavUrl,
          'onlyLatestBackup': settings.onlyLatestBackup,
        },
      );
      message = 'WebDav 备份失败\n$error';
    }
    if (!mounted) return;
    Navigator.pop(context);
    _showMessage(message);
  }

  Future<void> _restoreFromWebDav() async {
    final settings = _settingsService.appSettings;
    showCupertinoBottomSheetDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CupertinoActivityIndicator()),
    );

    List<WebDavRemoteEntry> backups = const <WebDavRemoteEntry>[];
    try {
      backups = await _webDavService.listBackupFiles(settings: settings);
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'backup_settings.list_webdav_backups',
        message: '拉取 WebDav 备份列表失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'webDavUrl': settings.webDavUrl,
          'hasAccount': settings.webDavAccount.trim().isNotEmpty,
          'hasPassword': settings.webDavPassword.trim().isNotEmpty,
        },
      );
      if (!mounted) return;
      Navigator.pop(context);
      await _showWebDavRestoreFallback(error.toString());
      return;
    }
    if (!mounted) return;
    Navigator.pop(context);

    if (backups.isEmpty) {
      await _showWebDavRestoreFallback('WebDav 无可用备份文件');
      return;
    }

    final selected = await _pickWebDavBackupFile(backups);
    if (selected == null) return;
    await _restoreSelectedWebDavBackup(selected);
  }

  Future<void> _restoreFromLocal() async {
    await _import(overwrite: false);
  }

  Future<void> _importOldData() async {
    String? selectedDirectory;
    try {
      selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择旧版备份文件夹',
      );
    } catch (error) {
      _showMessage('选择旧版备份文件夹失败：$error');
      return;
    }
    if (selectedDirectory == null || selectedDirectory.trim().isEmpty) {
      return;
    }

    showCupertinoBottomSheetDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CupertinoActivityIndicator()),
    );

    final result = await _backupService.importOldVersionDirectory(
      selectedDirectory,
    );
    if (!mounted) return;
    Navigator.pop(context);

    if (!result.success) {
      _exceptionLogService.record(
        node: 'backup_settings.import_legacy_directory',
        message: '导入旧版数据失败',
        context: <String, dynamic>{
          'selectedDirectory': selectedDirectory,
          'errorMessage': result.errorMessage,
        },
      );
      _showMessage(result.errorMessage ?? '导入旧数据失败');
      return;
    }
    await _syncBackupCompareBaselineNow(reason: 'import_legacy_directory');
    _showMessage(
      '导入旧数据完成：书源 ${result.sourcesImported} 条，书籍 ${result.booksImported} 本，替换规则 ${result.replaceRulesImported} 条',
    );
  }

  Future<WebDavRemoteEntry?> _pickWebDavBackupFile(
    List<WebDavRemoteEntry> backups,
  ) async {
    return showCupertinoBottomSheetDialog<WebDavRemoteEntry>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('选择恢复文件'),
        content: SizedBox(
          width: double.maxFinite,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final entry in backups)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(dialogContext, entry),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.displayName,
                          style: CupertinoTheme.of(context)
                              .textTheme
                              .textStyle
                              .copyWith(fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _backupEntrySummary(entry),
                          style: CupertinoTheme.of(context)
                              .textTheme
                              .tabLabelTextStyle
                              .copyWith(
                                fontSize: 12,
                                color: CupertinoColors.systemGrey.resolveFrom(context),
                              ),
                        ),
                      ],
                    ),
                    minimumSize: Size(44, 44),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
        ],
      ),
    );
  }

  Future<bool> _restoreSelectedWebDavBackup(WebDavRemoteEntry entry) async {
    showCupertinoBottomSheetDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CupertinoActivityIndicator()),
    );

    try {
      final bytes = await _webDavService.downloadFileBytes(
        settings: _settingsService.appSettings,
        remoteUrl: entry.path,
      );
      final result =
          await _backupService.importFromBytesWithStoredIgnore(bytes);
      if (!mounted) return false;
      Navigator.pop(context);
      if (!result.success) {
        _exceptionLogService.record(
          node: 'backup_settings.restore_webdav_backup',
          message: '恢复 WebDav 备份失败',
          context: <String, dynamic>{
            'remotePath': entry.path,
            'displayName': entry.displayName,
            'errorMessage': result.errorMessage,
          },
        );
        await _showWebDavRestoreFallback(result.errorMessage ?? 'WebDav 恢复失败');
        return false;
      }
      if (entry.lastModify > 0) {
        await _settingsService.saveLastSeenWebDavBackupMillis(entry.lastModify);
      } else {
        await _syncBackupCompareBaselineNow(reason: 'restore_webdav_backup');
      }
      _showImportResult(
        result,
        prefix:
            'WebDav 恢复完成：书源 ${result.sourcesImported} 条，书籍 ${result.booksImported} 本，章节 ${result.chaptersImported} 章',
      );
      return true;
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'backup_settings.restore_webdav_backup',
        message: '恢复 WebDav 备份发生异常',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'remotePath': entry.path,
          'displayName': entry.displayName,
        },
      );
      if (!mounted) return false;
      Navigator.pop(context);
      await _showWebDavRestoreFallback(error.toString());
      return false;
    }
  }

  Future<void> _showWebDavRestoreFallback(String errorMessage) async {
    if (!mounted) return;
    final shouldFallback = await showCupertinoBottomSheetDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('恢复'),
        content: Text(
          'WebDavError\n$errorMessage\n将从本地备份恢复。',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          CupertinoDialogAction(
            child: const Text('回退本地恢复'),
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );
    if (shouldFallback == true) {
      await _restoreFromLocal();
    }
  }

  void _showImportResult(
    BackupImportResult result, {
    required String prefix,
  }) {
    final lines = <String>[prefix];
    if (result.ignoredOptions.isNotEmpty) {
      lines.add('恢复时忽略：${result.ignoredOptions.join('、')}');
    }
    if (result.ignoredLocalBooks > 0) {
      lines.add('已跳过本地书籍 ${result.ignoredLocalBooks} 本');
    }
    _showMessage(lines.join('\n'));
  }

  String _backupEntrySummary(WebDavRemoteEntry entry) {
    final size = _formatFileSize(entry.size);
    final time =
        entry.lastModify > 0 ? _formatDateTime(entry.lastModify) : '时间未知';
    return '$time · $size';
  }

  String _formatDateTime(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _editRestoreIgnore() async {
    final current = _backupRestoreIgnoreService.load();
    final selected = <String>{};
    for (final option in BackupRestoreIgnoreConfig.options) {
      if (!current.isIgnored(option.key)) continue;
      selected.add(option.key);
    }
    final result = await showCupertinoBottomSheetDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => CupertinoAlertDialog(
          title: const Text('恢复时忽略'),
          content: SizedBox(
            width: double.maxFinite,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final option in BackupRestoreIgnoreConfig.options)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        setDialogState(() {
                          if (!selected.add(option.key)) {
                            selected.remove(option.key);
                          }
                        });
                      },
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              option.title,
                              style: CupertinoTheme.of(context)
                                  .textTheme
                                  .textStyle
                                  .copyWith(fontSize: 16),
                            ),
                          ),
                          if (selected.contains(option.key))
                            const Icon(
                              CupertinoIcons.check_mark,
                              size: 18,
                            ),
                        ],
                      ),
                      minimumSize: Size(34, 34),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('取消'),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            CupertinoDialogAction(
              child: const Text('保存'),
              onPressed: () =>
                  Navigator.pop(dialogContext, Set<String>.from(selected)),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    await _backupRestoreIgnoreService.saveSelectedKeys(result);
    final next = _backupRestoreIgnoreService.load();
    if (!mounted) return;
    setState(() {
      _restoreIgnoreConfig = next;
    });
    unawaited(showAppToast(context, message: '已保存：${next.summary(maxItems: 3)}'));
  }

  Future<void> _editBackupPath() async {
    await _editWebDavField(
      title: '备份路径',
      placeholder: '请输入备份目录路径',
      initialValue: _settingsService.appSettings.backupPath,
      onSave: _settingsService.saveBackupPath,
    );
  }

  Future<void> _editWebDavField({
    required String title,
    required String placeholder,
    required String initialValue,
    required Future<void> Function(String value) onSave,
    bool obscureText = false,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showCupertinoBottomSheetDialog<String>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: placeholder,
            obscureText: obscureText,
            maxLines: 1,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          CupertinoDialogAction(
            child: const Text('保存'),
            onPressed: () => Navigator.pop(dialogContext, controller.text),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    await onSave(result.trim());
    if (!mounted) return;
    unawaited(showAppToast(context, message: '已保存'));
  }

  Future<void> _testWebDavConnection() async {
    showCupertinoBottomSheetDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CupertinoActivityIndicator()),
    );

    var message = '连接成功，已准备 WebDav books 目录';
    try {
      await _webDavService
          .ensureUploadDirectories(_settingsService.appSettings);
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'backup_settings.test_webdav_connection',
        message: '测试 WebDav 连接失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'webDavUrl': _settingsService.appSettings.webDavUrl,
          'hasAccount':
              _settingsService.appSettings.webDavAccount.trim().isNotEmpty,
          'hasPassword':
              _settingsService.appSettings.webDavPassword.trim().isNotEmpty,
        },
      );
      message = error.toString();
    } finally {
      if (mounted) {
        Navigator.pop(context);
      }
    }

    if (!mounted) return;
    _showMessage(message);
  }

  /// 同步“自动检查新备份”的本地对照时间。
  ///
  /// 与 legado `LocalConfig.lastBackup` 语义对齐：
  /// 本地备份/恢复成功后也要推进对照时间，避免旧远端备份被重复判定为“新备份”。
  Future<void> _syncBackupCompareBaselineNow({
    required String reason,
  }) async {
    try {
      await _settingsService.saveLastSeenWebDavBackupMillis(
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'backup_settings.sync_compare_baseline',
        message: '更新自动检查新备份对照时间失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{'reason': reason},
      );
    }
  }

  String _brief(String value, {String fallback = '未设置'}) {
    final text = value.trim();
    if (text.isEmpty) return fallback;
    if (text.length <= 22) return text;
    return '${text.substring(0, 22)}…';
  }

  String _maskSecret(String value) {
    final text = value.trim();
    if (text.isEmpty) return '未设置';
    return '已设置（${text.length} 位）';
  }

  void _showMessage(String message) {
    showCupertinoBottomSheetDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            child: const Text('好'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

enum _BackupMoreAction {
  logs,
}
