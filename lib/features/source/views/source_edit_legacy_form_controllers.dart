import 'package:flutter/cupertino.dart';

import '../models/book_source.dart';

class SourceEditLegacyFormControllers {
  late final TextEditingController bookSourceUrlCtrl,
      bookSourceNameCtrl,
      bookSourceGroupCtrl,
      bookSourceCommentCtrl,
      loginUrlCtrl,
      loginUiCtrl,
      loginCheckJsCtrl,
      coverDecodeJsCtrl,
      bookUrlPatternCtrl,
      headerCtrl,
      variableCommentCtrl,
      concurrentRateCtrl,
      jsLibCtrl;
  late final TextEditingController searchUrlCtrl,
      searchCheckKeyWordCtrl,
      searchBookListCtrl,
      searchNameCtrl,
      searchAuthorCtrl,
      searchKindCtrl,
      searchWordCountCtrl,
      searchLastChapterCtrl,
      searchIntroCtrl,
      searchCoverUrlCtrl,
      searchBookUrlCtrl;
  late final TextEditingController exploreUrlCtrl,
      exploreBookListCtrl,
      exploreNameCtrl,
      exploreAuthorCtrl,
      exploreKindCtrl,
      exploreWordCountCtrl,
      exploreLastChapterCtrl,
      exploreIntroCtrl,
      exploreCoverUrlCtrl,
      exploreBookUrlCtrl;
  late final TextEditingController infoInitCtrl,
      infoNameCtrl,
      infoAuthorCtrl,
      infoKindCtrl,
      infoWordCountCtrl,
      infoLastChapterCtrl,
      infoIntroCtrl,
      infoCoverUrlCtrl,
      infoTocUrlCtrl,
      infoCanRenameCtrl,
      infoDownloadUrlsCtrl;
  late final TextEditingController tocPreUpdateJsCtrl,
      tocChapterListCtrl,
      tocChapterNameCtrl,
      tocChapterUrlCtrl,
      tocFormatJsCtrl,
      tocIsVolumeCtrl,
      tocUpdateTimeCtrl,
      tocIsVipCtrl,
      tocIsPayCtrl,
      tocNextTocUrlCtrl;
  late final TextEditingController contentContentCtrl,
      contentTitleCtrl,
      contentNextContentUrlCtrl,
      contentWebJsCtrl,
      contentSourceRegexCtrl,
      contentReplaceRegexCtrl,
      contentImageStyleCtrl,
      contentImageDecodeCtrl,
      contentPayActionCtrl;

  SourceEditLegacyFormControllers(BookSource source) {
    _initBase(source);
    _initSearch(source);
    _initExplore(source);
    _initInfo(source);
    _initToc(source);
    _initContent(source);
  }

  void _initBase(BookSource source) {
    bookSourceUrlCtrl = TextEditingController(text: source.bookSourceUrl);
    bookSourceNameCtrl = TextEditingController(text: source.bookSourceName);
    bookSourceGroupCtrl = TextEditingController(text: source.bookSourceGroup);
    bookSourceCommentCtrl =
        TextEditingController(text: source.bookSourceComment);
    loginUrlCtrl = TextEditingController(text: source.loginUrl);
    loginUiCtrl = TextEditingController(text: source.loginUi);
    loginCheckJsCtrl = TextEditingController(text: source.loginCheckJs);
    coverDecodeJsCtrl = TextEditingController(text: source.coverDecodeJs);
    bookUrlPatternCtrl = TextEditingController(text: source.bookUrlPattern);
    headerCtrl = TextEditingController(text: source.header);
    variableCommentCtrl = TextEditingController(text: source.variableComment);
    concurrentRateCtrl = TextEditingController(text: source.concurrentRate);
    jsLibCtrl = TextEditingController(text: source.jsLib);
  }

  void _initSearch(BookSource source) {
    searchUrlCtrl = TextEditingController(text: source.searchUrl);
    searchCheckKeyWordCtrl =
        TextEditingController(text: source.ruleSearch?.checkKeyWord);
    searchBookListCtrl = TextEditingController(text: source.ruleSearch?.bookList);
    searchNameCtrl = TextEditingController(text: source.ruleSearch?.name);
    searchAuthorCtrl = TextEditingController(text: source.ruleSearch?.author);
    searchKindCtrl = TextEditingController(text: source.ruleSearch?.kind);
    searchWordCountCtrl =
        TextEditingController(text: source.ruleSearch?.wordCount);
    searchLastChapterCtrl =
        TextEditingController(text: source.ruleSearch?.lastChapter);
    searchIntroCtrl = TextEditingController(text: source.ruleSearch?.intro);
    searchCoverUrlCtrl = TextEditingController(text: source.ruleSearch?.coverUrl);
    searchBookUrlCtrl = TextEditingController(text: source.ruleSearch?.bookUrl);
  }

