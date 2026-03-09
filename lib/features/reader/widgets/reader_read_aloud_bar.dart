import 'package:flutter/cupertino.dart';

import '../../../app/theme/design_tokens.dart';
import '../services/read_aloud_service.dart';

/// 朗读控制浮层，朗读进行时叠加显示在阅读页顶部。
///
/// 包含：上一段 / 暂停·继续 / 下一段 / 语速步进 / 停止。
class ReaderReadAloudBar extends StatelessWidget {
  const ReaderReadAloudBar({
    super.key,
    required this.snapshot,
    required this.speechRate,
    required this.onPreviousParagraph,
    required this.onTogglePauseResume,
    required this.onNextParagraph,
    required this.onStop,
    required this.onSpeechRateChanged,
    this.onPreviousChapter,
    this.onNextChapter,
    this.onSetTimer,
    this.onOpenChapterList,
    this.bgColor,
    this.fgColor,
    this.accentColor,
  });

  final ReadAloudStatusSnapshot snapshot;
  final int speechRate;
  final VoidCallback onPreviousParagraph;
  final VoidCallback onTogglePauseResume;
  final VoidCallback onNextParagraph;
  final VoidCallback onStop;
  final ValueChanged<int> onSpeechRateChanged;
  final VoidCallback? onPreviousChapter;
  final VoidCallback? onNextChapter;
  final VoidCallback? onSetTimer;
  final VoidCallback? onOpenChapterList;
  final Color? bgColor;
  final Color? fgColor;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final bg = bgColor ?? CupertinoColors.systemBackground.resolveFrom(context);
    final fg = fgColor ?? CupertinoColors.label.resolveFrom(context);
    final accent =
        accentColor ?? CupertinoColors.activeBlue.resolveFrom(context);
    final isPaused = snapshot.isPaused;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(AppDesignTokens.radiusCard.toDouble()),
          child: ColoredBox(
            color: bg.withValues(alpha: 0.92),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  if (onOpenChapterList != null)
                    _BarIconButton(
                      icon: CupertinoIcons.list_bullet,
                      color: fg.withValues(alpha: 0.8),
                      size: 17,
                      onTap: onOpenChapterList!,
                      semanticLabel: '目录',
                    ),
                  if (onPreviousChapter != null)
                    _BarIconButton(
                      icon: CupertinoIcons.chevron_left_2,
                      color: fg.withValues(alpha: 0.7),
                      size: 18,
                      onTap: onPreviousChapter!,
                      semanticLabel: '上一章',
                    ),
                  _BarIconButton(
                    icon: CupertinoIcons.backward_end_fill,
                    color: fg,
                    onTap: onPreviousParagraph,
                    semanticLabel: '上一段',
                  ),
                  _BarIconButton(
                    icon: isPaused
                        ? CupertinoIcons.play_fill
                        : CupertinoIcons.pause_fill,
                    color: accent,
                    size: 22,
                    onTap: onTogglePauseResume,
                    semanticLabel: isPaused ? '继续朗读' : '暂停朗读',
                  ),
                  _BarIconButton(
                    icon: CupertinoIcons.forward_end_fill,
                    color: fg,
                    onTap: onNextParagraph,
                    semanticLabel: '下一段',
                  ),
                  if (onNextChapter != null)
                    _BarIconButton(
                      icon: CupertinoIcons.chevron_right_2,
                      color: fg.withValues(alpha: 0.7),
                      size: 18,
                      onTap: onNextChapter!,
                      semanticLabel: '下一章',
                    ),
                  const Spacer(),
                  _SpeechRateStepper(
                    rate: speechRate,
                    color: fg,
                    accentColor: accent,
                    onChanged: onSpeechRateChanged,
                  ),
                  const SizedBox(width: 4),
                  _TimerButton(
                    snapshot: snapshot,
                    color: fg,
                    accentColor: accent,
                    onTap: onSetTimer,
                  ),
                  const SizedBox(width: 4),
                  _BarIconButton(
                    icon: CupertinoIcons.stop_fill,
                    color: CupertinoColors.destructiveRed.resolveFrom(context),
                    onTap: onStop,
                    semanticLabel: '停止朗读',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BarIconButton extends StatelessWidget {
  const _BarIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.semanticLabel,
    this.size = 18,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String semanticLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        onPressed: onTap,
        child: Icon(icon, size: size, color: color),
      ),
    );
  }
}

class _SpeechRateStepper extends StatelessWidget {
  const _SpeechRateStepper({
    required this.rate,
    required this.color,
    required this.accentColor,
    required this.onChanged,
  });

  final int rate;
  final Color color;
  final Color accentColor;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          label: 'A',
          small: true,
          color: rate <= 1
              ? CupertinoColors.tertiaryLabel.resolveFrom(context)
              : color,
          onTap: rate <= 1 ? null : () => onChanged((rate - 1).clamp(1, 20)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            '$rate',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: accentColor,
            ),
          ),
        ),
        _StepButton(
          label: 'A',
          small: false,
          color: rate >= 20
              ? CupertinoColors.tertiaryLabel.resolveFrom(context)
              : color,
          onTap: rate >= 20 ? null : () => onChanged((rate + 1).clamp(1, 20)),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.label,
    required this.small,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool small;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: small ? 12 : 17,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// 定时停止按钮，对标 legado ReadAloudDialog seekTimer + tvTimer。
class _TimerButton extends StatelessWidget {
  const _TimerButton({
    required this.snapshot,
    required this.color,
    required this.accentColor,
    required this.onTap,
  });

  final ReadAloudStatusSnapshot snapshot;
  final Color color;
  final Color accentColor;
  final VoidCallback? onTap;

  String get _label {
    if (!snapshot.hasSleepTimer) return '定时';
    final remain = snapshot.sleepTimerRemainSeconds;
    final m = remain ~/ 60;
    final s = remain % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final active = snapshot.hasSleepTimer;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Text(
        _label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          color: active ? accentColor : color,
        ),
      ),
    );
  }
}
