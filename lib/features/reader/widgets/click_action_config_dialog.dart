import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
  static const Map<String, int> _defaultConfig = {
    'tl': ClickAction.prevPage,
    'tc': ClickAction.showMenu,
    'tr': ClickAction.nextPage,
    'ml': ClickAction.prevPage,
    'mc': ClickAction.showMenu,
    'mr': ClickAction.nextPage,
    'bl': ClickAction.prevPage,
    'bc': ClickAction.showMenu,
    'br': ClickAction.nextPage,
  };

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
        return Colors.amber;
      case ClickAction.nextPage:
        return Colors.green;
      case ClickAction.prevPage:
        return Colors.blue;
      case ClickAction.nextChapter:
        return Colors.orange;
      case ClickAction.prevChapter:
        return Colors.cyan;
      case ClickAction.addBookmark:
        return Colors.red;
      case ClickAction.openChapterList:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 标题栏
          _buildHeader(),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 说明文字
                  const Text(
                    '点击下方区域选择该位置的动作',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 16),

                  // 9宫格预览
                  _buildGridPreview(),

                  const SizedBox(height: 24),

                  // 动作说明
                  _buildLegend(),

                  const SizedBox(height: 16),

                  // 重置按钮
                  TextButton.icon(
                    onPressed: _resetToDefault,
                    icon: const Icon(Icons.refresh, color: Colors.white70),
                    label: const Text('恢复默认',
                        style: TextStyle(color: Colors.white70)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF333333)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '点击区域设置',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              TextButton(
                onPressed: () {
                  widget.onSave(_config);
                  Navigator.pop(context);
                },
                child: const Text('保存', style: TextStyle(color: Colors.amber)),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ],
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
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(8),
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

            return GestureDetector(
              onTap: () => _showActionPicker(zone),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: _getActionColor(action)
                      .withOpacity(isSelected ? 0.5 : 0.2),
                  border: Border.all(
                    color: isSelected
                        ? Colors.white
                        : _getActionColor(action).withOpacity(0.5),
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _getZoneName(zone),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ClickAction.getName(action),
                      style: TextStyle(
                        color: _getActionColor(action),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
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
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getActionColor(action).withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: _getActionColor(action).withOpacity(0.5)),
          ),
          child: Text(
            ClickAction.getName(action),
            style: TextStyle(
              color: _getActionColor(action),
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
                    color: _getActionColor(action),
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
    });
  }
}

/// 显示点击区域配置对话框
Future<void> showClickActionConfigDialog(
  BuildContext context, {
  required Map<String, int> currentConfig,
  required Function(Map<String, int>) onSave,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ClickActionConfigDialog(
      initialConfig: currentConfig,
      onSave: onSave,
    ),
  );
}
