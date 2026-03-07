import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';

import '../../../app/widgets/cupertino_bottom_dialog.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/widgets/app_action_list_sheet.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/services/cookie_store.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/services/keyboard_assist_store.dart';
import '../../../core/services/qr_scan_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/source_variable_store.dart';
import '../../search/models/search_scope.dart';
import '../../search/models/search_scope_group_helper.dart';
import '../../search/views/search_view.dart';
import '../constants/source_help_texts.dart';
import '../models/book_source.dart';
import '../services/source_cookie_scope_resolver.dart';
import '../services/source_edit_rule_help_store.dart';
import '../services/source_explore_kinds_service.dart';
import '../services/source_import_export_service.dart';
import '../services/source_legacy_save_service.dart';
import '../services/source_login_url_resolver.dart';
import 'keyboard_assists_config_sheet.dart';
import 'source_debug_legacy_view.dart';
import 'source_edit_legacy_form_controllers.dart';
import 'source_edit_legacy_form_controller_dispose.dart';
import 'source_edit_legacy_form_source_codec.dart';
import 'source_edit_legacy_tab_builder.dart';
import 'source_edit_legacy_source_builder.dart';
import 'source_edit_legacy_share_helper.dart';
import 'source_edit_legacy_transfer_helper.dart';
import 'source_edit_legacy_url_option_dialog.dart';
import 'source_edit_legacy_variable_sheet.dart';
import 'source_edit_legacy_sections.dart';
import 'source_login_form_view.dart';
import 'source_login_webview_view.dart';

class SourceEditLegacyView extends StatefulWidget {
  final String? originalUrl;
  final String initialRawJson;
  final int? initialTab;

  const SourceEditLegacyView({
    super.key,
    required this.initialRawJson,
    this.originalUrl,
    this.initialTab,
  });

  static SourceEditLegacyView fromSource(
    BookSource source, {
    String? rawJson,
    int? initialTab,
  }) {
    final normalizedRaw = (rawJson != null && rawJson.trim().isNotEmpty)
        ? rawJson
        : SourceEditLegacyTransferHelper.encodeSourceJson(source);
    return SourceEditLegacyView(
      originalUrl: source.bookSourceUrl,
      initialRawJson: normalizedRaw,
      initialTab: initialTab,
    );
  }

  @override
  State<SourceEditLegacyView> createState() => _SourceEditLegacyViewState();
}

enum _SourceEditMoreAction {
  login,
  search,
  clearCookie,
  toggleAutoComplete,
  copySource,
  pasteSource,
  setSourceVariable,
  importQr,
  shareQr,
  shareText,
  help,
}

class _SourceEditLegacyViewState extends State<SourceEditLegacyView> {
  static const String _insertActionAssistPrefix = 'assist:';
  static const String _insertActionConfig = 'insert_action_config';
  static const String _insertActionUrlOption = 'insert_action_url_option';
  static const String _insertActionRuleHelp = 'insert_action_rule_help';
  static const String _insertActionJsHelp = 'insert_action_js_help';
  static const String _insertActionRegexHelp = 'insert_action_regex_help';
  static const String _insertActionGroupOrFile = 'insert_action_group_or_file';
  late final DatabaseService _db;
  late final SourceRepository _repo;
  late final SourceExploreKindsService _exploreKindsService;
  late final SourceImportExportService _importExportService;
  late final SourceLegacySaveService _saveService;
  final SettingsService _settingsService = SettingsService();
  final KeyboardAssistStore _keyboardAssistStore = KeyboardAssistStore();
  final SourceEditRuleHelpStore _ruleHelpStore = SourceEditRuleHelpStore();

  int _tab = 0;
  bool _autoComplete = false;

  String? _currentOriginalUrl;
  BookSource? _savedSource;
  String _savedSnapshot = '';

  bool _enabled = true;
  bool _enabledExplore = true;
  bool _enabledCookieJar = true;
  int _bookSourceType = 0;
  String? _activeFieldKey;
  TextEditingController? _activeFieldController;

  late final SourceEditLegacyFormControllers _form;

