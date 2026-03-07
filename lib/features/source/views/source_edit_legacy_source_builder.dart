import 'package:flutter/cupertino.dart';

import '../models/book_source.dart';
import '../services/source_rule_complete.dart';
import 'source_edit_legacy_form_controllers.dart';

class SourceEditLegacySourceBuildInput {
  const SourceEditLegacySourceBuildInput({
    required this.base,
    required this.form,
    required this.autoComplete,
    required this.enabled,
    required this.enabledExplore,
    required this.enabledCookieJar,
    required this.bookSourceType,
  });

  final BookSource base;
  final SourceEditLegacyFormControllers form;
  final bool autoComplete;
  final bool enabled;
  final bool enabledExplore;
  final bool enabledCookieJar;
  final int bookSourceType;
}

class SourceEditLegacySourceBuilder {
  static BookSource build(SourceEditLegacySourceBuildInput input) {
    final searchBookList = _textOrNull(input.form.searchBookListCtrl);
    final exploreBookList = _textOrNull(input.form.exploreBookListCtrl);
    final infoInit = _textOrNull(input.form.infoInitCtrl);
    final tocChapterList = _textOrNull(input.form.tocChapterListCtrl);

    final searchRule = SearchRule(
      checkKeyWord: _textOrNull(input.form.searchCheckKeyWordCtrl),
      bookList: searchBookList,
      name: _ruleComplete(input, input.form.searchNameCtrl, preRule: searchBookList),
      author: _ruleComplete(input, input.form.searchAuthorCtrl, preRule: searchBookList),
      kind: _ruleComplete(input, input.form.searchKindCtrl, preRule: searchBookList),
      wordCount: _ruleComplete(input, input.form.searchWordCountCtrl, preRule: searchBookList),
      lastChapter: _ruleComplete(input, input.form.searchLastChapterCtrl, preRule: searchBookList),
      intro: _ruleComplete(input, input.form.searchIntroCtrl, preRule: searchBookList),
      coverUrl: _ruleComplete(input, input.form.searchCoverUrlCtrl, preRule: searchBookList, type: 3),
      bookUrl: _ruleComplete(input, input.form.searchBookUrlCtrl, preRule: searchBookList, type: 2),
    );

    final exploreRule = ExploreRule(
      bookList: exploreBookList,
      name: _ruleComplete(input, input.form.exploreNameCtrl, preRule: exploreBookList),
      author: _ruleComplete(input, input.form.exploreAuthorCtrl, preRule: exploreBookList),
      kind: _ruleComplete(input, input.form.exploreKindCtrl, preRule: exploreBookList),
      wordCount: _ruleComplete(input, input.form.exploreWordCountCtrl, preRule: exploreBookList),
      lastChapter: _ruleComplete(input, input.form.exploreLastChapterCtrl, preRule: exploreBookList),
      intro: _ruleComplete(input, input.form.exploreIntroCtrl, preRule: exploreBookList),
      coverUrl: _ruleComplete(input, input.form.exploreCoverUrlCtrl, preRule: exploreBookList, type: 3),
      bookUrl: _ruleComplete(input, input.form.exploreBookUrlCtrl, preRule: exploreBookList, type: 2),
    );

    final infoRule = BookInfoRule(
      init: infoInit,
      name: _ruleComplete(input, input.form.infoNameCtrl, preRule: infoInit),
      author: _ruleComplete(input, input.form.infoAuthorCtrl, preRule: infoInit),
      kind: _ruleComplete(input, input.form.infoKindCtrl, preRule: infoInit),
      wordCount: _ruleComplete(input, input.form.infoWordCountCtrl, preRule: infoInit),
      lastChapter: _ruleComplete(input, input.form.infoLastChapterCtrl, preRule: infoInit),
      intro: _ruleComplete(input, input.form.infoIntroCtrl, preRule: infoInit),
      coverUrl: _ruleComplete(input, input.form.infoCoverUrlCtrl, preRule: infoInit, type: 3),
      tocUrl: _ruleComplete(input, input.form.infoTocUrlCtrl, preRule: infoInit, type: 2),
      canReName: _textOrNull(input.form.infoCanRenameCtrl),
      downloadUrls: _ruleComplete(input, input.form.infoDownloadUrlsCtrl, preRule: infoInit),
    );

    final tocRule = TocRule(
      preUpdateJs: _textOrNull(input.form.tocPreUpdateJsCtrl),
      chapterList: tocChapterList,
      chapterName: _ruleComplete(input, input.form.tocChapterNameCtrl, preRule: tocChapterList),
      chapterUrl: _ruleComplete(input, input.form.tocChapterUrlCtrl, preRule: tocChapterList, type: 2),
      formatJs: _textOrNull(input.form.tocFormatJsCtrl),
      isVolume: _textOrNull(input.form.tocIsVolumeCtrl),
      updateTime: _textOrNull(input.form.tocUpdateTimeCtrl),
      isVip: _textOrNull(input.form.tocIsVipCtrl),
      isPay: _textOrNull(input.form.tocIsPayCtrl),
      nextTocUrl: _ruleComplete(input, input.form.tocNextTocUrlCtrl, preRule: tocChapterList, type: 2),
    );

    final contentRule = ContentRule(
      content: _ruleComplete(input, input.form.contentContentCtrl),
      title: _ruleComplete(input, input.form.contentTitleCtrl),
      nextContentUrl: _ruleComplete(input, input.form.contentNextContentUrlCtrl, type: 2),
      webJs: _textOrNull(input.form.contentWebJsCtrl),
      sourceRegex: _textOrNull(input.form.contentSourceRegexCtrl),
      replaceRegex: _textOrNull(input.form.contentReplaceRegexCtrl),
      imageStyle: _textOrNull(input.form.contentImageStyleCtrl),
      imageDecode: _textOrNull(input.form.contentImageDecodeCtrl),
      payAction: _textOrNull(input.form.contentPayActionCtrl),
    );

    return input.base.copyWith(
      bookSourceUrl: input.form.bookSourceUrlCtrl.text.trim(),
      bookSourceName: input.form.bookSourceNameCtrl.text,
      bookSourceGroup: _textOrNull(input.form.bookSourceGroupCtrl),
      bookSourceComment: _textOrNull(input.form.bookSourceCommentCtrl),
      loginUrl: _textOrNull(input.form.loginUrlCtrl),
      loginUi: _textOrNull(input.form.loginUiCtrl),
      loginCheckJs: _textOrNull(input.form.loginCheckJsCtrl),
      coverDecodeJs: _textOrNull(input.form.coverDecodeJsCtrl),
      bookUrlPattern: _textOrNull(input.form.bookUrlPatternCtrl),
      header: _textOrNull(input.form.headerCtrl),
      variableComment: _textOrNull(input.form.variableCommentCtrl),
      concurrentRate: _textOrNull(input.form.concurrentRateCtrl),
      jsLib: _textOrNull(input.form.jsLibCtrl),
      searchUrl: _textOrNull(input.form.searchUrlCtrl),
      exploreUrl: _textOrNull(input.form.exploreUrlCtrl),
      enabled: input.enabled,
      enabledExplore: input.enabledExplore,
      enabledCookieJar: input.enabledCookieJar,
      bookSourceType: input.bookSourceType,
      ruleSearch: searchRule,
      ruleExplore: exploreRule,
      ruleBookInfo: infoRule,
      ruleToc: tocRule,
      ruleContent: contentRule,
    );
  }

  static String? _textOrNull(TextEditingController controller) {
    final value = controller.text;
    return value.trim().isEmpty ? null : value;
  }

  static String? _ruleComplete(
    SourceEditLegacySourceBuildInput input,
    TextEditingController controller, {
    String? preRule,
    int type = 1,
  }) {
    final value = _textOrNull(controller);
    if (!input.autoComplete) return value;
    return SourceRuleComplete.autoComplete(
      value,
      preRule: preRule,
      type: type,
    );
  }
}