  void _initExplore(BookSource source) {
    exploreUrlCtrl = TextEditingController(text: source.exploreUrl);
    exploreBookListCtrl =
        TextEditingController(text: source.ruleExplore?.bookList);
    exploreNameCtrl = TextEditingController(text: source.ruleExplore?.name);
    exploreAuthorCtrl = TextEditingController(text: source.ruleExplore?.author);
    exploreKindCtrl = TextEditingController(text: source.ruleExplore?.kind);
    exploreWordCountCtrl =
        TextEditingController(text: source.ruleExplore?.wordCount);
    exploreLastChapterCtrl =
        TextEditingController(text: source.ruleExplore?.lastChapter);
    exploreIntroCtrl = TextEditingController(text: source.ruleExplore?.intro);
    exploreCoverUrlCtrl =
        TextEditingController(text: source.ruleExplore?.coverUrl);
    exploreBookUrlCtrl = TextEditingController(text: source.ruleExplore?.bookUrl);
  }

  void _initInfo(BookSource source) {
    infoInitCtrl = TextEditingController(text: source.ruleBookInfo?.init);
    infoNameCtrl = TextEditingController(text: source.ruleBookInfo?.name);
    infoAuthorCtrl = TextEditingController(text: source.ruleBookInfo?.author);
    infoKindCtrl = TextEditingController(text: source.ruleBookInfo?.kind);
    infoWordCountCtrl =
        TextEditingController(text: source.ruleBookInfo?.wordCount);
    infoLastChapterCtrl =
        TextEditingController(text: source.ruleBookInfo?.lastChapter);
    infoIntroCtrl = TextEditingController(text: source.ruleBookInfo?.intro);
    infoCoverUrlCtrl =
        TextEditingController(text: source.ruleBookInfo?.coverUrl);
    infoTocUrlCtrl = TextEditingController(text: source.ruleBookInfo?.tocUrl);
    infoCanRenameCtrl =
        TextEditingController(text: source.ruleBookInfo?.canReName);
    infoDownloadUrlsCtrl =
        TextEditingController(text: source.ruleBookInfo?.downloadUrls);
  }

  void _initToc(BookSource source) {
    tocPreUpdateJsCtrl = TextEditingController(text: source.ruleToc?.preUpdateJs);
    tocChapterListCtrl = TextEditingController(text: source.ruleToc?.chapterList);
    tocChapterNameCtrl = TextEditingController(text: source.ruleToc?.chapterName);
    tocChapterUrlCtrl = TextEditingController(text: source.ruleToc?.chapterUrl);
    tocFormatJsCtrl = TextEditingController(text: source.ruleToc?.formatJs);
    tocIsVolumeCtrl = TextEditingController(text: source.ruleToc?.isVolume);
    tocUpdateTimeCtrl = TextEditingController(text: source.ruleToc?.updateTime);
    tocIsVipCtrl = TextEditingController(text: source.ruleToc?.isVip);
    tocIsPayCtrl = TextEditingController(text: source.ruleToc?.isPay);
    tocNextTocUrlCtrl = TextEditingController(text: source.ruleToc?.nextTocUrl);
  }

  void _initContent(BookSource source) {
    contentContentCtrl = TextEditingController(text: source.ruleContent?.content);
    contentTitleCtrl = TextEditingController(text: source.ruleContent?.title);
    contentNextContentUrlCtrl =
        TextEditingController(text: source.ruleContent?.nextContentUrl);
    contentWebJsCtrl = TextEditingController(text: source.ruleContent?.webJs);
    contentSourceRegexCtrl =
        TextEditingController(text: source.ruleContent?.sourceRegex);
    contentReplaceRegexCtrl =
        TextEditingController(text: source.ruleContent?.replaceRegex);
    contentImageStyleCtrl =
        TextEditingController(text: source.ruleContent?.imageStyle);
    contentImageDecodeCtrl =
        TextEditingController(text: source.ruleContent?.imageDecode);
    contentPayActionCtrl =
        TextEditingController(text: source.ruleContent?.payAction);
  }

  void loadSource(BookSource source) {
    _loadBase(source);
    _loadSearch(source);
    _loadExplore(source);
    _loadInfo(source);
    _loadToc(source);
    _loadContent(source);
  }

  void _loadBase(BookSource source) {
    bookSourceUrlCtrl.text = source.bookSourceUrl;
    bookSourceNameCtrl.text = source.bookSourceName;
    bookSourceGroupCtrl.text = source.bookSourceGroup ?? '';
    bookSourceCommentCtrl.text = source.bookSourceComment ?? '';
    loginUrlCtrl.text = source.loginUrl ?? '';
    loginUiCtrl.text = source.loginUi ?? '';
    loginCheckJsCtrl.text = source.loginCheckJs ?? '';
    coverDecodeJsCtrl.text = source.coverDecodeJs ?? '';
    bookUrlPatternCtrl.text = source.bookUrlPattern ?? '';
    headerCtrl.text = source.header ?? '';
    variableCommentCtrl.text = source.variableComment ?? '';
    concurrentRateCtrl.text = source.concurrentRate ?? '';
    jsLibCtrl.text = source.jsLib ?? '';
  }

