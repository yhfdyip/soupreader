import 'package:flutter/cupertino.dart';

import '../../../app/theme/design_tokens.dart';
import '../models/reading_settings.dart';

/// 点击区域配置对话框
/// 允许用户配置9宫格区域的点击动作
class ClickActionConfigDialog extends StatefulWidget {
  final Map<String, int> initialConfig;
  final Function(Map<String, int>) onSave;

  const ClickActionConfigDialog({
    super.key,
    required this.initialConfig,
    required this.onSave,
  });

  @override
  State<ClickActionConfigDialog> createState() =>
      _ClickActionConfigDialogState();
}

class _ClickActionConfigDialogState extends State<ClickActionConfigDialog> {
  late Map<String, int> _config;
  String? _selectedZone;

  // 9宫格区域定义 (3x3)
  static const List<String> _zones = [
    'tl', 'tc', 'tr', // top-left, top-center, top-right
    'ml', 'mc', 'mr', // middle-left, middle-center, middle-right
    'bl', 'bc', 'br', // bottom-left, bottom-center, bottom-right
  ];

  // 默认配置
  static const Map<String, int> _defaultConfig = ClickAction.defaultZoneConfig;

  bool get _isDark => CupertinoTheme.of(context).brightness == Brightness.dark;

  Color get _accent =>
      _isDark ? AppDesignTokens.brandSecondary : AppDesignTokens.brandPrimary;

  Color get _panelBg =>
      _isDark ? const Color(0xFF1C1C1E) : AppDesignTokens.surfaceLight;

  Color get _textStrong =>
      _isDark ? CupertinoColors.white : AppDesignTokens.textStrong;

  Color get _textNormal =>
      _isDark ? CupertinoColors.systemGrey : AppDesignTokens.textNormal;

  Color get _textSubtle => _isDark
      ? CupertinoColors.systemGrey.withValues(alpha: 0.75)
      : AppDesignTokens.textMuted;

  Color get _lineColor =>
      _isDark ? AppDesignTokens.borderDark : AppDesignTokens.borderLight;

  Color get _chipBg => _isDark
      ? CupertinoColors.systemGrey.withValues(alpha: 0.16)
      : AppDesignTokens.pageBgLight;

  @override
  void initState() {
    super.initState();
    _config = Map<String, int>.from(widget.initialConfig);
    // 填充缺失的区域
    for (final zone in _zones) {
      _config.putIfAbsent(zone, () => _defaultConfig[zone]!);
    }
  }

  String _getZoneName(String zone) {
    switch (zone) {
      case 'tl':
        return '左上';
      case 'tc':
        return '中上';
      case 'tr':
        return '右上';
      case 'ml':
        return '左中';
      case 'mc':
        return '中间';
      case 'mr':
        return '右中';
      case 'bl':
        return '左下';
      case 'bc':
        return '中下';
      case 'br':
        return '右下';
      default:
        return zone;
    }
  }

  Color _getActionColor(int action) {
    switch (action) {
      case ClickAction.showMenu:
        return _accent;
      case ClickAction.nextPage:
        return AppDesignTokens.success;
      case ClickAction.prevPage:
        return AppDesignTokens.info;
      case ClickAction.nextChapter:
        return AppDesignTokens.warning;
      case ClickAction.prevChapter:
        return const Color(0xFF8B5CF6);
      case ClickAction.addBookmark:
        return const Color(0xFFEC4899);
      case ClickAction.openChapterList:
        return const Color(0xFF6366F1);
      default:
        return _textSubtle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: _panelBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildGrabber(),
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // 说明文字
                    Text(
                      '点击下方区域选择该位置的动作',
                      style: TextStyle(color: _textNormal, fontSize: 14),
                    ),
                    const SizedBox(height: 16),

                    // 9宫格预览
                    _buildGridPreview(),

                    const SizedBox(height: 24),

                    // 动作说明
                    _buildLegend(),

                    const SizedBox(height: 16),

                    // 重置按钮
                    CupertinoButton(
                      onPressed: _resetToDefault,
                      child: Text(
                        '恢复默认',
                        style: TextStyle(
                          color: _textSubtle,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrabber() {
    final color = _isDark
        ? CupertinoColors.white.withValues(alpha: 0.24)
        : AppDesignTokens.textMuted.withValues(alpha: 0.35);
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        width: 38,
        height: 4,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _lineColor),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '点击区域设置',
              style: TextStyle(
                color: _textStrong,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: const Size(30, 30),
            onPressed: () {
              widget.onSave(_config);
              Navigator.pop(context);
            },
            child: Text(
              '保存',
              style: TextStyle(
                color: _accent,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.all(6),
            minimumSize: const Size(30, 30),
            onPressed: () => Navigator.pop(context),
            child: Icon(
              CupertinoIcons.xmark,
              color: _textSubtle,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridPreview() {
    return AspectRatio(
      aspectRatio: 0.6, // 模拟手机屏幕比例
      child: Container(
        decoration: BoxDecoration(
          color: _chipBg,
          border: Border.all(color: _lineColor),
          borderRadius: BorderRadius.circular(10),
        ),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.6,
          ),
          itemCount: 9,
          itemBuilder: (context, index) {
            final zone = _zones[index];
            final action = _config[zone] ?? ClickAction.showMenu;
            final isSelected = _selectedZone == zone;
            final actionColor = _getActionColor(action);

            return GestureDetector(
              onTap: () => _showActionPicker(zone),
              child: Container(
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color:
                      actionColor.withValues(alpha: isSelected ? 0.28 : 0.14),
                  border: Border.all(
                    color: isSelected
                        ? _accent
                        : actionColor.withValues(alpha: 0.45),
                    width: isSelected ? 1.8 : 1,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _getZoneName(zone),
                      style: TextStyle(
                        color: _textSubtle,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ClickAction.getName(action),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: actionColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ClickAction.allActions.map((action) {
        final actionColor = _getActionColor(action);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: actionColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: actionColor.withValues(alpha: 0.4)),
          ),
          child: Text(
            ClickAction.getName(action),
            style: TextStyle(
              color: actionColor,
              fontSize: 12,
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showActionPicker(String zone) {
    setState(() {
      _selectedZone = zone;
    });

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('选择 ${_getZoneName(zone)} 的动作'),
        actions: ClickAction.allActions.map((action) {
          final actionColor = _getActionColor(action);
          return CupertinoActionSheetAction(
            onPressed: () {
              setState(() {
                _config[zone] = action;
                _selectedZone = null;
              });
              Navigator.pop(context);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: actionColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(ClickAction.getName(action)),
              ],
            ),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () {
            setState(() {
              _selectedZone = null;
            });
            Navigator.pop(context);
          },
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _resetToDefault() {
    setState(() {
      _config = Map<String, int>.from(_defaultConfig);
      _selectedZone = null;
    });
  }
}

/// 显示点击区域配置对话框
void showClickActionConfigDialog(
  BuildContext context, {
  Map<String, int>? initialConfig,
  Map<String, int>? currentConfig,
  required Function(Map<String, int>) onSave,
}) {
  final resolvedConfig = initialConfig ?? currentConfig;
  if (resolvedConfig == null) {
    throw ArgumentError('initialConfig 或 currentConfig 至少需要提供一个');
  }

  showCupertinoModalPopup(
    context: context,
    builder: (context) => ClickActionConfigDialog(
      initialConfig: resolvedConfig,
      onSave: onSave,
    ),
  );
}
