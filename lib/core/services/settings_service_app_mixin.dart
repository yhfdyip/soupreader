import 'package:flutter/foundation.dart';

import '../config/migration_exclusions.dart';
import '../models/app_settings.dart';
import 'settings_service_context.dart';

mixin SettingsServiceAppMixin on SettingsServiceContext {
  Future<void> saveAutoRefresh(bool enabled) async {
    await saveAppSettingsPatch(
      (current) => current.copyWith(autoRefresh: enabled),
    );
  }

  Future<void> saveDefaultToRead(bool enabled) async {
    await saveAppSettingsPatch(
      (current) => current.copyWith(defaultToRead: enabled),
    );
  }

  Future<void> saveShowDiscovery(bool enabled) async {
    await saveAppSettingsPatch(
      (current) => current.copyWith(showDiscovery: enabled),
    );
  }

  Future<void> saveShowRss(bool enabled) async {
    if (MigrationExclusions.excludeRss) {
      debugPrint('[settings] 迁移排除：阻断 saveShowRss（excludeRss=true），不写入');
      return;
    }
    await saveAppSettingsPatch(
      (current) => current.copyWith(showRss: enabled),
    );
  }

  Future<void> saveDefaultHomePage(MainDefaultHomePage value) async {
    if (MigrationExclusions.excludeRss && value == MainDefaultHomePage.rss) {
      debugPrint(
        '[settings] 迁移排除：阻断 saveDefaultHomePage（excludeRss=true, value=rss），不写入',
      );
      return;
    }
    await saveAppSettingsPatch(
      (current) => current.copyWith(defaultHomePage: value),
    );
  }

  Future<void> savePreDownloadNum(int value) async {
    await saveAppSettingsPatch(
      (current) => current.copyWith(preDownloadNum: value),
    );
  }

  Future<void> saveThreadCount(int value) async {
    await saveAppSettingsPatch(
      (current) => current.copyWith(threadCount: value),
    );
  }

  Future<void> saveBitmapCacheSize(int value) async {
    await saveAppSettingsPatch(
      (current) => current.copyWith(bitmapCacheSize: value),
    );
  }

  Future<void> saveImageRetainNum(int value) async {
    if (MigrationExclusions.excludeManga) {
      debugPrint(
        '[settings] 迁移排除：阻断 saveImageRetainNum（excludeManga=true），不写入',
      );
      return;
    }
    await saveAppSettingsPatch(
      (current) => current.copyWith(imageRetainNum: value),
    );
  }

  Future<void> saveReplaceEnableDefault(bool enabled) async {
    await saveAppSettingsPatch(
      (current) => current.copyWith(replaceEnableDefault: enabled),
    );
  }

  Future<void> saveCronet(bool enabled) async {
    await saveAppSettingsPatch(
      (current) => current.copyWith(cronet: enabled),
    );
  }

  Future<void> saveAntiAlias(bool enabled) async {
    await saveAppSettingsPatch(
      (current) => current.copyWith(antiAlias: enabled),
    );
  }

  Future<void> saveMediaButtonOnExit(bool enabled) async {
    if (MigrationExclusions.excludeTts) {
      debugPrint(
        '[settings] 迁移排除：阻断 saveMediaButtonOnExit（excludeTts=true），不写入',
      );
      return;
    }
    await saveAppSettingsPatch(
      (current) => current.copyWith(mediaButtonOnExit: enabled),
    );
  }

  Future<void> saveReadAloudByMediaButton(bool enabled) async {
    if (MigrationExclusions.excludeTts) {
      debugPrint(
        '[settings] 迁移排除：阻断 saveReadAloudByMediaButton（excludeTts=true），不写入',
      );
      return;
    }
    await saveAppSettingsPatch(
      (current) => current.copyWith(readAloudByMediaButton: enabled),
    );
  }

  Future<void> saveIgnoreAudioFocus(bool enabled) async {
    if (MigrationExclusions.excludeTts) {
      debugPrint(
        '[settings] 迁移排除：阻断 saveIgnoreAudioFocus（excludeTts=true），不写入',
      );
      return;
    }
    await saveAppSettingsPatch(
      (current) => current.copyWith(ignoreAudioFocus: enabled),
    );
  }

  Future<void> saveAutoClearExpired(bool enabled) async {
    await saveAppSettingsPatch(
      (current) => current.copyWith(autoClearExpired: enabled),
    );
  }

  Future<void> saveShowAddToShelfAlert(bool enabled) async {
    await saveAppSettingsPatch(
      (current) => current.copyWith(showAddToShelfAlert: enabled),
    );
  }

  Future<void> saveUpdateToVariant(String value) async {
    final updateToVariant = AppSettings.normalizeUpdateToVariant(value);
    await saveAppSettingsPatch(
      (current) => current.copyWith(updateToVariant: updateToVariant),
    );
  }

  Future<void> saveShowMangaUi(bool enabled) async {
    if (MigrationExclusions.excludeManga) {
      debugPrint(
        '[settings] 迁移排除：阻断 saveShowMangaUi（excludeManga=true），不写入',
      );
      return;
    }
    await saveAppSettingsPatch(
      (current) => current.copyWith(showMangaUi: enabled),
    );
  }

  Future<void> saveProcessText(bool enabled) async {
    await saveAppSettingsPatch(
      (current) => current.copyWith(processText: enabled),
    );
  }

  Future<void> saveRecordLog(bool enabled) async {
    await saveAppSettingsPatch(
      (current) => current.copyWith(recordLog: enabled),
    );
  }

  Future<void> saveRecordHeapDump(bool enabled) async {
    await saveAppSettingsPatch(
      (current) => current.copyWith(recordHeapDump: enabled),
    );
  }

  Future<void> saveLauncherIcon(String value) async {
    final normalized = value.trim();
    await saveAppSettingsPatch(
      (current) => current.copyWith(
        launcherIcon:
            normalized.isEmpty ? AppSettings.defaultLauncherIcon : normalized,
      ),
    );
  }

  Future<void> saveTransparentStatusBar(bool enabled) async {
    await saveAppSettingsPatch(
      (current) => current.copyWith(transparentStatusBar: enabled),
    );
  }

  Future<void> saveImmNavigationBar(bool enabled) async {
    await saveAppSettingsPatch(
      (current) => current.copyWith(immNavigationBar: enabled),
    );
  }

  Future<void> saveBarElevation(int value) async {
    await saveAppSettingsPatch(
      (current) => current.copyWith(barElevation: value),
    );
  }

  Future<void> saveFontScale(int value) async {
    await saveAppSettingsPatch(
      (current) => current.copyWith(fontScale: value),
    );
  }

  Future<void> saveBackgroundImage(String? path) async {
    final normalized = (path ?? '').trim();
    await saveAppSettingsPatch(
      (current) => current.copyWith(backgroundImage: normalized),
    );
  }

  Future<void> saveBackgroundImageNight(String? path) async {
    final normalized = (path ?? '').trim();
    await saveAppSettingsPatch(
      (current) => current.copyWith(backgroundImageNight: normalized),
    );
  }

  Future<void> saveBackgroundImageBlurring(int value) async {
    await saveAppSettingsPatch(
      (current) => current.copyWith(backgroundImageBlurring: value),
    );
  }

  Future<void> saveBackgroundImageNightBlurring(int value) async {
    await saveAppSettingsPatch(
      (current) => current.copyWith(backgroundImageNightBlurring: value),
    );
  }

  Future<void> saveSyncBookProgress(bool enabled) async {
    await saveAppSettingsPatch(
      (current) => current.copyWith(syncBookProgress: enabled),
    );
  }

  Future<void> saveSyncBookProgressPlus(bool enabled) async {
    await saveAppSettingsPatch(
      (current) => current.copyWith(syncBookProgressPlus: enabled),
    );
  }

  Future<void> saveWebDavDeviceName(String value) async {
    await saveAppSettingsPatch(
      (current) => current.copyWith(webDavDeviceName: value.trim()),
    );
  }

  Future<void> saveBackupPath(String path) async {
    await saveAppSettingsPatch(
      (current) => current.copyWith(backupPath: path.trim()),
    );
  }

  Future<void> saveOnlyLatestBackup(bool enabled) async {
    await saveAppSettingsPatch(
      (current) => current.copyWith(onlyLatestBackup: enabled),
    );
  }

  Future<void> saveAutoCheckNewBackup(bool enabled) async {
    await saveAppSettingsPatch(
      (current) => current.copyWith(autoCheckNewBackup: enabled),
    );
  }
}
