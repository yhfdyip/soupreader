import 'package:flutter/cupertino.dart';

import '../../../app/theme/colors.dart';
import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../models/reading_settings.dart';
import 'reader_quick_settings_tab_bodies.dart';

enum ReaderQuickSettingsTab {
  typography,
  interface,
  page,
  more,
}

class ReaderQuickSettingsSheet extends StatefulWidget {
  final ReadingSettings settings;
  final List<ReadingThemeColors> themes;
  final ValueChanged<ReadingSettings> onSettingsChanged;
  final ReaderQuickSettingsTab initialTab;
  final VoidCallback onOpenFullSettings;

  const ReaderQuickSettingsSheet({
    super.key,
    required this.settings,
    required this.themes,
    required this.onSettingsChanged,
    required this.initialTab,
    required this.onOpenFullSettings,
  });

  @override
  State<ReaderQuickSettingsSheet> createState() =>
      _ReaderQuickSettingsSheetState();
}

class _ReaderQuickSettingsSheetState extends State<ReaderQuickSettingsSheet> {
  late ReaderQuickSettingsTab _tab;
  late ReadingSettings _draft;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _draft = widget.settings;
  }

  @override
  void didUpdateWidget(covariant ReaderQuickSettingsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 该 sheet 是一个独立 route，通常不会随外层 setState 重建；
    // 这里主要用于极少数场景（例如外部强制刷新）保持一致。
    _draft = widget.settings;
  }

  void _apply(ReadingSettings next) {
    setState(() => _draft = next);
    widget.onSettingsChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final sheetBg = ReaderSettingsTokens.sheetBackground(isDark: isDark);
    final height = MediaQuery.sizeOf(context).height * 0.65;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDesignTokens.radiusSheet)),
      child: Container(
        height: height,
        color: sheetBg,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              _buildGrabber(),
              _buildHeader(),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _buildTabs(),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _buildBody(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrabber() {
    final grabberColor = CupertinoColors.separator.resolveFrom(context);
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 6),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: grabberColor,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? CupertinoColors.white : CupertinoColors.label.resolveFrom(context);
    final secondaryColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.5)
        : CupertinoColors.secondaryLabel.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '阅读设置',
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            minimumSize: Size.zero,
            onPressed: _showMoreActions,
            child: Icon(
              CupertinoIcons.ellipsis_circle,
              color: secondaryColor,
              size: 20,
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            minimumSize: Size.zero,
            onPressed: () => Navigator.pop(context),
            child: Text(
              '完成',
              style: TextStyle(
                color: ReaderSettingsTokens.accent(isDark: isDark),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<ReaderQuickSettingsTab>(
        groupValue: _tab,
        padding: const EdgeInsets.all(3),
        onValueChanged: (v) {
          if (v == null) return;
          setState(() => _tab = v);
        },
        children: const <ReaderQuickSettingsTab, Widget>{
          ReaderQuickSettingsTab.typography: Padding(
            padding: EdgeInsets.symmetric(vertical: 7),
            child: Text('界面', textAlign: TextAlign.center),
          ),
          ReaderQuickSettingsTab.interface: Padding(
            padding: EdgeInsets.symmetric(vertical: 7),
            child: Text('设置', textAlign: TextAlign.center),
          ),
          ReaderQuickSettingsTab.page: Padding(
            padding: EdgeInsets.symmetric(vertical: 7),
            child: Text('翻页', textAlign: TextAlign.center),
          ),
          ReaderQuickSettingsTab.more: Padding(
            padding: EdgeInsets.symmetric(vertical: 7),
            child: Text('其他', textAlign: TextAlign.center),
          ),
        },
      ),
    );
  }

  Widget _buildBody() {
    switch (_tab) {
      case ReaderQuickSettingsTab.typography:
        return ReaderTypographyTab(
          key: const ValueKey('typography'),
          settings: _draft,
          onSettingsChanged: _apply,
        );
      case ReaderQuickSettingsTab.interface:
        return ReaderInterfaceTab(
          key: const ValueKey('interface'),
          settings: _draft,
          themes: widget.themes,
          onSettingsChanged: _apply,
        );
      case ReaderQuickSettingsTab.page:
        return ReaderPageTab(
          key: const ValueKey('page'),
          settings: _draft,
          onSettingsChanged: _apply,
        );
      case ReaderQuickSettingsTab.more:
        return ReaderMoreTab(
          key: const ValueKey('more'),
          settings: _draft,
          onSettingsChanged: _apply,
          onOpenFullSettings: widget.onOpenFullSettings,
        );
    }
  }

  void _showMoreActions() {
    showCupertinoBottomDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => CupertinoActionSheet(
        title: const Text('更多'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('打开完整阅读设置'),
            onPressed: () {
              Navigator.pop(context);
              widget.onOpenFullSettings();
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('恢复默认设置'),
            onPressed: () {
              Navigator.pop(context);
              _confirmResetDefaults();
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _confirmResetDefaults() {
    showCupertinoBottomDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('恢复默认设置'),
        content: const Text('\n将阅读设置恢复为默认值（立即生效）。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _apply(const ReadingSettings());
            },
            child: const Text('恢复'),
          ),
        ],
      ),
    );
  }
}

