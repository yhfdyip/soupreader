const String settingsKeyReadingSettings = 'reading_settings';
const String settingsKeyReadingSettingsSchemaVersion =
    'reading_settings_schema_version';
const String settingsKeyAppSettings = 'app_settings';
const String settingsKeyReaderChapterUrlOpenInBrowser =
    'reader_chapter_url_open_in_browser';
const String settingsKeyReaderFontFolderPath = 'reader_font_folder_path';
const String settingsKeyReaderCustomFontPath = 'reader_custom_font_path';
const String settingsKeyBookCanUpdateMap = 'book_can_update_map';
const String settingsKeyBookSplitLongChapterMap =
    'book_split_long_chapter_map';
const String settingsKeyBookTxtTocRuleMap = 'book_txt_toc_rule_map';
const String settingsKeyBookUseReplaceRuleMap = 'book_use_replace_rule_map';
const String settingsKeyTocUiUseReplace = 'toc_ui_use_replace';
const String settingsKeyTocUiLoadWordCount = 'toc_ui_load_word_count';
const String settingsKeyChangeSourceCheckAuthor = 'changeSourceCheckAuthor';
const String settingsKeyChangeSourceLoadWordCount = 'changeSourceLoadWordCount';
const String settingsKeyChangeSourceLoadInfo = 'changeSourceLoadInfo';
const String settingsKeyChangeSourceLoadToc = 'changeSourceLoadToc';
const String settingsKeyChangeSourceGroup = 'searchGroup';
const String settingsKeyBatchChangeSourceDelay = 'batchChangeSourceDelay';
const String settingsKeyOpenBookInfoByClickTitle = 'openBookInfoByClickTitle';
const String settingsKeyDeleteBookOriginal = 'deleteBookOriginal';
const String settingsKeyBookPageAnimMap = 'book_page_anim_map';
const String settingsKeyBookReSegmentMap = 'book_re_segment_map';
const String settingsKeyBookImageStyleMap = 'book_image_style_map';
const String settingsKeyChapterSameTitleRemovedMap =
    'chapter_same_title_removed_map';
const String settingsKeyBookDelRubyTagMap = 'book_del_ruby_tag_map';
const String settingsKeyBookDelHTagMap = 'book_del_h_tag_map';
const String settingsKeyBookReadSimulatingMap = 'book_read_simulating_map';
const String settingsKeyBookSimulatedStartChapterMap =
    'book_simulated_start_chapter_map';
const String settingsKeyBookSimulatedDailyChaptersMap =
    'book_simulated_daily_chapters_map';
const String settingsKeyBookSimulatedStartDateMap =
    'book_simulated_start_date_map';
const String settingsKeyBookRemoteUploadUrlMap = 'book_remote_upload_url_map';
const String settingsKeyBookReaderImageSizeSnapshotMap =
    'book_reader_image_size_snapshot_map';
const String settingsKeyAudioPlayWakeLock = 'audioPlayWakeLock';
const String settingsKeyContentSelectSpeakMod = 'contentSelectSpeakMod';
const String settingsKeyEnableReadRecord = 'enableReadRecord';
const String settingsKeyReadRecordSort = 'readRecordSort';
const String settingsKeyBookReadRecordDurationMap =
    'book_read_record_duration_map';
const String settingsKeyLoadCoverOnlyWifi = 'loadCoverOnlyWifi';
const String settingsKeyCoverRule = 'coverRule';
const String settingsKeyUseDefaultCover = 'useDefaultCover';
const String settingsKeyDefaultCoverPath = 'defaultCover';
const String settingsKeyDefaultCoverDarkPath = 'defaultCoverDark';
const String settingsKeyCoverShowName = 'coverShowName';
const String settingsKeyCoverShowAuthor = 'coverShowAuthor';
const String settingsKeyCoverShowNameNight = 'coverShowNameN';
const String settingsKeyCoverShowAuthorNight = 'coverShowAuthorN';
const String settingsKeyCustomWelcome = 'customWelcome';
const String settingsKeyWelcomeImagePath = 'welcomeImagePath';
const String settingsKeyWelcomeImageDarkPath = 'welcomeImagePathDark';
const String settingsKeyWelcomeShowText = 'welcomeShowText';
const String settingsKeyWelcomeShowIcon = 'welcomeShowIcon';
const String settingsKeyWelcomeShowTextDark = 'welcomeShowTextDark';
const String settingsKeyWelcomeShowIconDark = 'welcomeShowIconDark';
const String settingsKeyLastSeenWebDavBackupMillis =
    'last_seen_webdav_backup_millis';
const String settingsDefaultImageStyle = 'DEFAULT';
const Set<String> settingsValidImageStyles = <String>{
  'DEFAULT',
  'FULL',
  'TEXT',
  'SINGLE',
};
const int settingsReadingSettingsSchemaVersion = 4;
const int settingsMaxReaderImageSizeSnapshotBytes = 120 * 1024;