  @override
  void initState() {
    super.initState();
    _db = DatabaseService();
    _repo = SourceRepository(_db);
    _exploreKindsService = SourceExploreKindsService(databaseService: _db);
    _importExportService = SourceImportExportService();
    _saveService = SourceLegacySaveService(
      upsertSourceRawJson: ({
        String? originalUrl,
        required String rawJson,
      }) {
        return _repo.upsertSourceRawJson(
          originalUrl: originalUrl,
          rawJson: rawJson,
        );
      },
      clearExploreKindsCache: _exploreKindsService.clearExploreKindsCache,
      clearJsLibScope: (_) {
        // Flutter 侧当前无跨源共享 JS Scope，保留回调位以维持行为完整性。
      },
      removeSourceVariable: (sourceUrl) {
        return SourceVariableStore.removeVariable(sourceUrl);
      },
    );

    _tab = (widget.initialTab ?? 0).clamp(0, 5);
    _currentOriginalUrl = (widget.originalUrl ?? '').trim();
    if (_currentOriginalUrl?.isEmpty == true) {
      _currentOriginalUrl = null;
    }

    final source = SourceEditLegacyFormSourceCodec.parseInitialSource(
      widget.initialRawJson,
    );
    _loadSourceMeta(source);
    _form = SourceEditLegacyFormControllers(source);
    _savedSource = source;
    _savedSnapshot = SourceEditLegacyFormSourceCodec.snapshotFor(source);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowRuleHelp();
    });
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final canExit = await _confirmExitIfDirty();
        if (!canExit || !context.mounted) return;
        Navigator.of(context).pop();
      },
      child: AppCupertinoPageScaffold(
        title: '书源编辑',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppNavBarButton(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              onPressed: _save,
              child: const Text('保存'),
            ),
            AppNavBarButton(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              onPressed: _saveAndOpenDebug,
              child: const Text('调试'),
            ),
            AppNavBarButton(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              onPressed: _showMore,
              child: const Icon(CupertinoIcons.ellipsis_circle),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildTopSettings(),
            _buildTabSwitcher(),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: SourceEditLegacyTabBuilder.buildTabs(
                  form: _form,
                  activeFieldController: _activeFieldController,
                  onFieldActivated: _markActiveField,
                  onShowInsertActions: _showInsertActions,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSettings() {
    return SourceEditLegacyTopSettingsSection(
      bookSourceType: _bookSourceType,
      typeLabelBuilder: SourceEditLegacyFormSourceCodec.typeLabel,
      onPickBookSourceType: _pickBookSourceType,
      enabled: _enabled,
      onEnabledChanged: (value) => setState(() => _enabled = value),
      enabledExplore: _enabledExplore,
      onEnabledExploreChanged: (value) =>
          setState(() => _enabledExplore = value),
      enabledCookieJar: _enabledCookieJar,
      onEnabledCookieJarChanged: (value) =>
          setState(() => _enabledCookieJar = value),
    );
  }

  Widget _buildTabSwitcher() {
    return SourceEditLegacyTabSwitcher(
      tab: _tab,
      onTabChanged: (value) {
        setState(() {
          _tab = value;
          _activeFieldKey = null;
          _activeFieldController = null;
        });
      },
    );
  }

  void _markActiveField(String key, TextEditingController controller) {
    if (identical(_activeFieldController, controller) &&
        _activeFieldKey == key) {
      return;
    }
    if (!mounted) {
      _activeFieldKey = key;
      _activeFieldController = controller;
      return;
    }
    setState(() {
      _activeFieldKey = key;
      _activeFieldController = controller;
    });
  }

  Future<void> _pickBookSourceType() async {
    final selected = await showAppActionListSheet<int>(
      context: context,
      title: '书源类型',
      showCancel: true,
      items: const [
        AppActionListItem<int>(
          value: 0,
          icon: CupertinoIcons.book,
          label: '默认',
        ),
        AppActionListItem<int>(
          value: 1,
          icon: CupertinoIcons.music_note,
          label: '音频',
        ),
        AppActionListItem<int>(
          value: 2,
          icon: CupertinoIcons.photo,
          label: '图片',
        ),
        AppActionListItem<int>(
          value: 3,
          icon: CupertinoIcons.doc_text,
          label: '文件',
        ),
      ],
    );

    if (selected == null || !mounted) return;
    setState(() => _bookSourceType = selected);
  }

  Future<void> _showMore() async {
    if (!mounted) return;
    final hasLogin = _form.loginUrlCtrl.text.trim().isNotEmpty;
    final selected = await showAppActionListSheet<_SourceEditMoreAction>(
      context: context,
      title: '更多',
      showCancel: true,
      items: <AppActionListItem<_SourceEditMoreAction>>[
        if (hasLogin)
          const AppActionListItem<_SourceEditMoreAction>(
            value: _SourceEditMoreAction.login,
            icon: CupertinoIcons.person_crop_circle_badge_checkmark,
            label: '登录',
          ),
        const AppActionListItem<_SourceEditMoreAction>(
          value: _SourceEditMoreAction.search,
          icon: CupertinoIcons.search,
          label: '搜索',
        ),
        const AppActionListItem<_SourceEditMoreAction>(
          value: _SourceEditMoreAction.clearCookie,
          icon: CupertinoIcons.delete,
          label: '清除 Cookie',
        ),
        AppActionListItem<_SourceEditMoreAction>(
          value: _SourceEditMoreAction.toggleAutoComplete,
          icon: _autoComplete
              ? CupertinoIcons.check_mark_circled_solid
              : CupertinoIcons.check_mark_circled,
          label: '${_autoComplete ? '✓ ' : ''}自动补全',
        ),
        const AppActionListItem<_SourceEditMoreAction>(
          value: _SourceEditMoreAction.copySource,
          icon: CupertinoIcons.doc_on_doc,
          label: '复制书源',
        ),
        const AppActionListItem<_SourceEditMoreAction>(
          value: _SourceEditMoreAction.pasteSource,
          icon: CupertinoIcons.doc_on_clipboard,
          label: '粘贴源',
        ),
        const AppActionListItem<_SourceEditMoreAction>(
          value: _SourceEditMoreAction.setSourceVariable,
          icon: CupertinoIcons.slider_horizontal_3,
          label: '设置源变量',
        ),
        const AppActionListItem<_SourceEditMoreAction>(
          value: _SourceEditMoreAction.importQr,
          icon: CupertinoIcons.qrcode_viewfinder,
          label: '二维码导入',
        ),
        const AppActionListItem<_SourceEditMoreAction>(
          value: _SourceEditMoreAction.shareQr,
          icon: CupertinoIcons.qrcode,
          label: '二维码分享',
        ),
        const AppActionListItem<_SourceEditMoreAction>(
          value: _SourceEditMoreAction.shareText,
          icon: CupertinoIcons.square_arrow_up,
          label: '字符串分享',
        ),
        const AppActionListItem<_SourceEditMoreAction>(
          value: _SourceEditMoreAction.help,
          icon: CupertinoIcons.question_circle,
          label: '帮助',
        ),
      ],
    );
    if (selected == null) return;
    switch (selected) {
      case _SourceEditMoreAction.login:
        await _saveAndOpenLogin();
        return;
      case _SourceEditMoreAction.search:
        await _saveAndSearch();
        return;
      case _SourceEditMoreAction.clearCookie:
        await _clearCookie();
        return;
      case _SourceEditMoreAction.toggleAutoComplete:
        setState(() => _autoComplete = !_autoComplete);
        return;
      case _SourceEditMoreAction.copySource:
        await _copySourceJson();
        return;
      case _SourceEditMoreAction.pasteSource:
        await _pasteSourceJson();
        return;
      case _SourceEditMoreAction.setSourceVariable:
        await _setSourceVariable();
        return;
      case _SourceEditMoreAction.importQr:
        await _importFromQrCode();
        return;
      case _SourceEditMoreAction.shareQr:
        await _shareSourceJsonQr();
        return;
      case _SourceEditMoreAction.shareText:
        await _shareSourceJsonText();
        return;
      case _SourceEditMoreAction.help:
        _showMessage(SourceHelpTexts.ruleHelp);
        return;
    }
  }

  Future<void> _maybeShowRuleHelp() async {
    final shown = await _ruleHelpStore.isShown();
    if (shown) return;
    await _ruleHelpStore.markShown();
    if (!mounted) return;
    _showMessage(SourceHelpTexts.ruleHelp);
  }

  Future<void> _showInsertActions() async {
    final keyboardAssists = await _keyboardAssistStore.loadAll(type: 0);
    if (!mounted) return;
    final fieldKey = _activeFieldKey;
    final onGroupField = fieldKey == 'bookSourceGroup';
    final selected = await showAppActionListSheet<String>(
      context: context,
      title: '编辑工具',
      showCancel: true,
      items: <AppActionListItem<String>>[
        const AppActionListItem<String>(
          value: _insertActionConfig,
          icon: CupertinoIcons.settings,
          label: '辅助按键配置',
        ),
        for (var i = 0; i < keyboardAssists.length; i++)
          AppActionListItem<String>(
            value: '$_insertActionAssistPrefix$i',
            icon: CupertinoIcons.keyboard,
            label: keyboardAssists[i].key,
          ),
        const AppActionListItem<String>(
          value: _insertActionUrlOption,
          icon: CupertinoIcons.link,
          label: '插入URL参数',
        ),
        const AppActionListItem<String>(
          value: _insertActionRuleHelp,
          icon: CupertinoIcons.book,
          label: '书源教程',
        ),
        const AppActionListItem<String>(
          value: _insertActionJsHelp,
          icon: CupertinoIcons.chevron_left_slash_chevron_right,
          label: 'js教程',
        ),
        const AppActionListItem<String>(
          value: _insertActionRegexHelp,
          icon: CupertinoIcons.textformat_abc,
          label: '正则教程',
        ),
        AppActionListItem<String>(
          value: _insertActionGroupOrFile,
          icon:
              onGroupField ? CupertinoIcons.collections : CupertinoIcons.folder,
          label: onGroupField ? '插入分组' : '选择文件',
        ),
      ],
    );
    if (selected == null) return;
    if (selected.startsWith(_insertActionAssistPrefix)) {
      final index = int.tryParse(
        selected.substring(_insertActionAssistPrefix.length),
      );
      if (index == null || index < 0 || index >= keyboardAssists.length) return;
      _insertTextToActiveField(keyboardAssists[index].value);
      return;
    }
    switch (selected) {
      case _insertActionConfig:
        await _showKeyboardAssistsConfig();
        return;
      case _insertActionUrlOption:
        await _insertUrlOption();
        return;
      case _insertActionRuleHelp:
        _showMessage(SourceHelpTexts.ruleHelp);
        return;
      case _insertActionJsHelp:
        _showMessage(SourceHelpTexts.jsHelp);
        return;
      case _insertActionRegexHelp:
        _showMessage(SourceHelpTexts.regexHelp);
        return;
      case _insertActionGroupOrFile:
        if (onGroupField) {
          await _insertGroup();
        } else {
          await _insertFilePath();
        }
        return;
      default:
        return;
    }
  }

  Future<void> _showKeyboardAssistsConfig() async {
    if (!mounted) return;
    await showKeyboardAssistsConfigSheet(
      context,
      store: _keyboardAssistStore,
    );
  }

  Future<void> _insertUrlOption() async {
    if (!_ensureActiveFieldSelected()) return;
    final text = await showSourceEditLegacyUrlOptionDialog(context);

    if (text == null || text.trim().isEmpty) return;
    _insertTextToActiveField(text.trim());
  }

  Future<void> _insertGroup() async {
    if (!_ensureActiveFieldSelected()) return;
    final groups = _collectAllGroups();
    if (groups.isEmpty) {
      _showMessage('暂无可选分组');
      return;
    }

    final selected = await showAppActionListSheet<String>(
      context: context,
      title: '选择分组',
      showCancel: true,
      items: [
        for (final group in groups)
          AppActionListItem<String>(
            value: group,
            icon: CupertinoIcons.collections,
            label: group,
          ),
      ],
    );
    if (selected == null || selected.trim().isEmpty) return;
    _insertTextToActiveField(selected);
  }

  Future<void> _insertFilePath() async {
    if (!_ensureActiveFieldSelected()) return;
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final path = (file.path ?? file.name).trim();
    if (path.isEmpty) {
      _showMessage('未获取到文件路径');
      return;
    }
    _insertTextToActiveField(path);
  }

  List<String> _collectAllGroups() {
    final rawGroups = _repo
        .getAllSources()
        .map((source) => source.bookSourceGroup?.trim() ?? '')
        .where((raw) => raw.isNotEmpty);
    return SearchScopeGroupHelper.dealGroups(rawGroups);
  }

  bool _ensureActiveFieldSelected() {
    if (_activeFieldController != null) return true;
    _showMessage('请先选中输入框');
    return false;
  }

  void _insertTextToActiveField(String text) {
    final controller = _activeFieldController;
    if (controller == null) {
      _showMessage('请先选中输入框');
      return;
    }
    final value = controller.value;
    final start = value.selection.start;
    final end = value.selection.end;
    final hasSelection = start >= 0 && end >= 0;
    final replaceStart =
        hasSelection ? (start < end ? start : end) : value.text.length;
    final replaceEnd =
        hasSelection ? (start < end ? end : start) : value.text.length;
    final nextText = value.text.replaceRange(replaceStart, replaceEnd, text);
    controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: replaceStart + text.length),
    );
  }

  Future<void> _copySourceJson() async {
    final source = _buildSourceFromFields();
    await SourceEditLegacyTransferHelper.copySourceJson(source);
    if (!mounted) return;
    _showMessage('已复制书源 JSON');
  }

  Future<void> _shareSourceJsonText() async {
    final source = _buildSourceFromFields();
    await SourceEditLegacyTransferHelper.shareSourceJsonText(source);
  }

  Future<void> _shareSourceJsonQr() async {
    final source = _buildSourceFromFields();
    final text = SourceEditLegacyTransferHelper.encodeSourceJson(source);
    final qrFile = await SourceEditLegacyShareHelper.buildShareQrPngFile(text);
    if (qrFile == null) {
      if (!mounted) return;
      _showMessage('文字太多，生成二维码失败');
      return;
    }
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[
            XFile(qrFile.path, mimeType: 'image/png'),
          ],
          subject: '分享书源',
          text: '分享书源',
        ),
      );
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'source.edit_legacy.share_qr',
        message: '分享书源二维码失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'sourceUrl': source.bookSourceUrl,
          'sourceName': source.bookSourceName,
        },
      );
      if (!mounted) return;
      _showMessage(SourceEditLegacyShareHelper.resolveShareErrorMessage(error));
    }
  }

  Future<void> _pasteSourceJson() async {
    final text = await SourceEditLegacyTransferHelper.readClipboardText();
    final result =
        await SourceEditLegacyTransferHelper.importFirstSourceFromText(
      text: text ?? '',
      importExportService: _importExportService,
      errorMessageResolver:
          SourceEditLegacyTransferHelper.resolvePasteSourceError,
    );
    if (!result.isSuccess) {
      if (result.inputLength != null) {
        ExceptionLogService().record(
          node: 'source.edit_legacy.paste_json',
          message: '粘贴导入书源失败',
          error: result.rawErrorMessage,
          context: <String, dynamic>{
            'inputLength': result.inputLength,
          },
        );
      }
      _showMessage(result.userMessage ?? '格式不对');
      return;
    }

    _applyLoadedSource(result.source!);
  }

  Future<void> _importFromQrCode() async {
    final text = await QrScanService.scanText(context, title: '扫描二维码');
    final value = text?.trim();
    if (value == null || value.isEmpty) {
      return;
    }
    final result =
        await SourceEditLegacyTransferHelper.importFirstSourceFromText(
      text: value,
      importExportService: _importExportService,
      errorMessageResolver: SourceEditLegacyTransferHelper.resolveQrImportError,
    );
    if (!result.isSuccess) {
      ExceptionLogService().record(
        node: 'source.edit_legacy.import_qr',
        message: '扫码导入书源失败',
        error: result.rawErrorMessage,
        context: <String, dynamic>{
          'inputLength': result.inputLength,
        },
      );
      _showMessage(result.userMessage ?? 'Error');
      return;
    }

    if (!mounted) return;
    _applyLoadedSource(result.source!);
  }

  Future<void> _saveAndOpenDebug() async {
    final saved = await _saveInternal(showSuccessMessage: false);
    if (saved == null || !mounted) return;

    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SourceDebugLegacyView(
          source: saved,
        ),
      ),
    );
  }

  Future<void> _saveAndOpenLogin() async {
    final saved = await _saveInternal(showSuccessMessage: false);
    if (saved == null || !mounted) return;

    final hasLoginUi = (saved.loginUi ?? '').trim().isNotEmpty;
    if (hasLoginUi) {
      await Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (_) => SourceLoginFormView(source: saved),
        ),
      );
      return;
    }

    final resolvedUrl = SourceLoginUrlResolver.resolve(
      baseUrl: saved.bookSourceUrl,
      loginUrl: saved.loginUrl ?? '',
    );
    if (resolvedUrl.isEmpty) {
      _showMessage('当前书源未配置登录地址');
      return;
    }
    final uri = Uri.tryParse(resolvedUrl);
    final scheme = uri?.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      _showMessage('登录地址不是有效网页地址');
      return;
    }

    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SourceLoginWebViewView(
          source: saved,
          initialUrl: resolvedUrl,
        ),
      ),
    );
  }

  Future<void> _saveAndSearch() async {
    final saved = await _saveInternal(showSuccessMessage: false);
    if (saved == null || !mounted) return;

    final nextScope = SearchScope.fromSource(saved);
    final currentSettings = _settingsService.appSettings;
    if (currentSettings.searchScope != nextScope) {
      await _settingsService.saveAppSettings(
        currentSettings.copyWith(searchScope: nextScope),
      );
    }
    if (!mounted) return;

    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => const SearchView(),
      ),
    );
  }

  Future<void> _setSourceVariable() async {
    final saved = await _saveInternal(showSuccessMessage: false);
    if (saved == null) return;

    final sourceKey = saved.bookSourceUrl;
    final note = SourceEditLegacyFormSourceCodec.displayVariableComment(saved);
    final current = await SourceVariableStore.getVariable(sourceKey) ?? '';
    if (!mounted) return;

    final result = await showSourceEditLegacyVariableSheet(
      context,
      note: note,
      initialValue: current,
    );
    if (result == null) return;

    await SourceVariableStore.putVariable(sourceKey, result);
  }

  Future<void> _clearCookie() async {
    final url = _form.bookSourceUrlCtrl.text.trim();
    final candidates = SourceCookieScopeResolver.resolveDomainCandidates(url);
    for (final uri in candidates) {
      try {
        await CookieStore.jar.delete(uri, true);
      } catch (_) {
        // 对齐 legado：clearCookie 分支静默执行，不追加成功/失败提示。
      }
    }
  }

  Future<void> _save() async {
    final saved = await _saveInternal(showSuccessMessage: false);
    if (saved == null || !mounted) return;
    Navigator.of(context).pop(saved.bookSourceUrl);
  }

  Future<BookSource?> _saveInternal({bool showSuccessMessage = true}) async {
    final source = _buildSourceFromFields();
    try {
      final saved = await _saveService.save(
        source: source,
        originalSource: _savedSource,
      );
      _savedSource = saved;
      _currentOriginalUrl = saved.bookSourceUrl;
      _savedSnapshot = SourceEditLegacyFormSourceCodec.snapshotFor(saved);
      if (showSuccessMessage && mounted) {
        _showMessage('保存成功');
      }
      return saved;
    } catch (e, stackTrace) {
      ExceptionLogService().record(
        node: 'source.edit_legacy.save',
        message: '书源保存失败',
        error: e,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'sourceUrl': source.bookSourceUrl,
          'sourceName': source.bookSourceName,
        },
      );
      if (mounted) {
        _showMessage(_legacyErrorMessage(e));
      }
      return null;
    }
  }

  String _legacyErrorMessage(Object error) {
    if (error is FormatException) {
      final message = error.message.toString().trim();
      if (message.isNotEmpty) return message;
    }
    final raw = error.toString().trim();
    const prefix = 'FormatException:';
    if (raw.startsWith(prefix)) {
      final message = raw.substring(prefix.length).trim();
      if (message.isNotEmpty) return message;
    }
    if (raw.isNotEmpty) return raw;
    return 'Error';
  }

  Future<bool> _confirmExitIfDirty() async {
    final dirty =
        SourceEditLegacyFormSourceCodec.snapshotFor(_buildSourceFromFields()) !=
            _savedSnapshot;
    if (!dirty) return true;

    final result = await showCupertinoBottomDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('退出'),
        content: const Text('\n存在未保存修改，确认退出吗？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('继续编辑'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('放弃修改'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  BookSource _buildSourceFromFields() {
    final base = _savedSource ??
        const BookSource(
          bookSourceUrl: '',
          bookSourceName: '',
        );
    return SourceEditLegacySourceBuilder.build(
      SourceEditLegacySourceBuildInput(
        base: base,
        form: _form,
        autoComplete: _autoComplete,
        enabled: _enabled,
        enabledExplore: _enabledExplore,
        enabledCookieJar: _enabledCookieJar,
        bookSourceType: _bookSourceType,
      ),
    );
  }

  void _loadSourceMeta(BookSource source) {
    _enabled = source.enabled;
    _enabledExplore = source.enabledExplore;
    _enabledCookieJar = source.enabledCookieJar ?? false;
    _bookSourceType = source.bookSourceType;
  }

  void _applyLoadedSource(BookSource source) {
    setState(() {
      _loadSourceMeta(source);
      _form.loadSource(source);
    });
  }

  void _showMessage(String message) {
    showCupertinoBottomDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('\n$message'),
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
