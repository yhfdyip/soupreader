import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show Material, ReorderableDragStartListener, ReorderableListView;

import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/app_sheet_panel.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/app_popover_menu.dart';
import '../models/reading_settings.dart';
import 'reader_style_edit_sheet.dart';

/// 背景文字样式完整列表管理页，类似书源管理。
///
/// 列表每项展示名称 + 右侧颜色图例（背景色/文字色圆点）。
/// 右上角三横菜单：新建、导入、导出、分享。
/// 底部批量操作栏：全选/取消全选、反选、删除（仅自定义样式可删除）。
/// 支持拖拽排序。
class ReaderStyleConfigListSheet extends StatefulWidget {
  final List<ReadStyleConfig> configs;
  final int selectedIndex;
  final ValueChanged<List<ReadStyleConfig>> onConfigsChanged;
  final ValueChanged<int> onSelectIndex;
  final VoidCallback? onImport;
  final VoidCallback? onExport;
  final VoidCallback? onShare;

  const ReaderStyleConfigListSheet({
    super.key,
    required this.configs,
    required this.selectedIndex,
    required this.onConfigsChanged,
    required this.onSelectIndex,
    this.onImport,
    this.onExport,
    this.onShare,
  });

  @override
  State<ReaderStyleConfigListSheet> createState() =>
      _ReaderStyleConfigListSheetState();
}

