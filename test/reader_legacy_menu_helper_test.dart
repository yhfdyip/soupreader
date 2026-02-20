import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/reader/services/reader_legacy_menu_helper.dart';

void main() {
  test('ReaderLegacyMenuHelper 在线阅读菜单顺序对齐 legado', () {
    final actions = ReaderLegacyMenuHelper.buildReadMenuActions(
      isOnline: true,
      isLocalTxt: false,
      isEpub: false,
    );

    expect(
      actions,
      <ReaderLegacyReadMenuAction>[
        ReaderLegacyReadMenuAction.changeSource,
        ReaderLegacyReadMenuAction.refresh,
        ReaderLegacyReadMenuAction.download,
        ReaderLegacyReadMenuAction.addBookmark,
        ReaderLegacyReadMenuAction.editContent,
        ReaderLegacyReadMenuAction.pageAnim,
        ReaderLegacyReadMenuAction.getProgress,
        ReaderLegacyReadMenuAction.coverProgress,
        ReaderLegacyReadMenuAction.reverseContent,
        ReaderLegacyReadMenuAction.simulatedReading,
        ReaderLegacyReadMenuAction.enableReplace,
        ReaderLegacyReadMenuAction.sameTitleRemoved,
        ReaderLegacyReadMenuAction.reSegment,
        ReaderLegacyReadMenuAction.imageStyle,
        ReaderLegacyReadMenuAction.updateToc,
        ReaderLegacyReadMenuAction.effectiveReplaces,
        ReaderLegacyReadMenuAction.log,
        ReaderLegacyReadMenuAction.help,
      ],
    );
  });

  test('ReaderLegacyMenuHelper 本地 txt 菜单包含文本组动作', () {
    final actions = ReaderLegacyMenuHelper.buildReadMenuActions(
      isOnline: false,
      isLocalTxt: true,
      isEpub: false,
    );

    expect(actions.first, ReaderLegacyReadMenuAction.tocRule);
    expect(actions, contains(ReaderLegacyReadMenuAction.setCharset));
    expect(actions, isNot(contains(ReaderLegacyReadMenuAction.changeSource)));
    expect(actions, isNot(contains(ReaderLegacyReadMenuAction.reverseContent)));
  });

  test('ReaderLegacyMenuHelper epub 菜单包含标签清理动作', () {
    final actions = ReaderLegacyMenuHelper.buildReadMenuActions(
      isOnline: false,
      isLocalTxt: false,
      isEpub: true,
    );

    expect(actions, contains(ReaderLegacyReadMenuAction.delRubyTag));
    expect(actions, contains(ReaderLegacyReadMenuAction.delHTag));
  });

  test('ReaderLegacyMenuHelper 目录页菜单顺序对齐 legado', () {
    final actions = ReaderLegacyMenuHelper.buildTocMenuActions(
      bookmarkTab: false,
      isLocalTxt: true,
    );
    expect(
      actions,
      <ReaderLegacyTocMenuAction>[
        ReaderLegacyTocMenuAction.reverseToc,
        ReaderLegacyTocMenuAction.useReplace,
        ReaderLegacyTocMenuAction.loadWordCount,
        ReaderLegacyTocMenuAction.tocRule,
        ReaderLegacyTocMenuAction.splitLongChapter,
        ReaderLegacyTocMenuAction.log,
      ],
    );
  });

  test('ReaderLegacyMenuHelper 书签页菜单顺序对齐 legado', () {
    final actions = ReaderLegacyMenuHelper.buildTocMenuActions(
      bookmarkTab: true,
      isLocalTxt: true,
    );
    expect(
      actions,
      <ReaderLegacyTocMenuAction>[
        ReaderLegacyTocMenuAction.exportBookmark,
        ReaderLegacyTocMenuAction.exportMarkdown,
        ReaderLegacyTocMenuAction.log,
      ],
    );
  });
}
