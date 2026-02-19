import 'dart:convert';

import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/rss_source_repository.dart';
import '../../../core/utils/legado_json.dart';
import '../models/rss_source.dart';

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
  final TextEditingController _sortUrlController = TextEditingController();
  final TextEditingController _customOrderController = TextEditingController();

  bool _enabled = true;
  bool _singleUrl = false;
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
    _sortUrlController.dispose();
    _customOrderController.dispose();
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
    _sortUrlController.text = source.sortUrl ?? '';
    _customOrderController.text = source.customOrder.toString();
    _enabled = source.enabled;
    _singleUrl = source.singleUrl;
  }

  String? _nullableText(TextEditingController controller) {
    final value = controller.text.trim();
    if (value.isEmpty) return null;
    return value;
  }

  Future<void> _save() async {
    if (_saving) return;
    final sourceUrl = _urlController.text.trim();
    if (sourceUrl.isEmpty) {
      await _showMessage('sourceUrl 不能为空');
      return;
    }
    final customOrder = int.tryParse(_customOrderController.text.trim()) ?? 0;
    final sourceName = _nameController.text.trim();

    final data = <String, dynamic>{
      ..._rawJsonMap,
      'sourceUrl': sourceUrl,
      'sourceName': sourceName,
      'sourceGroup': _nullableText(_groupController),
      'sourceComment': _nullableText(_commentController),
      'enabled': _enabled,
      'loginUrl': _nullableText(_loginUrlController),
      'sortUrl': _nullableText(_sortUrlController),
      'singleUrl': _singleUrl,
      'customOrder': customOrder,
    };

    setState(() {
      _saving = true;
    });
    try {
      await _repo.upsertSourceRawJson(
        originalUrl: _originalUrl,
        rawJson: LegadoJson.encode(data),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      await _showMessage('保存失败：$e');
    } finally {
      if (!mounted) return;
      setState(() {
        _saving = false;
      });
    }
  }

  Future<void> _showMessage(String message) async {
    if (!mounted) return;
    await showCupertinoDialog<void>(
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

  @override
  Widget build(BuildContext context) {
    final title = _isEditing ? '编辑订阅源' : '新增订阅源';
    return AppCupertinoPageScaffold(
      title: title,
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: _saving || _loading ? null : _save,
        child: _saving
            ? const CupertinoActivityIndicator()
            : const Text(
                '保存',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
      ),
      child: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : ListView(
              padding: const EdgeInsets.only(top: 12, bottom: 24),
              children: [
                CupertinoFormSection.insetGrouped(
                  header: const Text('基本信息'),
                  children: [
                    CupertinoTextFormFieldRow(
                      controller: _nameController,
                      placeholder: '源名称',
                      prefix: const Text('名称'),
                      textInputAction: TextInputAction.next,
                    ),
                    CupertinoTextFormFieldRow(
                      controller: _urlController,
                      placeholder: 'https://example.com/rss',
                      prefix: const Text('URL'),
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                    ),
                    CupertinoTextFormFieldRow(
                      controller: _groupController,
                      placeholder: '分组A,分组B',
                      prefix: const Text('分组'),
                      textInputAction: TextInputAction.next,
                    ),
                    CupertinoTextFormFieldRow(
                      controller: _commentController,
                      placeholder: '注释',
                      prefix: const Text('注释'),
                      textInputAction: TextInputAction.next,
                    ),
                  ],
                ),
                CupertinoFormSection.insetGrouped(
                  header: const Text('规则与状态'),
                  children: [
                    CupertinoTextFormFieldRow(
                      controller: _loginUrlController,
                      placeholder: '登录地址（可选）',
                      prefix: const Text('登录'),
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                    ),
                    CupertinoTextFormFieldRow(
                      controller: _sortUrlController,
                      placeholder: '分类地址/脚本（可选）',
                      prefix: const Text('分类'),
                      textInputAction: TextInputAction.next,
                    ),
                    CupertinoTextFormFieldRow(
                      controller: _customOrderController,
                      placeholder: '0',
                      prefix: const Text('排序'),
                      textInputAction: TextInputAction.done,
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: false,
                      ),
                    ),
                    CupertinoFormRow(
                      prefix: const Text('启用'),
                      child: CupertinoSwitch(
                        value: _enabled,
                        onChanged: (value) {
                          setState(() {
                            _enabled = value;
                          });
                        },
                      ),
                    ),
                    CupertinoFormRow(
                      prefix: const Text('singleUrl'),
                      child: CupertinoSwitch(
                        value: _singleUrl,
                        onChanged: (value) {
                          setState(() {
                            _singleUrl = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
