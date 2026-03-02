import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_ui_kit.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import 'package:flutter/foundation.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/option_picker_sheet.dart';
import '../../../core/config/migration_exclusions.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/services/settings_service.dart';
import '../services/check_source_settings_service.dart';
import '../services/direct_link_upload_config_service.dart';
import '../services/other_source_settings_service.dart';
import 'check_source_settings_view.dart';
import 'direct_link_upload_config_view.dart';
import 'storage_settings_view.dart';

class OtherSettingsView extends StatefulWidget {
  const OtherSettingsView({super.key});

  @override
  State<OtherSettingsView> createState() => _OtherSettingsViewState();
}

class _OtherSettingsViewState extends State<OtherSettingsView> {
  final SettingsService _settingsService = SettingsService();
  final DirectLinkUploadConfigService _directLinkUploadConfigService =
      DirectLinkUploadConfigService();
  final OtherSourceSettingsService _otherSourceSettingsService =
      OtherSourceSettingsService();
  final CheckSourceSettingsService _checkSourceSettingsService =
      CheckSourceSettingsService();
  late AppSettings _appSettings;
  String _directLinkUploadSummary = '未设置';
  String _userAgentSummary = OtherSourceSettingsService.defaultUserAgent;
  String _defaultBookTreeUriSummary = '从其它应用打开的书籍保存位置';
  String _sourceEditMaxLineSummary = OtherSourceSettingsService()
      .sourceEditMaxLineSummary(
          OtherSourceSettingsService.defaultSourceEditMaxLine);
  String _checkSourceSummary = _fallbackCheckSourceSummary;

  static const String _fallbackCheckSourceSummary =
      '校验超时：180秒\n校验项目： 搜索 发现 详情 目录 正文';

  bool get _excludeRss => MigrationExclusions.excludeRss;
  bool get _excludeTts => MigrationExclusions.excludeTts;
  bool get _excludeManga => MigrationExclusions.excludeManga;
  bool get _excludeWebService => MigrationExclusions.excludeWebService;

  @override
  void initState() {
    super.initState();
    _appSettings = _settingsService.appSettings;
    _settingsService.appSettingsListenable.addListener(_onChanged);
    unawaited(_loadDirectLinkUploadSummary());
    unawaited(_reloadSourceSettingsSummaries());
  }