class _ReaderStyleConfigListSheetState
    extends State<ReaderStyleConfigListSheet> {
  late List<ReadStyleConfig> _configs;
  late int _selectedIndex;
  final Set<int> _checkedIndices = {};
  bool _isSelecting = false;
  final GlobalKey _moreMenuKey = GlobalKey();

  static bool _isBuiltin(ReadStyleConfig c) {
    return kDefaultReadStyleConfigs.any(
      (d) =>
          d.name == c.name &&
          d.backgroundColor == c.backgroundColor &&
          d.textColor == c.textColor,
    );
  }

  Set<int> get _deletableIndices => {
        for (var i = 0; i < _configs.length; i++)
          if (!_isBuiltin(_configs[i])) i,
      };

  @override
  void initState() {
    super.initState();
    _configs = List.from(widget.configs);
    _selectedIndex = widget.selectedIndex;
  }

  bool get _isDark =>
      CupertinoTheme.of(context).brightness == Brightness.dark;

  Color get _accent =>
      _isDark ? AppDesignTokens.brandSecondary : AppDesignTokens.brandPrimary;

  void _notifyChanged() {
    widget.onConfigsChanged(_configs);
    widget.onSelectIndex(_selectedIndex);
  }

  void _addNew() {
    const newConfig = ReadStyleConfig(
      name: '新样式',
      backgroundColor: 0xFFFFFFFF,
      textColor: 0xFF333333,
      bgType: ReadStyleConfig.bgTypeColor,
      bgStr: '#FFFFFF',
      bgAlpha: 100,
    );
    final newIndex = _configs.length;
    setState(() {
      _configs = [..._configs, newConfig];
      _selectedIndex = newIndex;
    });
    _notifyChanged();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openEditSheet(newIndex);
    });
  }

  // 从列表移除 index，同步修正 _selectedIndex 和 _checkedIndices。
  void _removeIndex(int index, List<ReadStyleConfig> next) {
    next.removeAt(index);
    if (_selectedIndex >= next.length) _selectedIndex = next.length - 1;
    _checkedIndices.remove(index);
    final rebuilt = <int>{
      for (final i in _checkedIndices) i > index ? i - 1 : i,
    };
    _checkedIndices
      ..clear()
      ..addAll(rebuilt);
  }

  void _openEditSheet(int index) {
    final config = _configs[index];
    final isBuiltin = _isBuiltin(config);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => ReaderStyleEditSheet(
        config: config,
        canDelete: !isBuiltin,
        onChanged: (updated) {
          setState(() {
            final next = List<ReadStyleConfig>.from(_configs);
            next[index] = updated;
            _configs = next;
          });
          _notifyChanged();
        },
        onDelete: isBuiltin
            ? null
            : () {
                setState(() {
                  final next = List<ReadStyleConfig>.from(_configs);
                  _removeIndex(index, next);
                  _configs = next;
                });
                _notifyChanged();
              },
      ),
    );
  }

  void _toggleCheck(int index) {
    if (_isBuiltin(_configs[index])) return;
    setState(() {
      if (!_checkedIndices.remove(index)) _checkedIndices.add(index);
    });
  }

  void _toggleSelectAll() {
    final deletable = _deletableIndices;
    setState(() {
      if (_checkedIndices.containsAll(deletable) && deletable.isNotEmpty) {
        _checkedIndices.clear();
      } else {
        _checkedIndices
          ..clear()
          ..addAll(deletable);
      }
    });
  }

  void _invertSelection() {
    final inverted = _deletableIndices.difference(_checkedIndices);
    setState(() {
      _checkedIndices
        ..clear()
        ..addAll(inverted);
    });
  }

  void _deleteChecked() {
    if (_checkedIndices.isEmpty) return;
    final count = _checkedIndices.length;
    showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('删除样式'),
        content: Text('确定删除选中的 $count 个样式吗？此操作不可撤销。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed != true || !mounted) return;
      final sorted = _checkedIndices.toList()..sort((a, b) => b.compareTo(a));
      setState(() {
        final next = List<ReadStyleConfig>.from(_configs);
        for (final i in sorted) next.removeAt(i);
        _configs = next;
        _checkedIndices.clear();
        _selectedIndex =
            _configs.isEmpty ? 0 : _selectedIndex.clamp(0, _configs.length - 1);
        _isSelecting = false;
      });
      _notifyChanged();
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;
    setState(() {
      final next = List<ReadStyleConfig>.from(_configs);
      next.insert(newIndex, next.removeAt(oldIndex));
      _configs = next;
      if (_selectedIndex == oldIndex) {
        _selectedIndex = newIndex;
      } else if (oldIndex < _selectedIndex && newIndex >= _selectedIndex) {
        _selectedIndex -= 1;
      } else if (oldIndex > _selectedIndex && newIndex <= _selectedIndex) {
        _selectedIndex += 1;
      }
    });
    _notifyChanged();
  }

  void _showMoreMenu() {
    showAppPopoverMenu<_MenuAction>(
      context: context,
      anchorKey: _moreMenuKey,
      items: [
        const AppPopoverMenuItem(
          value: _MenuAction.addNew,
          icon: CupertinoIcons.plus,
          label: '新建样式',
        ),
        if (widget.onImport != null)
          const AppPopoverMenuItem(
            value: _MenuAction.import_,
            icon: CupertinoIcons.tray_arrow_down,
            label: '导入',
          ),
        if (widget.onExport != null)
          const AppPopoverMenuItem(
            value: _MenuAction.export_,
            icon: CupertinoIcons.tray_arrow_up,
            label: '导出',
          ),
        if (widget.onShare != null)
          const AppPopoverMenuItem(
            value: _MenuAction.share,
            icon: CupertinoIcons.share,
            label: '分享',
          ),
      ],
    ).then((action) {
      if (!mounted || action == null) return;
      switch (action) {
        case _MenuAction.addNew:
          _addNew();
        case _MenuAction.import_:
          widget.onImport?.call();
        case _MenuAction.export_:
          widget.onExport?.call();
        case _MenuAction.share:
          widget.onShare?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _isDark;
    final sep = CupertinoColors.separator.resolveFrom(context);
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondaryLabel =
        CupertinoColors.secondaryLabel.resolveFrom(context);

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: AppSheetPanel(
        contentPadding: EdgeInsets.zero,
        child: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildHeader(labelColor, sep),
            Expanded(
              child: _configs.isEmpty
                  ? Center(
                      child: Text(
                        '暂无样式',
                        style: TextStyle(
                            color: secondaryLabel, fontSize: 15),
                      ),
                    )
                  : ReorderableListView.builder(
                      itemCount: _configs.length,
                      onReorder: _isSelecting ? (_, __) {} : _onReorder,
                      proxyDecorator: (child, index, animation) => Material(
                        color: CupertinoColors.transparent,
                        child: child,
                      ),
                      itemBuilder: (_, i) => _buildItem(
                        i,
                        isDark,
                        labelColor,
                        secondaryLabel,
                        sep,
                      ),
                    ),
            ),
            if (_isSelecting) _buildBatchBar(sep),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildHeader(Color labelColor, Color sep) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: sep,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              AppNavBarButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Icon(CupertinoIcons.back, color: _accent, size: 22),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '背景文字样式',
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              AppNavBarButton(
                onPressed: _configs.isEmpty && !_isSelecting
                    ? null
                    : () => setState(() {
                          _isSelecting = !_isSelecting;
                          if (!_isSelecting) _checkedIndices.clear();
                        }),
                child: Text(
                  _isSelecting ? '完成' : '多选',
                  style: TextStyle(color: _accent, fontSize: 13),
                ),
              ),
              AppNavBarButton(
                key: _moreMenuKey,
                onPressed: _isSelecting ? null : _showMoreMenu,
                child: Icon(
                  CupertinoIcons.ellipsis,
                  color:
                      _isSelecting ? CupertinoColors.inactiveGray : _accent,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
        Container(height: 0.5, color: sep),
      ],
    );
  }

  Widget _buildItem(
    int index,
    bool isDark,
    Color labelColor,
    Color secondaryLabel,
    Color sep,
  ) {
    final config = _configs[index];
    final isSelected = index == _selectedIndex;
    final isChecked = _checkedIndices.contains(index);
    final isBuiltin = _isBuiltin(config);
    final itemBg =
        CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context);

    return Column(
      key: ObjectKey(config),
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (_isSelecting) {
              _toggleCheck(index);
            } else {
              setState(() => _selectedIndex = index);
              widget.onSelectIndex(index);
            }
          },
          onLongPress: () {
            if (!_isSelecting) _openEditSheet(index);
          },
          child: Container(
            color: itemBg,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                if (_isSelecting) ...[
                  Icon(
                    isBuiltin
                        ? CupertinoIcons.minus_circle
                        : (isChecked
                            ? CupertinoIcons.check_mark_circled_solid
                            : CupertinoIcons.circle),
                    size: 20,
                    color: isChecked ? _accent : secondaryLabel,
                  ),
                  const SizedBox(width: 10),
                ],
                if (!_isSelecting)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: isSelected ? 3 : 0,
                    height: 18,
                    margin: EdgeInsets.only(right: isSelected ? 8 : 0),
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                Expanded(
                  child: Text(
                    config.name.trim().isEmpty ? '未命名' : config.name.trim(),
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 15,
                      fontWeight: isSelected && !_isSelecting
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
                if (isBuiltin) _buildBuiltinBadge(secondaryLabel),
                _buildColorDot(Color(config.backgroundColor), sep),
                const SizedBox(width: 4),
                _buildColorDot(Color(config.textColor), sep),
                const SizedBox(width: 8),
                if (!_isSelecting)
                  ReorderableDragStartListener(
                    index: index,
                    child: Icon(
                      CupertinoIcons.line_horizontal_3,
                      size: 18,
                      color: secondaryLabel,
                    ),
                  ),
              ],
            ),
          ),
        ),
        Container(
          height: 0.5,
          margin: const EdgeInsets.only(left: 16),
          color: sep,
        ),
      ],
    );
  }

  Widget _buildBuiltinBadge(Color secondaryLabel) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: secondaryLabel.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '内置',
        style: TextStyle(color: secondaryLabel, fontSize: 11),
      ),
    );
  }

  Widget _buildColorDot(Color color, Color border) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 0.5),
      ),
    );
  }

  Widget _buildBatchBar(Color sep) {
    final deletable = _deletableIndices;
    final allSelected =
        deletable.isNotEmpty && _checkedIndices.containsAll(deletable);
    final hasChecked = _checkedIndices.isNotEmpty;
    final barBg =
        CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context);
    final enabledColor = _accent;
    const disabledColor = CupertinoColors.inactiveGray;

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: sep, width: 0.5)),
        color: barBg,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                minimumSize: const Size(30, 30),
                onPressed: _toggleSelectAll,
                child: Text(
                  allSelected ? '取消全选' : '全选',
                  style: TextStyle(color: enabledColor, fontSize: 13),
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                minimumSize: const Size(30, 30),
                onPressed: hasChecked ? _invertSelection : null,
                child: Text(
                  '反选',
                  style: TextStyle(
                    color: hasChecked ? enabledColor : disabledColor,
                    fontSize: 13,
                  ),
                ),
              ),
              const Spacer(),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                minimumSize: const Size(30, 30),
                onPressed: hasChecked ? _deleteChecked : null,
                child: Text(
                  '删除',
                  style: TextStyle(
                    color: hasChecked
                        ? CupertinoColors.destructiveRed
                        : disabledColor,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _MenuAction { addNew, import_, export_, share }