  void _loadSearch(BookSource source) {
    searchUrlCtrl.text = source.searchUrl ?? '';
    searchCheckKeyWordCtrl.text = source.ruleSearch?.checkKeyWord ?? '';
    searchBookListCtrl.text = source.ruleSearch?.bookList ?? '';
    searchNameCtrl.text = source.ruleSearch?.name ?? '';
    searchAuthorCtrl.text = source.ruleSearch?.author ?? '';
    searchKindCtrl.text = source.ruleSearch?.kind ?? '';
    searchWordCountCtrl.text = source.ruleSearch?.wordCount ?? '';
    searchLastChapterCtrl.text = source.ruleSearch?.lastChapter ?? '';
    searchIntroCtrl.text = source.ruleSearch?.intro ?? '';
    searchCoverUrlCtrl.text = source.ruleSearch?.coverUrl ?? '';
    searchBookUrlCtrl.text = source.ruleSearch?.bookUrl ?? '';
  }

  void _loadExplore(BookSource source) {
    exploreUrlCtrl.text = source.exploreUrl ?? '';
    exploreBookListCtrl.text = source.ruleExplore?.bookList ?? '';
    exploreNameCtrl.text = source.ruleExplore?.name ?? '';
    exploreAuthorCtrl.text = source.ruleExplore?.author ?? '';
    exploreKindCtrl.text = source.ruleExplore?.kind ?? '';
    exploreWordCountCtrl.text = source.ruleExplore?.wordCount ?? '';
    exploreLastChapterCtrl.text = source.ruleExplore?.lastChapter ?? '';
    exploreIntroCtrl.text = source.ruleExplore?.intro ?? '';
    exploreCoverUrlCtrl.text = source.ruleExplore?.coverUrl ?? '';
    exploreBookUrlCtrl.text = source.ruleExplore?.bookUrl ?? '';
  }

  void _loadInfo(BookSource source) {
    infoInitCtrl.text = source.ruleBookInfo?.init ?? '';
    infoNameCtrl.text = source.ruleBookInfo?.name ?? '';
    infoAuthorCtrl.text = source.ruleBookInfo?.author ?? '';
    infoKindCtrl.text = source.ruleBookInfo?.kind ?? '';
    infoWordCountCtrl.text = source.ruleBookInfo?.wordCount ?? '';
    infoLastChapterCtrl.text = source.ruleBookInfo?.lastChapter ?? '';
    infoIntroCtrl.text = source.ruleBookInfo?.intro ?? '';
    infoCoverUrlCtrl.text = source.ruleBookInfo?.coverUrl ?? '';
    infoTocUrlCtrl.text = source.ruleBookInfo?.tocUrl ?? '';
    infoCanRenameCtrl.text = source.ruleBookInfo?.canReName ?? '';
    infoDownloadUrlsCtrl.text = source.ruleBookInfo?.downloadUrls ?? '';
  }

  void _loadToc(BookSource source) {
    tocPreUpdateJsCtrl.text = source.ruleToc?.preUpdateJs ?? '';
    tocChapterListCtrl.text = source.ruleToc?.chapterList ?? '';
    tocChapterNameCtrl.text = source.ruleToc?.chapterName ?? '';
    tocChapterUrlCtrl.text = source.ruleToc?.chapterUrl ?? '';
    tocFormatJsCtrl.text = source.ruleToc?.formatJs ?? '';
    tocIsVolumeCtrl.text = source.ruleToc?.isVolume ?? '';
    tocUpdateTimeCtrl.text = source.ruleToc?.updateTime ?? '';
    tocIsVipCtrl.text = source.ruleToc?.isVip ?? '';
    tocIsPayCtrl.text = source.ruleToc?.isPay ?? '';
    tocNextTocUrlCtrl.text = source.ruleToc?.nextTocUrl ?? '';
  }

  void _loadContent(BookSource source) {
    contentContentCtrl.text = source.ruleContent?.content ?? '';
    contentTitleCtrl.text = source.ruleContent?.title ?? '';
    contentNextContentUrlCtrl.text = source.ruleContent?.nextContentUrl ?? '';
    contentWebJsCtrl.text = source.ruleContent?.webJs ?? '';
    contentSourceRegexCtrl.text = source.ruleContent?.sourceRegex ?? '';
    contentReplaceRegexCtrl.text = source.ruleContent?.replaceRegex ?? '';
    contentImageStyleCtrl.text = source.ruleContent?.imageStyle ?? '';
    contentImageDecodeCtrl.text = source.ruleContent?.imageDecode ?? '';
    contentPayActionCtrl.text = source.ruleContent?.payAction ?? '';
  }
}
