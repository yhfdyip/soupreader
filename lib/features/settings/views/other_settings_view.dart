import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/services/settings_service.dart';
import 'settings_placeholders.dart';
import 'settings_ui_tokens.dart';
import 'storage_settings_view.dart';

class OtherSettingsView extends StatefulWidget {
  const OtherSettingsView({super.key});

  @override
  State<OtherSettingsView> createState() => _OtherSettingsViewState();
}

class _OtherSettingsViewState extends State<OtherSettingsView> {
  final SettingsService _settingsService = SettingsService();
  late AppSettings _appSettings;

  Color _accent(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    return isDark
        ? AppDesignTokens.brandSecondary
        : AppDesignTokens.brandPrimary;
  }

  @override
  void initState() {
    super.initState();
    _appSettings = _settingsService.appSettings;
    _settingsService.appSettingsListenable.addListener(_onChanged);
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

  Future<void> _pickBookshelfViewMode() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('书架显示方式'),
        actions: [
          _modeAction(ctx, BookshelfViewMode.grid, '网格'),
          _modeAction(ctx, BookshelfViewMode.list, '列表'),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
  }

  CupertinoActionSheetAction _modeAction(
    BuildContext ctx,
    BookshelfViewMode mode,
    String label,
  ) {
    final selected = _appSettings.bookshelfViewMode == mode;
    return CupertinoActionSheetAction(
      onPressed: () async {
        await _settingsService.saveAppSettings(
          _appSettings.copyWith(bookshelfViewMode: mode),
        );
        if (ctx.mounted) Navigator.pop(ctx);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          if (selected) ...[
            const SizedBox(width: 8),
            Icon(CupertinoIcons.checkmark, size: 18, color: _accent(context)),
          ],
        ],
      ),
    );
  }

  Future<void> _pickBookshelfSortMode() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('新书默认排序'),
        actions: [
          _sortAction(ctx, BookshelfSortMode.recentRead, '最近阅读'),
          _sortAction(ctx, BookshelfSortMode.recentAdded, '最近加入'),
          _sortAction(ctx, BookshelfSortMode.title, '书名'),
          _sortAction(ctx, BookshelfSortMode.author, '作者'),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
  }

