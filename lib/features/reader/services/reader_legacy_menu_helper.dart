enum ReaderLegacyReadMenuAction {
  changeSource,
  refresh,
  download,
  tocRule,
  setCharset,
  addBookmark,
  editContent,
  pageAnim,
  getProgress,
  coverProgress,
  reverseContent,
  simulatedReading,
  enableReplace,
  sameTitleRemoved,
  reSegment,
  enableReview,
  delRubyTag,
  delHTag,
  imageStyle,
  updateToc,
  effectiveReplaces,
  log,
  help,
}

enum ReaderLegacyTocMenuAction {
  reverseToc,
  useReplace,
  loadWordCount,
  tocRule,
  splitLongChapter,
  exportBookmark,
  exportMarkdown,
  log,
}

enum ReaderLegacyChangeSourceMenuAction {
  chapter,
  book,
}

enum ReaderLegacyRefreshMenuAction {
  current,
  after,
  all,
}

class ReaderLegacyMenuHelper {
  const ReaderLegacyMenuHelper._();

  static List<ReaderLegacyReadMenuAction> buildReadMenuActions({
    required bool isOnline,
    required bool isLocalTxt,
    required bool isEpub,
    required bool showWebDavProgressActions,
    bool showReviewAction = false,
  }) {
    final actions = <ReaderLegacyReadMenuAction>[];
    if (isOnline) {
      actions.addAll(const <ReaderLegacyReadMenuAction>[
        ReaderLegacyReadMenuAction.changeSource,
        ReaderLegacyReadMenuAction.refresh,
        ReaderLegacyReadMenuAction.download,
      ]);
    }
    if (isLocalTxt) {
      actions.add(ReaderLegacyReadMenuAction.tocRule);
    }
    if (!isOnline) {
      actions.add(ReaderLegacyReadMenuAction.setCharset);
    }
    actions.addAll(<ReaderLegacyReadMenuAction>[
      ReaderLegacyReadMenuAction.addBookmark,
      ReaderLegacyReadMenuAction.editContent,
      ReaderLegacyReadMenuAction.pageAnim,
      if (showWebDavProgressActions) ReaderLegacyReadMenuAction.getProgress,
      if (showWebDavProgressActions) ReaderLegacyReadMenuAction.coverProgress,
      if (isOnline) ReaderLegacyReadMenuAction.reverseContent,
      ReaderLegacyReadMenuAction.simulatedReading,
      ReaderLegacyReadMenuAction.enableReplace,
      ReaderLegacyReadMenuAction.sameTitleRemoved,
      ReaderLegacyReadMenuAction.reSegment,
      if (showReviewAction) ReaderLegacyReadMenuAction.enableReview,
      if (isEpub) ReaderLegacyReadMenuAction.delRubyTag,
      if (isEpub) ReaderLegacyReadMenuAction.delHTag,
      ReaderLegacyReadMenuAction.imageStyle,
      ReaderLegacyReadMenuAction.updateToc,
      ReaderLegacyReadMenuAction.effectiveReplaces,
      ReaderLegacyReadMenuAction.log,
      ReaderLegacyReadMenuAction.help,
    ]);
    return actions;
  }

  static String readMenuLabel(ReaderLegacyReadMenuAction action) {
    switch (action) {
      case ReaderLegacyReadMenuAction.changeSource:
        return '换源';
      case ReaderLegacyReadMenuAction.refresh:
        return '刷新';
      case ReaderLegacyReadMenuAction.download:
        return '离线缓存';
      case ReaderLegacyReadMenuAction.tocRule:
        return 'TXT 目录规则';
      case ReaderLegacyReadMenuAction.setCharset:
        return '设置编码';
      case ReaderLegacyReadMenuAction.addBookmark:
        return '添加书签';
      case ReaderLegacyReadMenuAction.editContent:
        return '编辑正文';
      case ReaderLegacyReadMenuAction.pageAnim:
        return '翻页动画（本书）';
      case ReaderLegacyReadMenuAction.getProgress:
        return '获取进度';
      case ReaderLegacyReadMenuAction.coverProgress:
        return '覆盖云端进度';
      case ReaderLegacyReadMenuAction.reverseContent:
        return '反转内容';
      case ReaderLegacyReadMenuAction.simulatedReading:
        return '模拟追读';
      case ReaderLegacyReadMenuAction.enableReplace:
        return '替换净化';
      case ReaderLegacyReadMenuAction.sameTitleRemoved:
        return '移除重复标题';
      case ReaderLegacyReadMenuAction.reSegment:
        return '重新分段';
      case ReaderLegacyReadMenuAction.enableReview:
        return '段评';
      case ReaderLegacyReadMenuAction.delRubyTag:
        return '删除ruby标签';
      case ReaderLegacyReadMenuAction.delHTag:
        return '删除h标签';
      case ReaderLegacyReadMenuAction.imageStyle:
        return '图片样式';
      case ReaderLegacyReadMenuAction.updateToc:
        return '更新目录';
      case ReaderLegacyReadMenuAction.effectiveReplaces:
        return '起效的替换';
      case ReaderLegacyReadMenuAction.log:
        return '日志';
      case ReaderLegacyReadMenuAction.help:
        return '帮助';
    }
  }

