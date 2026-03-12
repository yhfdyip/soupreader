import 'dart:convert';

import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/rss_source_repository.dart';
import '../../../core/utils/legado_json.dart';
import '../models/rss_source.dart';
import 'rss_source_debug_view.dart';
import 'rss_source_edit_form.dart';

class RssSourceEditView extends StatefulWidget {
  const RssSourceEditView({
    super.key,
    this.sourceUrl,
  });

  final String? sourceUrl;

  @override
  State<RssSourceEditView> createState() => _RssSourceEditViewState();
}

class _RssSourceEditViewState extends State<RssSourceEditView> {
  late final RssSourceRepository _repo;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _groupController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _loginUrlController = TextEditingController();
  final TextEditingController _loginUiController = TextEditingController();
  final TextEditingController _loginCheckJsController = TextEditingController();
  final TextEditingController _coverDecodeJsController = TextEditingController();
  final TextEditingController _sortUrlController = TextEditingController();
  final TextEditingController _customOrderController = TextEditingController();
  final TextEditingController _headerController = TextEditingController();
  final TextEditingController _variableCommentController = TextEditingController();
  final TextEditingController _concurrentRateController = TextEditingController();
  final TextEditingController _jsLibController = TextEditingController();
  // 列表规则
  final TextEditingController _ruleArticlesController = TextEditingController();
  final TextEditingController _ruleNextPageController = TextEditingController();
  final TextEditingController _ruleTitleController = TextEditingController();
  final TextEditingController _rulePubDateController = TextEditingController();
  final TextEditingController _ruleDescriptionController = TextEditingController();
  final TextEditingController _ruleImageController = TextEditingController();
  final TextEditingController _ruleLinkController = TextEditingController();
  // WebView 规则
  final TextEditingController _ruleContentController = TextEditingController();
  final TextEditingController _injectJsController = TextEditingController();
  final TextEditingController _contentWhitelistController = TextEditingController();
  final TextEditingController _contentBlacklistController = TextEditingController();
  final TextEditingController _shouldOverrideUrlLoadingController = TextEditingController();

  bool _enabled = true;
  bool _singleUrl = false;
  bool _enabledCookieJar = true;
  bool _enableJs = false;
  bool _loadWithBaseUrl = false;
  bool _loading = true;
  bool _saving = false;
  String? _originalUrl;
  Map<String, dynamic> _rawJsonMap = <String, dynamic>{};

  bool get _isEditing => widget.sourceUrl != null;

