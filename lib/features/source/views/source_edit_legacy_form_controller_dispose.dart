import 'package:flutter/cupertino.dart';

import 'source_edit_legacy_form_controllers.dart';

extension SourceEditLegacyFormControllersDisposeX
    on SourceEditLegacyFormControllers {
  void dispose() {
    _disposeControllers(<TextEditingController>[
      bookSourceUrlCtrl,
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
      jsLibCtrl,
      searchUrlCtrl,
      searchCheckKeyWordCtrl,
      searchBookListCtrl,
      searchNameCtrl,
      searchAuthorCtrl,
      searchKindCtrl,
      searchWordCountCtrl,
      searchLastChapterCtrl,
      searchIntroCtrl,
      searchCoverUrlCtrl,
      searchBookUrlCtrl,
      exploreUrlCtrl,
      exploreBookListCtrl,
      exploreNameCtrl,
      exploreAuthorCtrl,
      exploreKindCtrl,
      exploreWordCountCtrl,
      exploreLastChapterCtrl,
      exploreIntroCtrl,
      exploreCoverUrlCtrl,
      exploreBookUrlCtrl,
      infoInitCtrl,
      infoNameCtrl,
      infoAuthorCtrl,
      infoKindCtrl,
      infoWordCountCtrl,
      infoLastChapterCtrl,
      infoIntroCtrl,
      infoCoverUrlCtrl,
      infoTocUrlCtrl,
      infoCanRenameCtrl,
      infoDownloadUrlsCtrl,
      tocPreUpdateJsCtrl,
      tocChapterListCtrl,
      tocChapterNameCtrl,
      tocChapterUrlCtrl,
      tocFormatJsCtrl,
      tocIsVolumeCtrl,
      tocUpdateTimeCtrl,
      tocIsVipCtrl,
      tocIsPayCtrl,
      tocNextTocUrlCtrl,
      contentContentCtrl,
      contentTitleCtrl,
      contentNextContentUrlCtrl,
      contentWebJsCtrl,
      contentSourceRegexCtrl,
      contentReplaceRegexCtrl,
      contentImageStyleCtrl,
      contentImageDecodeCtrl,
      contentPayActionCtrl,
    ]);
  }

  void _disposeControllers(List<TextEditingController> controllers) {
    for (final controller in controllers) {
      controller.dispose();
    }
  }
}