  static List<ReaderLegacyTocMenuAction> buildTocMenuActions({
    required bool bookmarkTab,
    required bool isLocalTxt,
  }) {
    if (bookmarkTab) {
      return const <ReaderLegacyTocMenuAction>[
        ReaderLegacyTocMenuAction.exportBookmark,
        ReaderLegacyTocMenuAction.exportMarkdown,
        ReaderLegacyTocMenuAction.log,
      ];
    }
    return <ReaderLegacyTocMenuAction>[
      if (isLocalTxt) ReaderLegacyTocMenuAction.tocRule,
      if (isLocalTxt) ReaderLegacyTocMenuAction.splitLongChapter,
      ReaderLegacyTocMenuAction.reverseToc,
      ReaderLegacyTocMenuAction.useReplace,
      ReaderLegacyTocMenuAction.loadWordCount,
      ReaderLegacyTocMenuAction.log,
    ];
  }

  static String tocMenuLabel(ReaderLegacyTocMenuAction action) {
    switch (action) {
      case ReaderLegacyTocMenuAction.reverseToc:
        return '倒序';
      case ReaderLegacyTocMenuAction.useReplace:
        return '使用替换规则';
      case ReaderLegacyTocMenuAction.loadWordCount:
        return '加载字数';
      case ReaderLegacyTocMenuAction.tocRule:
        return 'TXT 目录规则';
      case ReaderLegacyTocMenuAction.splitLongChapter:
        return '分割长章节';
      case ReaderLegacyTocMenuAction.exportBookmark:
        return '导出书签';
      case ReaderLegacyTocMenuAction.exportMarkdown:
        return '导出 Markdown';
      case ReaderLegacyTocMenuAction.log:
        return '日志';
    }
  }

  static List<ReaderLegacyChangeSourceMenuAction>
      buildChangeSourceMenuActions() {
    return const <ReaderLegacyChangeSourceMenuAction>[
      ReaderLegacyChangeSourceMenuAction.chapter,
      ReaderLegacyChangeSourceMenuAction.book,
    ];
  }

  static String changeSourceMenuLabel(
      ReaderLegacyChangeSourceMenuAction action) {
    switch (action) {
      case ReaderLegacyChangeSourceMenuAction.chapter:
        return '单章换源';
      case ReaderLegacyChangeSourceMenuAction.book:
        return '整书换源';
    }
  }

  static List<ReaderLegacyRefreshMenuAction> buildRefreshMenuActions() {
    return const <ReaderLegacyRefreshMenuAction>[
      ReaderLegacyRefreshMenuAction.current,
      ReaderLegacyRefreshMenuAction.after,
      ReaderLegacyRefreshMenuAction.all,
    ];
  }

  static ReaderLegacyRefreshMenuAction defaultRefreshAction() {
    return ReaderLegacyRefreshMenuAction.current;
  }

  static String refreshMenuLabel(ReaderLegacyRefreshMenuAction action) {
    switch (action) {
      case ReaderLegacyRefreshMenuAction.current:
        return '刷新当前章节';
      case ReaderLegacyRefreshMenuAction.after:
        return '刷新之后章节';
      case ReaderLegacyRefreshMenuAction.all:
        return '刷新全部章节';
    }
  }
}