  @override
  void initState() {
    super.initState();
    _repo = RssSourceRepository(DatabaseService());
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _groupController.dispose();
    _commentController.dispose();
    _loginUrlController.dispose();
    _loginUiController.dispose();
    _loginCheckJsController.dispose();
    _coverDecodeJsController.dispose();
    _sortUrlController.dispose();
    _customOrderController.dispose();
    _headerController.dispose();
    _variableCommentController.dispose();
    _concurrentRateController.dispose();
    _jsLibController.dispose();
    _ruleArticlesController.dispose();
    _ruleNextPageController.dispose();
    _ruleTitleController.dispose();
    _rulePubDateController.dispose();
    _ruleDescriptionController.dispose();
    _ruleImageController.dispose();
    _ruleLinkController.dispose();
    _ruleContentController.dispose();
    _injectJsController.dispose();
    _contentWhitelistController.dispose();
    _contentBlacklistController.dispose();
    _shouldOverrideUrlLoadingController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final editingUrl = widget.sourceUrl?.trim() ?? '';
    if (editingUrl.isEmpty) {
      _customOrderController.text = (_repo.maxOrder + 1).toString();
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      return;
    }

    final source = _repo.getByKey(editingUrl);
    if (source != null) {
      _fillFromSource(source);
      final raw = _repo.getRawJsonByUrl(source.sourceUrl);
      _rawJsonMap = _parseRawJson(raw);
      _rawJsonMap['sourceUrl'] = source.sourceUrl;
      _originalUrl = source.sourceUrl;
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
    });
  }

  Map<String, dynamic> _parseRawJson(String? rawJson) {
    final raw = rawJson?.trim() ?? '';
    if (raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry('$key', value));
      }
    } catch (_) {
      return <String, dynamic>{};
    }
    return <String, dynamic>{};
  }

  void _fillFromSource(RssSource source) {
    _nameController.text = source.sourceName;
    _urlController.text = source.sourceUrl;
    _groupController.text = source.sourceGroup ?? '';
    _commentController.text = source.sourceComment ?? '';
    _loginUrlController.text = source.loginUrl ?? '';
    _loginUiController.text = source.loginUi ?? '';
    _loginCheckJsController.text = source.loginCheckJs ?? '';
    _coverDecodeJsController.text = source.coverDecodeJs ?? '';
    _sortUrlController.text = source.sortUrl ?? '';
    _customOrderController.text = source.customOrder.toString();
    _headerController.text = source.header ?? '';
    _variableCommentController.text = source.variableComment ?? '';
    _concurrentRateController.text = source.concurrentRate ?? '';
    _jsLibController.text = source.jsLib ?? '';
    _ruleArticlesController.text = source.ruleArticles ?? '';
    _ruleNextPageController.text = source.ruleNextPage ?? '';
    _ruleTitleController.text = source.ruleTitle ?? '';
    _rulePubDateController.text = source.rulePubDate ?? '';
    _ruleDescriptionController.text = source.ruleDescription ?? '';
    _ruleImageController.text = source.ruleImage ?? '';
    _ruleLinkController.text = source.ruleLink ?? '';
    _ruleContentController.text = source.ruleContent ?? '';
    _injectJsController.text = source.injectJs ?? '';
    _contentWhitelistController.text = source.contentWhitelist ?? '';
    _contentBlacklistController.text = source.contentBlacklist ?? '';
    _shouldOverrideUrlLoadingController.text =
        source.shouldOverrideUrlLoading ?? '';
    _enabled = source.enabled;
    _singleUrl = source.singleUrl;
    _enabledCookieJar = source.enabledCookieJar ?? true;
    _enableJs = source.enableJs;
    _loadWithBaseUrl = source.loadWithBaseUrl;
  }

  String? _nullableText(TextEditingController controller) {
    final value = controller.text.trim();
    if (value.isEmpty) return null;
    return value;
  }

  Map<String, dynamic>? _buildSourceRawData() {
    final sourceUrl = _urlController.text.trim();
    if (sourceUrl.isEmpty) {
      return null;
    }
    final customOrder = int.tryParse(_customOrderController.text.trim()) ?? 0;
    final sourceName = _nameController.text.trim();

    return <String, dynamic>{
      ..._rawJsonMap,
      'sourceUrl': sourceUrl,
      'sourceName': sourceName,
      'sourceGroup': _nullableText(_groupController),
      'sourceComment': _nullableText(_commentController),
      'enabled': _enabled,
      'loginUrl': _nullableText(_loginUrlController),
      'loginUi': _nullableText(_loginUiController),
      'loginCheckJs': _nullableText(_loginCheckJsController),
      'coverDecodeJs': _nullableText(_coverDecodeJsController),
      'sortUrl': _nullableText(_sortUrlController),
      'singleUrl': _singleUrl,
      'customOrder': customOrder,
      'header': _nullableText(_headerController),
      'variableComment': _nullableText(_variableCommentController),
      'concurrentRate': _nullableText(_concurrentRateController),
      'jsLib': _nullableText(_jsLibController),
      'enabledCookieJar': _enabledCookieJar,
      // 列表规则
      'ruleArticles': _nullableText(_ruleArticlesController),
      'ruleNextPage': _nullableText(_ruleNextPageController),
      'ruleTitle': _nullableText(_ruleTitleController),
      'rulePubDate': _nullableText(_rulePubDateController),
      'ruleDescription': _nullableText(_ruleDescriptionController),
      'ruleImage': _nullableText(_ruleImageController),
      'ruleLink': _nullableText(_ruleLinkController),
      // WebView 规则
      'enableJs': _enableJs,
      'loadWithBaseUrl': _loadWithBaseUrl,
      'ruleContent': _nullableText(_ruleContentController),
      'injectJs': _nullableText(_injectJsController),
      'contentWhitelist': _nullableText(_contentWhitelistController),
      'contentBlacklist': _nullableText(_contentBlacklistController),
      'shouldOverrideUrlLoading':
          _nullableText(_shouldOverrideUrlLoadingController),
    };
  }

  Future<RssSource?> _persistSourceDraft() async {
    if (_saving) return null;
    final data = _buildSourceRawData();
    if (data == null) {
      await _showMessage('sourceUrl 不能为空');
      return null;
    }

    setState(() {
      _saving = true;
    });
    try {
      await _repo.upsertSourceRawJson(
        originalUrl: _originalUrl,
        rawJson: LegadoJson.encode(data),
      );
      final source = RssSource.fromJson(data);
      _rawJsonMap = data;
      _originalUrl = source.sourceUrl;
      return source;
    } catch (e) {
      await _showMessage('保存失败：$e');
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final source = await _persistSourceDraft();
    if (source == null || !mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _openDebugSource() async {
    final source = await _persistSourceDraft();
    if (source == null || !mounted) return;
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => RssSourceDebugView(source: source),
      ),
    );
  }

  Future<void> _showMessage(String message) async {
    if (!mounted) return;
    await showCupertinoBottomSheetDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  void _onEnabledChanged(bool value) {
    setState(() {
      _enabled = value;
    });
  }

  void _onSingleUrlChanged(bool value) {
    setState(() {
      _singleUrl = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing ? '编辑订阅源' : '新增订阅源';
    return AppCupertinoPageScaffold(
      title: title,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppNavBarButton(
            onPressed: _saving || _loading ? null : _openDebugSource,
            child: const Icon(CupertinoIcons.ant),
          ),
          AppNavBarButton(
            onPressed: _saving || _loading ? null : _save,
            child: _saving
                ? const CupertinoActivityIndicator()
                : const Text(
                    '保存',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
          ),
        ],
      ),
      child: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : RssSourceEditTabs(
              nameController: _nameController,
              urlController: _urlController,
              groupController: _groupController,
              commentController: _commentController,
              loginUrlController: _loginUrlController,
              loginUiController: _loginUiController,
              loginCheckJsController: _loginCheckJsController,
              coverDecodeJsController: _coverDecodeJsController,
              sortUrlController: _sortUrlController,
              customOrderController: _customOrderController,
              headerController: _headerController,
              variableCommentController: _variableCommentController,
              concurrentRateController: _concurrentRateController,
              jsLibController: _jsLibController,
              ruleArticlesController: _ruleArticlesController,
              ruleNextPageController: _ruleNextPageController,
              ruleTitleController: _ruleTitleController,
              rulePubDateController: _rulePubDateController,
              ruleDescriptionController: _ruleDescriptionController,
              ruleImageController: _ruleImageController,
              ruleLinkController: _ruleLinkController,
              ruleContentController: _ruleContentController,
              injectJsController: _injectJsController,
              contentWhitelistController: _contentWhitelistController,
              contentBlacklistController: _contentBlacklistController,
              shouldOverrideUrlLoadingController:
                  _shouldOverrideUrlLoadingController,
              enabled: _enabled,
              singleUrl: _singleUrl,
              enabledCookieJar: _enabledCookieJar,
              enableJs: _enableJs,
              loadWithBaseUrl: _loadWithBaseUrl,
              onEnabledChanged: _onEnabledChanged,
              onSingleUrlChanged: _onSingleUrlChanged,
              onEnabledCookieJarChanged: (v) =>
                  setState(() => _enabledCookieJar = v),
              onEnableJsChanged: (v) => setState(() => _enableJs = v),
              onLoadWithBaseUrlChanged: (v) =>
                  setState(() => _loadWithBaseUrl = v),
            ),
    );
  }
}
