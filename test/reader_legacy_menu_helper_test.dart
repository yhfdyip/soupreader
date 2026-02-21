import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/reader/services/reader_legacy_menu_helper.dart';

void main() {
  test('ReaderLegacyMenuHelper 在线阅读菜单顺序对齐 legado', () {
    final actions = ReaderLegacyMenuHelper.buildReadMenuActions(
      isOnline: true,
      isLocalTxt: false,
      isEpub: false,
      showWebDavProgressActions: true,
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
      showWebDavProgressActions: false,
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
      showWebDavProgressActions: false,
    );

    expect(actions, contains(ReaderLegacyReadMenuAction.delRubyTag));
    expect(actions, contains(ReaderLegacyReadMenuAction.delHTag));
  });

  test('ReaderLegacyMenuHelper 未配置 WebDav 时隐藏进度动作', () {
    final actions = ReaderLegacyMenuHelper.buildReadMenuActions(
      isOnline: true,
      isLocalTxt: false,
      isEpub: false,
      showWebDavProgressActions: false,
    );
    expect(actions, isNot(contains(ReaderLegacyReadMenuAction.getProgress)));
    expect(actions, isNot(contains(ReaderLegacyReadMenuAction.coverProgress)));
  });

  test('ReaderLegacyMenuHelper 目录页菜单顺序对齐 legado', () {
    final actions = ReaderLegacyMenuHelper.buildTocMenuActions(
      bookmarkTab: false,
      isLocalTxt: true,
    );
    expect(
      actions,
      <ReaderLegacyTocMenuAction>[
        ReaderLegacyTocMenuAction.tocRule,
        ReaderLegacyTocMenuAction.splitLongChapter,
        ReaderLegacyTocMenuAction.reverseToc,
        ReaderLegacyTocMenuAction.useReplace,
        ReaderLegacyTocMenuAction.loadWordCount,
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

  test('ReaderLegacyMenuHelper 换源分支顺序对齐 legado', () {
    final actions = ReaderLegacyMenuHelper.buildChangeSourceMenuActions();
    expect(
      actions,
      <ReaderLegacyChangeSourceMenuAction>[
        ReaderLegacyChangeSourceMenuAction.chapter,
        ReaderLegacyChangeSourceMenuAction.book,
      ],
    );
    expect(
      actions.map(ReaderLegacyMenuHelper.changeSourceMenuLabel).toList(),
      <String>['章节换源', '书籍换源'],
    );
  });

  test('ReaderLegacyMenuHelper 刷新分支顺序对齐 legado', () {
    final actions = ReaderLegacyMenuHelper.buildRefreshMenuActions();
    expect(
      actions,
      <ReaderLegacyRefreshMenuAction>[
        ReaderLegacyRefreshMenuAction.current,
        ReaderLegacyRefreshMenuAction.after,
        ReaderLegacyRefreshMenuAction.all,
      ],
    );
    expect(
      actions.map(ReaderLegacyMenuHelper.refreshMenuLabel).toList(),
      <String>['刷新当前章节', '刷新之后章节', '刷新全部章节'],
    );
  });
}