  CupertinoActionSheetAction _sortAction(
    BuildContext ctx,
    BookshelfSortMode mode,
    String label,
  ) {
    final selected = _appSettings.bookshelfSortMode == mode;
    return CupertinoActionSheetAction(
      onPressed: () async {
        await _settingsService.saveAppSettings(
          _appSettings.copyWith(bookshelfSortMode: mode),
        );
        if (ctx.mounted) Navigator.pop(ctx);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          if (selected) ...[
            const SizedBox(width: 8),
            Icon(CupertinoIcons.checkmark, size: 18, color: _accent(context)),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '其它设置',
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        children: [
          CupertinoListSection.insetGrouped(
            header: const Text('基本设置'),
            children: [
              CupertinoListTile.notched(
                title: const Text('主页面'),
                additionalInfo: _plannedInfo(),
                trailing: const CupertinoListTileChevron(),
                onTap: () => SettingsPlaceholders.showNotImplemented(
                  context,
                  title: '主页面（底部导航栏顺序/显示）暂未实现',
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('更换图标'),
                additionalInfo: _plannedInfo(),
                trailing: const CupertinoListTileChevron(),
                onTap: () => SettingsPlaceholders.showNotImplemented(
                  context,
                  title: '更换图标暂未实现',
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('自动刷新'),
                additionalInfo: _plannedInfo(),
                trailing: const CupertinoListTileChevron(),
                onTap: () => SettingsPlaceholders.showNotImplemented(
                  context,
                  title: '自动刷新暂未实现',
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('竖屏锁定'),
                additionalInfo: _plannedInfo(),
                trailing: const CupertinoListTileChevron(),
                onTap: () => SettingsPlaceholders.showNotImplemented(
                  context,
                  title: '竖屏锁定暂未实现',
                ),
              ),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('源设置'),
            children: [
              CupertinoListTile.notched(
                title: const Text('服务器证书验证'),
                additionalInfo: _plannedInfo(),
                trailing: const CupertinoListTileChevron(),
                onTap: () => SettingsPlaceholders.showNotImplemented(
                  context,
                  title: '服务器证书验证开关暂未实现（需要对 Dio/HttpClient 做统一配置）',
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('开启 18+ 网址检测'),
                additionalInfo: _plannedInfo(),
                trailing: const CupertinoListTileChevron(),
                onTap: () => SettingsPlaceholders.showNotImplemented(
                  context,
                  title: '18+ 网址检测暂未实现',
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('高级搜索'),
                additionalInfo: _plannedInfo(),
                trailing: const CupertinoListTileChevron(),
                onTap: () => SettingsPlaceholders.showNotImplemented(
                  context,
                  title: '高级搜索设置暂未实现',
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('智能评估'),
                additionalInfo: _plannedInfo(),
                trailing: const CupertinoListTileChevron(),
                onTap: () => SettingsPlaceholders.showNotImplemented(
                  context,
                  title: '智能评估暂未实现',
                ),
              ),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('书籍设置'),
            children: [
              CupertinoListTile.notched(
                title: const Text('书架显示方式'),
                additionalInfo: Text(
                  _appSettings.bookshelfViewMode == BookshelfViewMode.grid
                      ? '网格'
                      : '列表',
                ),
                trailing: const CupertinoListTileChevron(),
                onTap: _pickBookshelfViewMode,
              ),
              CupertinoListTile.notched(
                title: const Text('新书默认排序'),
                additionalInfo:
                    Text(_bookshelfSortLabel(_appSettings.bookshelfSortMode)),
                trailing: const CupertinoListTileChevron(),
                onTap: _pickBookshelfSortMode,
              ),
              CupertinoListTile.notched(
                title: const Text('启动自动跳转之前阅读'),
                additionalInfo: _plannedInfo(),
                trailing: const CupertinoListTileChevron(),
                onTap: () => SettingsPlaceholders.showNotImplemented(
                  context,
                  title: '启动自动跳转之前阅读暂未实现',
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('新书默认开启净化替换'),
                additionalInfo: _plannedInfo(),
                trailing: const CupertinoListTileChevron(),
                onTap: () => SettingsPlaceholders.showNotImplemented(
                  context,
                  title: '新书默认开启净化替换暂未实现',
                ),
              ),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('下载与缓存'),
            children: [
              CupertinoListTile.notched(
                title: const Text('下载与缓存'),
                additionalInfo: const Text('仅 Wi‑Fi · 清理'),
                trailing: const CupertinoListTileChevron(),
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (context) => const StorageSettingsView(),
                  ),
                ),
              ),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('订阅设置'),
            children: [
              CupertinoListTile.notched(
                title: const Text('订阅设置'),
                additionalInfo: _plannedInfo(),
                trailing: const CupertinoListTileChevron(),
                onTap: () => SettingsPlaceholders.showNotImplemented(
                  context,
                  title: '订阅设置暂未实现',
                ),
              ),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('日志'),
            children: [
              CupertinoListTile.notched(
                title: const Text('日志文件'),
                additionalInfo: _plannedInfo(),
                trailing: const CupertinoListTileChevron(),
                onTap: () => SettingsPlaceholders.showNotImplemented(
                  context,
                  title: '日志文件暂未实现',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _bookshelfSortLabel(BookshelfSortMode mode) {
    switch (mode) {
      case BookshelfSortMode.recentRead:
        return '最近阅读';
      case BookshelfSortMode.recentAdded:
        return '最近加入';
      case BookshelfSortMode.title:
        return '书名';
      case BookshelfSortMode.author:
        return '作者';
    }
  }

  Widget _plannedInfo() {
    return const Text(
      SettingsUiTokens.plannedLabel,
      style: TextStyle(color: CupertinoColors.secondaryLabel),
    );
  }
}
