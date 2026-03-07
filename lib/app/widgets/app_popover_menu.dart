import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../theme/design_tokens.dart';
import '../theme/ui_tokens.dart';
import 'app_squircle_surface.dart';

part 'app_popover_menu_parts.dart';

const double _screenEdgePadding = 10.0;
const double _popoverVerticalGap = 8.0;

class AppPopoverMenuItem<T> {
  final T value;
  final IconData icon;
  final String label;
  final bool enabled;
  final bool isDestructiveAction;

  const AppPopoverMenuItem({
    required this.value,
    required this.icon,
    required this.label,
    this.enabled = true,
    this.isDestructiveAction = false,
  });
}

class _PopoverAnchor {
  final Rect rect;
  final Size overlaySize;
  final EdgeInsets safePadding;

  const _PopoverAnchor({
    required this.rect,
    required this.overlaySize,
    required this.safePadding,
  });
}

class _PopoverPosition {
  final double left;
  final double top;

  const _PopoverPosition({
    required this.left,
    required this.top,
  });
}

class _PopoverLayout {
  final _PopoverPosition position;
  final double maxHeight;

  const _PopoverLayout({
    required this.position,
    required this.maxHeight,
  });
}

Future<T?> showAppPopoverMenu<T>({
  required BuildContext context,
  required GlobalKey anchorKey,
  required List<AppPopoverMenuItem<T>> items,
  double width = 196,
  double itemHeight = kMinInteractiveDimensionCupertino,
  double? radius,
  double verticalPadding = 6,
  double backdropBlurSigma = AppDesignTokens.glassBlurSigma,
}) {
  assert(items.isNotEmpty, 'items should not be empty');
  final anchor = _resolveAnchor(context: context, anchorKey: anchorKey);
  final estimatedHeight = _estimateHeight(
    itemCount: items.length,
    itemHeight: itemHeight,
    verticalPadding: verticalPadding,
  );
  final layout = _resolveLayout(
    anchor: anchor,
    width: width,
    estimatedHeight: estimatedHeight,
  );
  final barrierLabel =
      CupertinoLocalizations.of(context).modalBarrierDismissLabel;
  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: barrierLabel,
    // 在 iOS 上更接近原生 Popover：背景略模糊 + 轻微遮罩。
    barrierColor: CupertinoColors.transparent,
    pageBuilder: (popupContext, __, ___) {
      final uiTokens = AppUiTokens.resolve(popupContext);
      final resolvedRadius = radius ?? uiTokens.radii.popover;
      final isDark =
          CupertinoTheme.of(popupContext).brightness == Brightness.dark;
      final backdropMask = _resolveBackdropMask(isDark);
      final labelColor = uiTokens.colors.label;
      final iconColor = uiTokens.colors.secondaryLabel;
      final destructiveColor = uiTokens.colors.destructive;
      final bg = uiTokens.colors.surfaceBackground.withValues(alpha: 0.92);
      final borderColor = uiTokens.colors.separator.withValues(alpha: 0.78);
      final separatorColor = uiTokens.colors.separator.withValues(alpha: 0.54);

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(popupContext).pop(),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(
                    sigmaX: backdropBlurSigma,
                    sigmaY: backdropBlurSigma,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: backdropMask),
                  ),
                ),
              ),
            ),
            Positioned(
              left: layout.position.left,
              top: layout.position.top,
              width: width,
              child: _PopoverSurface(
                backgroundColor: bg,
                borderColor: borderColor,
                radius: resolvedRadius,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: layout.maxHeight),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: verticalPadding),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _PopoverMenuRow(
                          height: itemHeight,
                          icon: item.icon,
                          label: item.label,
                          enabled: item.enabled,
                          showDivider: index < items.length - 1,
                          dividerColor: separatorColor,
                          iconColor: item.isDestructiveAction
                              ? destructiveColor
                              : iconColor,
                          textColor: item.isDestructiveAction
                              ? destructiveColor
                              : labelColor,
                          onTap: item.enabled
                              ? () => _dismissWithFeedback(
                                    popupContext,
                                    value: item.value,
                                  )
                              : null,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Color _resolveBackdropMask(bool isDark) {
  return isDark
      ? CupertinoColors.black.withValues(alpha: 0.2)
      : CupertinoColors.black.withValues(alpha: 0.06);
}

void _dismissWithFeedback<T>(BuildContext context, {required T value}) {
  HapticFeedback.selectionClick();
  Navigator.of(context).pop(value);
}

_PopoverAnchor _resolveAnchor({
  required BuildContext context,
  required GlobalKey anchorKey,
}) {
  final anchorContext = anchorKey.currentContext;
  if (anchorContext == null) {
    throw FlutterError('showAppPopoverMenu: anchorKey has no currentContext');
  }
  final renderBox = _findAnchorRenderBox(anchorContext);
  if (renderBox == null) {
    throw FlutterError('showAppPopoverMenu: anchorKey renderBox not ready');
  }
  final overlayObject =
      Overlay.of(context, rootOverlay: true).context.findRenderObject();
  if (overlayObject is! RenderBox || !overlayObject.hasSize) {
    throw FlutterError('showAppPopoverMenu: root overlay renderBox not ready');
  }
  final anchorOffset = renderBox.localToGlobal(Offset.zero);
  return _PopoverAnchor(
    rect: anchorOffset & renderBox.size,
    overlaySize: overlayObject.size,
    safePadding: MediaQuery.paddingOf(context),
  );
}

RenderBox? _findAnchorRenderBox(BuildContext anchorContext) {
  final directObject = anchorContext.findRenderObject();
  if (directObject is RenderBox && directObject.hasSize) {
    return directObject;
  }
  if (anchorContext is! Element) return null;
  return _findRenderBoxInSubtree(anchorContext);
}

RenderBox? _findRenderBoxInSubtree(Element root) {
  RenderBox? resolved;
  void visit(Element element) {
    if (resolved != null) return;
    final renderObject = element.renderObject;
    if (renderObject is RenderBox && renderObject.hasSize) {
      resolved = renderObject;
      return;
    }
    element.visitChildElements(visit);
  }

  root.visitChildElements(visit);
  return resolved;
}

double _estimateHeight({
  required int itemCount,
  required double itemHeight,
  required double verticalPadding,
}) {
  return verticalPadding * 2 + itemHeight * math.max(1, itemCount);
}

_PopoverLayout _resolveLayout({
  required _PopoverAnchor anchor,
  required double width,
  required double estimatedHeight,
}) {
  final overlaySize = anchor.overlaySize;
  final maxLeft = overlaySize.width - width - _screenEdgePadding;
  final desiredLeft = anchor.rect.right - width;
  final left = desiredLeft.clamp(_screenEdgePadding, maxLeft).toDouble();

  final safeTop = math.max(anchor.safePadding.top, _screenEdgePadding);
  final safeBottom = math.max(anchor.safePadding.bottom, _screenEdgePadding);
  final belowTop = anchor.rect.bottom + _popoverVerticalGap;
  final availableBelow = overlaySize.height - safeBottom - belowTop;
  final availableAbove = anchor.rect.top - safeTop - _popoverVerticalGap;
  final canFitBelow = estimatedHeight <= availableBelow;
  final canFitAbove = estimatedHeight <= availableAbove;
  final showBelow =
      canFitBelow || (!canFitAbove && availableBelow >= availableAbove);

  final maxHeight =
      math.max(0, showBelow ? availableBelow : availableAbove).toDouble();
  final resolvedHeight = math.min(estimatedHeight, maxHeight);
  final rawTop = showBelow
      ? belowTop
      : anchor.rect.top - resolvedHeight - _popoverVerticalGap;
  final maxTop = overlaySize.height - safeBottom - resolvedHeight;
  final top = rawTop.clamp(safeTop, math.max(safeTop, maxTop)).toDouble();

  return _PopoverLayout(
    position: _PopoverPosition(left: left, top: top),
    maxHeight: maxHeight,
  );
}
