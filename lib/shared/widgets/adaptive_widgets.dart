import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 平台自适应开关
class AdaptiveSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;

  const AdaptiveSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return CupertinoSwitch(
        value: value,
        onChanged: onChanged,
        activeColor: activeColor ?? Theme.of(context).primaryColor,
      );
    }
    return Switch(
      value: value,
      onChanged: onChanged,
      activeColor: activeColor ?? Theme.of(context).primaryColor,
    );
  }
}

/// 平台自适应按钮
class AdaptiveButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? color;

  const AdaptiveButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return CupertinoButton(
        onPressed: onPressed,
        color: color ?? Theme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        minSize: 0,
        child: child,
      );
    }
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? Theme.of(context).primaryColor,
      ),
      child: child,
    );
  }
}

/// 平台自适应设置分组容器
class AdaptiveSettingsGroup extends StatelessWidget {
  final String? header;
  final List<Widget> children;
  final String? footer;

  const AdaptiveSettingsGroup({
    super.key,
    this.header,
    required this.children,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // iOS 风格分组背景色
    final groupColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final dividerColor =
        isDark ? const Color(0xFF38383A) : const Color(0xFFC6C6C8);
    final platform = Theme.of(context).platform;
    final isIOS = platform == TargetPlatform.iOS;

    if (!isIOS) {
      // Android 风格简单的列表
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                header!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ...children,
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child:
                  Text(footer!, style: Theme.of(context).textTheme.bodySmall),
            ),
          const Divider(),
        ],
      );
    }

    // iOS 风格圆角分组
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 16, 32, 8), // iOS 头部缩进稍大
            child: Text(
              header!.toUpperCase(),
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF8E8E93),
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: groupColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 56), // 图标宽40+间距16
                    child: Divider(
                      height: 0.5,
                      thickness: 0.5,
                      color: dividerColor,
                    ),
                  ),
              ],
            ],
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 8, 32, 16),
            child: Text(
              footer!,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF8E8E93),
              ),
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// 平台自适应设置项 Tile
class AdaptiveSettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final Color? iconBgColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;

  const AdaptiveSettingsTile({
    super.key,
    required this.icon,
    this.iconColor,
    this.iconBgColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent, // 让点击水波纹(Android)或高亮生效
      child: InkWell(
        onTap: onTap,
        splashColor:
            isIOS ? Colors.transparent : null, // iOS 无水波纹，应该用 highlight
        highlightColor:
            isIOS ? (isDark ? Colors.grey[800] : Colors.grey[200]) : null,
        borderRadius: isIOS ? BorderRadius.circular(10) : null, // 匹配分组圆角
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // 图标容器
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBgColor ?? Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(8), // iOS 风格圆角矩形图标
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: iconColor ?? Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // 标题
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isIOS
                              ? const Color(0xFF8E8E93)
                              : Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // 尾部
              if (trailing != null) ...[
                trailing!, // Switch 等组件
                const SizedBox(width: 8),
              ],

              // 箭头
              if (showChevron && onTap != null && trailing == null)
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: const Color(0xFFC6C6C8),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 平台自适应弹窗辅助函数
Future<T?> showAdaptiveDialog<T>({
  required BuildContext context,
  required String title,
  String? content,
  List<Widget>? actions,
}) {
  if (Platform.isIOS) {
    return showCupertinoDialog<T>(
      context: context,
      barrierDismissible: true,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: content != null ? Text(content) : null,
        actions: actions ??
            [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              )
            ],
      ),
    );
  }
  return showDialog<T>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: content != null ? Text(content) : null,
      actions: actions ??
          [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
    ),
  );
}