  @override
  void dispose() {
    _settingsService.appSettingsListenable.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() => _appSettings = _settingsService.appSettings);
  }

  Future<void> _loadDirectLinkUploadSummary() async {
    final rule = await _directLinkUploadConfigService.loadRule();
    final summary = rule.summary.trim();
    if (!mounted) return;
    setState(() {
      _directLinkUploadSummary = summary.isEmpty ? '未设置' : summary;
    });
  }

  Future<void> _reloadSourceSettingsSummaries() async {
    final userAgent = _otherSourceSettingsService.getUserAgent();
    final defaultBookTreeUri =
        _otherSourceSettingsService.getDefaultBookTreeUri();
    final sourceEditMaxLine =
        _otherSourceSettingsService.getSourceEditMaxLine();
    final sourceEditSummary =
        _otherSourceSettingsService.sourceEditMaxLineSummary(sourceEditMaxLine);
    final checkSourceSummary = _checkSourceSettingsService.loadSummary();
    if (!mounted) return;
    setState(() {
      _userAgentSummary = userAgent;
      _defaultBookTreeUriSummary = defaultBookTreeUri?.trim().isNotEmpty == true
          ? defaultBookTreeUri!.trim()
          : '从其它应用打开的书籍保存位置';
      _sourceEditMaxLineSummary = sourceEditSummary;
      _checkSourceSummary = checkSourceSummary.trim().isEmpty
          ? _fallbackCheckSourceSummary
          : checkSourceSummary.trim();
    });
  }

  Future<void> _openDirectLinkUploadConfig() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => const DirectLinkUploadConfigView(),
      ),
    );
    if (!mounted) return;
    await _loadDirectLinkUploadSummary();
  }

  Future<void> _editUserAgent() async {
    final controller = TextEditingController(
      text: _otherSourceSettingsService.getUserAgent(),
    );
    final value = await showCupertinoBottomDialog<String>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('用户代理'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: '用户代理',
            maxLines: 5,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    await _otherSourceSettingsService.saveUserAgent(value);
    await _reloadSourceSettingsSummaries();
  }

  Future<void> _selectDefaultBookTreeUri() async {
    try {
      final selected = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择保存书籍的文件夹',
      );
      if (selected == null || selected.trim().isEmpty) return;
      await _otherSourceSettingsService.saveDefaultBookTreeUri(selected);
      await _reloadSourceSettingsSummaries();
    } catch (error) {
      _showMessage('选择保存书籍的文件夹失败：$error');
    }
  }

  Future<void> _editSourceEditMaxLine() async {
    final controller = TextEditingController(
      text: _otherSourceSettingsService.getSourceEditMaxLine().toString(),
    );
    final value = await showCupertinoBottomDialog<String>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('源编辑框最大行数'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            keyboardType: TextInputType.number,
            placeholder: '请输入大于等于 10 的整数',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    final parsed = int.tryParse(value.trim()) ?? 0;
    if (parsed < OtherSourceSettingsService.minSourceEditMaxLine) {
      _showMessage('源编辑框最大行数不能小于 10');
      return;
    }
    await _otherSourceSettingsService.saveSourceEditMaxLine(parsed);
    await _reloadSourceSettingsSummaries();
  }

  Future<void> _openCheckSourceSettings() async {
    final updated = await Navigator.of(context).push<bool>(
      CupertinoPageRoute<bool>(
        builder: (context) => const CheckSourceSettingsView(),
      ),
    );
    if (updated != true || !mounted) return;
    await _reloadSourceSettingsSummaries();
  }

  Future<void> _pickDefaultHomePage() async {
    final pickerItems = <OptionPickerItem<MainDefaultHomePage>>[
      const OptionPickerItem<MainDefaultHomePage>(
        value: MainDefaultHomePage.bookshelf,
        label: '书架',
      ),
      const OptionPickerItem<MainDefaultHomePage>(
        value: MainDefaultHomePage.explore,
        label: '发现',
      ),
      if (!_excludeRss)
        const OptionPickerItem<MainDefaultHomePage>(
          value: MainDefaultHomePage.rss,
          label: '订阅',
        ),
      const OptionPickerItem<MainDefaultHomePage>(
        value: MainDefaultHomePage.my,
        label: '我的',
      ),
    ];
    final selected = await showOptionPickerSheet<MainDefaultHomePage>(
      context: context,
      title: '默认主页',
      currentValue: _effectiveDefaultHomePageForUi(
        _appSettings.defaultHomePage,
      ),
      accentColor: AppDesignTokens.brandPrimary,
      items: pickerItems,
    );
    if (selected == null) return;
    await _settingsService.saveDefaultHomePage(selected);
  }

  MainDefaultHomePage _effectiveDefaultHomePageForUi(
    MainDefaultHomePage page,
  ) {
    // 迁移排除策略：RSS 入口隐藏时，默认主页不应继续显示为“订阅”。
    if (_excludeRss && page == MainDefaultHomePage.rss) {
      return MainDefaultHomePage.bookshelf;
    }
    return page;
  }

  Future<void> _pickUpdateToVariant() async {
    final current = _appSettings.updateToVariant;
    final variants = <String>[
      AppSettings.defaultUpdateToVariant,
      AppSettings.officialUpdateToVariant,
      AppSettings.betaReleaseUpdateToVariant,
      AppSettings.betaReleaseAUpdateToVariant,
    ];
    final selected = await showOptionPickerSheet<String>(
      context: context,
      title: '检查更新查找版本',
      currentValue: current,
      accentColor: AppDesignTokens.brandPrimary,
      items: variants
          .map(
            (variant) => OptionPickerItem<String>(
              value: variant,
              label: AppSettings.updateToVariantLabel(variant),
            ),
          )
          .toList(growable: false),
    );
    if (selected == null || selected == current) return;
    await _settingsService.saveUpdateToVariant(selected);
  }

  Future<void> _editPreDownloadNum() async {
    await _editBoundedIntSetting(
      title: '预下载',
      currentValue: _appSettings.preDownloadNum,
      min: 0,
      max: 9999,
      placeholder: '请输入 0 到 9999 之间的整数',
      save: _settingsService.savePreDownloadNum,
    );
  }

  Future<void> _editThreadCount() async {
    await _editBoundedIntSetting(
      title: '线程数量',
      currentValue: _appSettings.threadCount,
      min: 1,
      max: 999,
      placeholder: '请输入 1 到 999 之间的整数',
      save: _settingsService.saveThreadCount,
    );
  }

  Future<void> _editBitmapCacheSize() async {
    await _editBoundedIntSetting(
      title: '图片绘制缓存',
      currentValue: _appSettings.bitmapCacheSize,
      min: 1,
      max: 2047,
      placeholder: '请输入 1 到 2047 之间的整数（MB）',
      save: _settingsService.saveBitmapCacheSize,
    );
  }

  Future<void> _editImageRetainNum() async {
    await _editBoundedIntSetting(
      title: '漫画保留数量',
      currentValue: _appSettings.imageRetainNum,
      min: 0,
      max: 999,
      placeholder: '请输入 0 到 999 之间的整数',
      save: _settingsService.saveImageRetainNum,
    );
  }

  Future<void> _editBoundedIntSetting({
    required String title,
    required int currentValue,
    required int min,
    required int max,
    required String placeholder,
    required Future<void> Function(int value) save,
  }) async {
    final controller = TextEditingController(text: currentValue.toString());
    final value = await showCupertinoBottomDialog<String>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            keyboardType: TextInputType.number,
            placeholder: placeholder,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;

    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed < min || parsed > max) {
      _showMessage('$title 需要在 $min 到 $max 之间');
      return;
    }
    await save(parsed);
  }

  Widget _buildBooleanTile({
    required String title,
    String? additionalInfo,
    required bool value,
    required Future<void> Function(bool enabled) save,
  }) {
    return AppListTile(
      title: Text(title),
      additionalInfo: additionalInfo == null ? null : Text(additionalInfo),
      trailing: CupertinoSwitch(
        value: value,
        onChanged: save,
      ),
      onTap: () => save(!value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '其它设置',
      child: AppListView(
        children: [
          AppListSection(
            header: const Text('基本设置'),
            hasLeading: false,
            children: [
              AppListTile(
                title: const Text('自动刷新'),
                additionalInfo: const Text('打开软件时自动更新书籍'),
                trailing: CupertinoSwitch(
                  value: _appSettings.autoRefresh,
                  onChanged: _settingsService.saveAutoRefresh,
                ),
                onTap: () => _settingsService.saveAutoRefresh(
                  !_appSettings.autoRefresh,
                ),
              ),
              AppListTile(
                title: const Text('自动跳转最近阅读'),
                additionalInfo: const Text('默认打开书架'),
                trailing: CupertinoSwitch(
                  value: _appSettings.defaultToRead,
                  onChanged: _settingsService.saveDefaultToRead,
                ),
                onTap: () => _settingsService.saveDefaultToRead(
                  !_appSettings.defaultToRead,
                ),
              ),
              AppListTile(
                title: const Text('显示发现'),
                trailing: CupertinoSwitch(
                  value: _appSettings.showDiscovery,
                  onChanged: _settingsService.saveShowDiscovery,
                ),
                onTap: () => _settingsService.saveShowDiscovery(
                  !_appSettings.showDiscovery,
                ),
              ),
              if (!_excludeRss)
                AppListTile(
                  title: const Text('显示订阅'),
                  trailing: CupertinoSwitch(
                    value: _appSettings.showRss,
                    onChanged: _settingsService.saveShowRss,
                  ),
                  onTap: () => _settingsService.saveShowRss(
                    !_appSettings.showRss,
                  ),
                ),
              AppListTile(
                title: const Text('默认主页'),
                additionalInfo: Text(
                  _defaultHomePageLabel(_appSettings.defaultHomePage),
                ),
                onTap: _pickDefaultHomePage,
              ),
            ],
          ),
          AppListSection(
            header: const Text('源设置'),
            hasLeading: false,
            children: [
              AppListTile(
                title: const Text('用户代理'),
                additionalInfo: Text(_brief(_userAgentSummary)),
                onTap: _editUserAgent,
              ),
              AppListTile(
                title: const Text('书籍保存位置'),
                additionalInfo: Text(
                  _brief(
                    _defaultBookTreeUriSummary,
                    fallback: '从其它应用打开的书籍保存位置',
                  ),
                ),
                onTap: _selectDefaultBookTreeUri,
              ),
              AppListTile(
                title: const Text('源编辑框最大行数'),
                additionalInfo: Text(_brief(_sourceEditMaxLineSummary)),
                onTap: _editSourceEditMaxLine,
              ),
              AppListTile(
                title: const Text('校验设置'),
                additionalInfo: Text(_brief(_checkSourceSummary)),
                onTap: _openCheckSourceSettings,
              ),
              AppListTile(
                title: const Text('直链上传规则'),
                additionalInfo: Text(_brief(_directLinkUploadSummary)),
                onTap: _openDirectLinkUploadConfig,
              ),
            ],
          ),
          AppListSection(
            header: const Text('缓存与净化'),
            hasLeading: false,
            children: [
              AppListTile(
                title: const Text('预下载'),
                additionalInfo: Text('预先下载 ${_appSettings.preDownloadNum} 章正文'),
                onTap: _editPreDownloadNum,
              ),
              AppListTile(
                title: const Text('线程数量'),
                additionalInfo: Text('当前线程数 ${_appSettings.threadCount}'),
                onTap: _editThreadCount,
              ),
              AppListTile(
                title: const Text('图片绘制缓存'),
                additionalInfo:
                    Text('当前最大缓存 ${_appSettings.bitmapCacheSize} MB'),
                onTap: _editBitmapCacheSize,
              ),
              if (!_excludeManga)
                AppListTile(
                  title: const Text('漫画保留数量'),
                  additionalInfo:
                      Text('保留已读章节数量 ${_appSettings.imageRetainNum}'),
                  onTap: _editImageRetainNum,
                ),
              AppListTile(
                title: const Text('默认启用替换净化'),
                additionalInfo: const Text('新加入书架的书是否启用替换净化'),
                trailing: CupertinoSwitch(
                  value: _appSettings.replaceEnableDefault,
                  onChanged: _settingsService.saveReplaceEnableDefault,
                ),
                onTap: () => _settingsService.saveReplaceEnableDefault(
                  !_appSettings.replaceEnableDefault,
                ),
              ),
              AppListTile(
                title: const Text('下载与缓存'),
                additionalInfo: const Text('缓存清理、WebView 数据、数据库维护'),
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (context) => const StorageSettingsView(),
                  ),
                ),
              ),
            ],
          ),
          AppListSection(
            header: const Text('调试与系统'),
            hasLeading: false,
            children: [
              AppListTile(
                title: const Text('文字操作显示搜索'),
                additionalInfo: const Text('长按文字在操作菜单中显示阅读·搜索'),
                trailing: CupertinoSwitch(
                  value: _appSettings.processText,
                  onChanged: _settingsService.saveProcessText,
                ),
                onTap: () => _settingsService.saveProcessText(
                  !_appSettings.processText,
                ),
              ),
              AppListTile(
                title: const Text('记录日志'),
                additionalInfo: const Text('记录调试日志'),
                trailing: CupertinoSwitch(
                  value: _appSettings.recordLog,
                  onChanged: _settingsService.saveRecordLog,
                ),
                onTap: () =>
                    _settingsService.saveRecordLog(!_appSettings.recordLog),
              ),
              AppListTile(
                title: const Text('记录堆转储'),
                additionalInfo: const Text('当应用发生 OOM 崩溃时保存堆转储'),
                trailing: CupertinoSwitch(
                  value: _appSettings.recordHeapDump,
                  onChanged: _settingsService.saveRecordHeapDump,
                ),
                onTap: () => _settingsService.saveRecordHeapDump(
                  !_appSettings.recordHeapDump,
                ),
              ),
            ],
          ),
          if (!kIsWeb)
            AppListSection(
              header: const Text('非 Web 其它设置'),
              hasLeading: false,
              children: [
                _buildBooleanTile(
                  title: 'Cronet',
                  additionalInfo: '使用 Cronet 网络组件',
                  value: _appSettings.cronet,
                  save: _settingsService.saveCronet,
                ),
                _buildBooleanTile(
                  title: '抗锯齿',
                  additionalInfo: '绘制图片时抗锯齿',
                  value: _appSettings.antiAlias,
                  save: _settingsService.saveAntiAlias,
                ),
                if (!_excludeTts)
                  _buildBooleanTile(
                    title: '全程响应耳机按键',
                    additionalInfo: '即使退出软件也响应耳机按键',
                    value: _appSettings.mediaButtonOnExit,
                    save: _settingsService.saveMediaButtonOnExit,
                  ),
                if (!_excludeTts)
                  _buildBooleanTile(
                    title: '耳机按键启动朗读',
                    additionalInfo: '通过耳机按键来启动朗读',
                    value: _appSettings.readAloudByMediaButton,
                    save: _settingsService.saveReadAloudByMediaButton,
                  ),
                if (!_excludeTts)
                  _buildBooleanTile(
                    title: '忽略音频焦点',
                    additionalInfo: '允许与其他应用同时播放音频',
                    value: _appSettings.ignoreAudioFocus,
                    save: _settingsService.saveIgnoreAudioFocus,
                  ),
                _buildBooleanTile(
                  title: '自动清除过期搜索数据',
                  additionalInfo: '超过一天的搜索数据',
                  value: _appSettings.autoClearExpired,
                  save: _settingsService.saveAutoClearExpired,
                ),
                _buildBooleanTile(
                  title: '返回时提示放入书架',
                  additionalInfo: '阅读未放入书架的书籍在返回时提示放入书架',
                  value: _appSettings.showAddToShelfAlert,
                  save: _settingsService.saveShowAddToShelfAlert,
                ),
                AppListTile(
                  title: const Text('检查更新查找版本'),
                  additionalInfo: Text(
                    AppSettings.updateToVariantLabel(
                      _appSettings.updateToVariant,
                    ),
                  ),
                  onTap: _pickUpdateToVariant,
                ),
                if (!_excludeManga)
                  _buildBooleanTile(
                    title: '漫画浏览',
                    value: _appSettings.showMangaUi,
                    save: _settingsService.saveShowMangaUi,
                  ),
              ],
            ),
          if (!_excludeWebService)
            AppListSection(
              header: const Text('Web 服务（未启用）'),
              hasLeading: false,
              children: [
                AppListTile(
                  title: const Text('Web 端口'),
                  additionalInfo: Text('未启用（当前: ${_appSettings.webPort}）'),
                ),
                AppListTile(
                  title: const Text('WebService 唤醒锁'),
                  additionalInfo: Text(
                    '未启用（当前: ${_appSettings.webServiceWakeLock ? '开' : '关'}）',
                  ),
                ),
              ],
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _defaultHomePageLabel(MainDefaultHomePage page) {
    switch (_effectiveDefaultHomePageForUi(page)) {
      case MainDefaultHomePage.bookshelf:
        return '书架';
      case MainDefaultHomePage.explore:
        return '发现';
      case MainDefaultHomePage.rss:
        return '订阅';
      case MainDefaultHomePage.my:
        return '我的';
    }
  }

  String _brief(String value, {String fallback = '未设置'}) {
    final normalized = value.trim();
    if (normalized.isEmpty) return fallback;
    final singleLine = normalized.replaceAll('\n', ' ').replaceAll('\r', ' ');
    if (singleLine.length <= 24) return singleLine;
    return '${singleLine.substring(0, 24)}…';
  }

  void _showMessage(String message) {
    showCupertinoBottomDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }
}
