import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_sheet_panel.dart';
import '../../../app/widgets/app_sheet_header.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/config/migration_exclusions.dart';
import '../models/reading_settings.dart';

/// 点击区域配置对话框 — 允许用户配置 9 宫格区域的点击动作。
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

  List<int> get _availableActions => ClickAction.availableActions(
        excludeTts: MigrationExclusions.excludeTts,
      );

  @override
  void initState() {
    super.initState();
    _config = _normalizeConfig(Map<String, int>.from(widget.initialConfig));
  }

  Map<String, int> _normalizeConfig(Map<String, int> raw) =>
      ClickAction.normalizeConfigForExclusions(
        raw,
        excludeTts: MigrationExclusions.excludeTts,
      );

  String _zoneName(String zone) => switch (zone) {
        'tl' => '左上',
        'tc' => '中上',
        'tr' => '右上',
        'ml' => '左中',
        'mc' => '中间',
        'mr' => '右中',
        'bl' => '左下',
        'bc' => '中下',
        'br' => '右下',
        _ => zone,
      };

  Color _actionColor(int action, AppUiTokens ui) => switch (action) {
        ClickAction.showMenu => ui.colors.accent,
        ClickAction.nextPage => AppDesignTokens.success,
        ClickAction.prevPage => AppDesignTokens.info,
        ClickAction.nextChapter => AppDesignTokens.warning,
        ClickAction.prevChapter => const Color(0xFF8B5CF6),
        ClickAction.addBookmark => const Color(0xFFEC4899),
        ClickAction.openChapterList => const Color(0xFF6366F1),
        _ => CupertinoColors.tertiaryLabel.resolveFrom(context),
      };

  @override
  Widget build(BuildContext context) {
    final ui = AppUiTokens.resolve(context);
    return AppSheetPanel(
      contentPadding: EdgeInsets.zero,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSheetHeader(title: '点击区域设置'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                '点击下方区域选择该位置的动作',
                textAlign: TextAlign.center,
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                      fontSize: 13,
                      color: ui.colors.secondaryLabel,
                    ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildGridPreview(context, ui),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildLegend(context, ui),
            ),
            CupertinoButton(
              onPressed: _resetToDefault,
              child: Text(
                '恢复默认',
                style: TextStyle(
                  color: ui.colors.tertiaryLabel,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridPreview(BuildContext context, AppUiTokens ui) {
    final screenSize = MediaQuery.sizeOf(context);
    final gridBg = CupertinoColors.tertiarySystemFill.resolveFrom(context);
    final sep = ui.colors.separator;

    // 网格宽高比与屏幕一致，但限制最大高度避免撑满对话框
    final gridWidth = screenSize.width - 32;
    final gridHeight = (gridWidth * screenSize.height / screenSize.width)
        .clamp(0.0, screenSize.height * 0.28);
    final cellWidth = gridWidth / 3;
    final cellHeight = gridHeight / 3;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
      child: Container(
        width: gridWidth,
        height: gridHeight,
        decoration: BoxDecoration(
          color: gridBg,
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
          border: Border.all(
              color: sep, width: AppDesignTokens.hairlineBorderWidth),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (row) {
            return Row(
              children: List.generate(3, (col) {
                final index = row * 3 + col;
                return SizedBox(
                  width: cellWidth,
                  height: cellHeight,
                  child: _buildCell(context, ui, index, sep),
                );
              }),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildCell(
    BuildContext context,
    AppUiTokens ui,
    int index,
    Color sep,
  ) {
    final zone = ClickAction.zoneOrder[index];
    final action = _config[zone] ?? ClickAction.showMenu;
    final isSelected = _selectedZone == zone;
    final color = _actionColor(action, ui);

    final row = index ~/ 3;
    final col = index % 3;
    final showRight = col < 2;
    final showBottom = row < 2;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        _showActionPicker(zone);
      },
      child: AnimatedContainer(
        duration: AppDesignTokens.motionQuick,
        decoration: BoxDecoration(
          color: color.withValues(alpha: isSelected ? 0.22 : 0.10),
          border: Border(
            right: showRight
                ? BorderSide(
                    color: sep, width: AppDesignTokens.hairlineBorderWidth)
                : BorderSide.none,
            bottom: showBottom
                ? BorderSide(
                    color: sep, width: AppDesignTokens.hairlineBorderWidth)
                : BorderSide.none,
            left: isSelected
                ? BorderSide(color: color.withValues(alpha: 0.6), width: 1.5)
                : BorderSide.none,
            top: isSelected
                ? BorderSide(color: color.withValues(alpha: 0.6), width: 1.5)
                : BorderSide.none,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _zoneName(zone),
              style: TextStyle(
                color: ui.colors.tertiaryLabel,
                fontSize: 10,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              ClickAction.getName(action),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(BuildContext context, AppUiTokens ui) {
    final textStyle = CupertinoTheme.of(context).textTheme.textStyle;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: _availableActions.map((action) {
        final color = _actionColor(action, ui);
        return DecoratedBox(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusControl),
            border: Border.all(
              color: color.withValues(alpha: 0.35),
              width: AppDesignTokens.hairlineBorderWidth,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Text(
              ClickAction.getName(action),
              style: textStyle.copyWith(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.2,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showActionPicker(String zone) {
    setState(() => _selectedZone = zone);

    showCupertinoBottomSheetDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CupertinoActionSheet(
        title: Text('选择「${_zoneName(zone)}」的动作'),
        actions: _availableActions.map((action) {
          final color = _actionColor(action, AppUiTokens.resolve(context));
          return CupertinoActionSheetAction(
            onPressed: () {
              _applyConfig({...Map<String, int>.from(_config), zone: action});
              Navigator.pop(ctx);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
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
            setState(() => _selectedZone = null);
            Navigator.pop(ctx);
          },
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _resetToDefault() {
    _applyConfig(
      Map<String, int>.from(ClickAction.defaultZoneConfig),
      showRecoveryNotice: false,
    );
  }

  void _applyConfig(
    Map<String, int> next, {
    bool showRecoveryNotice = true,
  }) {
    final hadMenu = ClickAction.hasMenuZone(next);
    final normalized = _normalizeConfig(next);
    final recovered = !hadMenu && ClickAction.hasMenuZone(normalized);
    setState(() {
      _config = normalized;
      _selectedZone = null;
    });
    widget.onSave(Map<String, int>.from(normalized));
    if (recovered && showRecoveryNotice) _showMenuRecoveryNotice();
  }

  void _showMenuRecoveryNotice() {
    showCupertinoBottomSheetDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: const Text('\n当前没有配置菜单区域，已自动恢复中间区域为菜单。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }
}

/// 显示点击区域配置对话框。
void showClickActionConfigDialog(
  BuildContext context, {
  Map<String, int>? initialConfig,
  Map<String, int>? currentConfig,
  required Function(Map<String, int>) onSave,
}) {
  final config = initialConfig ?? currentConfig;
  if (config == null) {
    throw ArgumentError('initialConfig 或 currentConfig 至少需要提供一个');
  }
  showCupertinoBottomSheetDialog(
    context: context,
    builder: (context) => ClickActionConfigDialog(
      initialConfig: config,
      onSave: onSave,
    ),
  );
}
