import 'settings_service_context.dart';
import 'settings_service_keys.dart';

mixin SettingsServiceBookSecondaryMixin on SettingsServiceContext {
  int getBookReadRecordDurationMs(String bookId, {int fallback = 0}) {
    if (!isInitializedState) return fallback < 0 ? 0 : fallback;
    final key = bookId.trim();
    if (key.isEmpty) return fallback < 0 ? 0 : fallback;
    final value = bookReadRecordDurationState[key];
    if (value == null) return fallback < 0 ? 0 : fallback;
    return value < 0 ? 0 : value;
  }

  Map<String, int> getBookReadRecordDurationSnapshot() {
    if (!isInitializedState || bookReadRecordDurationState.isEmpty) {
      return const <String, int>{};
    }
    return Map<String, int>.unmodifiable(bookReadRecordDurationState);
  }

  int getTotalBookReadRecordDurationMs() {
    if (!isInitializedState || bookReadRecordDurationState.isEmpty) {
      return 0;
    }
    var total = 0;
    for (final value in bookReadRecordDurationState.values) {
      if (value <= 0) continue;
      total += value;
    }
    return total;
  }

  Future<void> addBookReadRecordDurationMs(
    String bookId,
    int durationMs,
  ) async {
    if (!isInitializedState) return;
    final key = bookId.trim();
    if (key.isEmpty) return;
    final safeDuration = durationMs < 0 ? 0 : durationMs;
    if (safeDuration == 0) return;
    final current = bookReadRecordDurationState[key] ?? 0;
    bookReadRecordDurationState = Map<String, int>.from(
      bookReadRecordDurationState,
    )..[key] = current + safeDuration;
    await persistIntMap(
      settingsKeyBookReadRecordDurationMap,
      bookReadRecordDurationState,
    );
  }

  Future<void> clearBookReadRecordDuration(String bookId) async {
    if (!isInitializedState) return;
    final key = bookId.trim();
    if (key.isEmpty || !bookReadRecordDurationState.containsKey(key)) return;
    bookReadRecordDurationState = Map<String, int>.from(
      bookReadRecordDurationState,
    )..remove(key);
    await persistIntMap(
      settingsKeyBookReadRecordDurationMap,
      bookReadRecordDurationState,
    );
  }

  Future<void> clearAllBookReadRecordDuration() async {
    if (!isInitializedState) return;
    bookReadRecordDurationState = <String, int>{};
    await prefsStoreState.remove(settingsKeyBookReadRecordDurationMap);
  }

  bool getBookReadSimulating(String bookId, {bool fallback = false}) {
    if (!isInitializedState) return fallback;
    final key = bookId.trim();
    if (key.isEmpty) return fallback;
    return bookReadSimulatingState[key] ?? fallback;
  }

  Future<void> saveBookReadSimulating(String bookId, bool enabled) async {
    if (!isInitializedState) return;
    final key = bookId.trim();
    if (key.isEmpty) return;
    bookReadSimulatingState = Map<String, bool>.from(bookReadSimulatingState)
      ..[key] = enabled;
    await persistBoolMap(settingsKeyBookReadSimulatingMap, bookReadSimulatingState);
  }

  int getBookSimulatedStartChapter(String bookId, {int fallback = 0}) {
    if (!isInitializedState) return fallback;
    final key = bookId.trim();
    if (key.isEmpty) return fallback;
    final value = bookSimulatedStartChapterState[key];
    if (value == null) return fallback;
    if (value < 0) return 0;
    return value;
  }

  Future<void> saveBookSimulatedStartChapter(
    String bookId,
    int startChapter,
  ) async {
    if (!isInitializedState) return;
    final key = bookId.trim();
    if (key.isEmpty) return;
    final normalized = startChapter < 0 ? 0 : startChapter;
    bookSimulatedStartChapterState =
        Map<String, int>.from(bookSimulatedStartChapterState)
          ..[key] = normalized;
    await persistIntMap(
      settingsKeyBookSimulatedStartChapterMap,
      bookSimulatedStartChapterState,
    );
  }

  int getBookSimulatedDailyChapters(String bookId, {int fallback = 3}) {
    if (!isInitializedState) return fallback;
    final key = bookId.trim();
    if (key.isEmpty) return fallback;
    final value = bookSimulatedDailyChaptersState[key];
    if (value == null) return fallback;
    if (value < 0) return 0;
    return value;
  }

  Future<void> saveBookSimulatedDailyChapters(
    String bookId,
    int dailyChapters,
  ) async {
    if (!isInitializedState) return;
    final key = bookId.trim();
    if (key.isEmpty) return;
    final normalized = dailyChapters < 0 ? 0 : dailyChapters;
    bookSimulatedDailyChaptersState =
        Map<String, int>.from(bookSimulatedDailyChaptersState)
          ..[key] = normalized;
    await persistIntMap(
      settingsKeyBookSimulatedDailyChaptersMap,
      bookSimulatedDailyChaptersState,
    );
  }

  DateTime? getBookSimulatedStartDate(String bookId) {
    if (!isInitializedState) return null;
    final key = bookId.trim();
    if (key.isEmpty) return null;
    final value = bookSimulatedStartDateState[key]?.trim();
    if (value == null || value.isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  Future<void> saveBookSimulatedStartDate(
    String bookId,
    DateTime? startDate,
  ) async {
    if (!isInitializedState) return;
    final key = bookId.trim();
    if (key.isEmpty) return;
    final nextMap = Map<String, String>.from(bookSimulatedStartDateState);
    if (startDate == null) {
      nextMap.remove(key);
    } else {
      nextMap[key] = _formatDateOnly(_normalizeDateOnly(startDate));
    }
    bookSimulatedStartDateState = nextMap;
    await persistStringMap(
      settingsKeyBookSimulatedStartDateMap,
      bookSimulatedStartDateState,
    );
  }

  Future<void> saveBookSimulatedReadingConfig(
    String bookId, {
    required bool enabled,
    required int startChapter,
    required int dailyChapters,
    required DateTime startDate,
  }) async {
    if (!isInitializedState) return;
    final key = bookId.trim();
    if (key.isEmpty) return;

    final safeStartChapter = startChapter < 0 ? 0 : startChapter;
    final safeDailyChapters = dailyChapters < 0 ? 0 : dailyChapters;
    final safeDate = _normalizeDateOnly(startDate);

    bookReadSimulatingState = Map<String, bool>.from(bookReadSimulatingState)
      ..[key] = enabled;
    bookSimulatedStartChapterState =
        Map<String, int>.from(bookSimulatedStartChapterState)
          ..[key] = safeStartChapter;
    bookSimulatedDailyChaptersState =
        Map<String, int>.from(bookSimulatedDailyChaptersState)
          ..[key] = safeDailyChapters;
    bookSimulatedStartDateState = Map<String, String>.from(
      bookSimulatedStartDateState,
    )..[key] = _formatDateOnly(safeDate);

    await Future.wait<void>([
      persistBoolMap(settingsKeyBookReadSimulatingMap, bookReadSimulatingState),
      persistIntMap(
        settingsKeyBookSimulatedStartChapterMap,
        bookSimulatedStartChapterState,
      ),
      persistIntMap(
        settingsKeyBookSimulatedDailyChaptersMap,
        bookSimulatedDailyChaptersState,
      ),
      persistStringMap(
        settingsKeyBookSimulatedStartDateMap,
        bookSimulatedStartDateState,
      ),
    ]);
  }

  DateTime _normalizeDateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  String _formatDateOnly(DateTime value) {
    final yyyy = value.year.toString().padLeft(4, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  String? getBookRemoteUploadUrl(String bookId) {
    if (!isInitializedState) return null;
    final key = bookId.trim();
    if (key.isEmpty) return null;
    final value = bookRemoteUploadUrlState[key]?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Future<void> saveBookRemoteUploadUrl(
    String bookId,
    String remoteUrl,
  ) async {
    if (!isInitializedState) return;
    final key = bookId.trim();
    final value = remoteUrl.trim();
    if (key.isEmpty || value.isEmpty) return;
    bookRemoteUploadUrlState = Map<String, String>.from(bookRemoteUploadUrlState)
      ..[key] = value;
    await persistStringMap(
      settingsKeyBookRemoteUploadUrlMap, bookRemoteUploadUrlState,
    );
  }

  String? getBookReaderImageSizeSnapshot(String bookId) {
    if (!isInitializedState) return null;
    final key = bookId.trim();
    if (key.isEmpty) return null;
    final value = bookReaderImageSizeSnapshotState[key]?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Future<void> saveBookReaderImageSizeSnapshot(
    String bookId,
    String snapshotJson,
  ) async {
    if (!isInitializedState) return;
    final key = bookId.trim();
    if (key.isEmpty) return;
    final value = snapshotJson.trim();
    if (value.isEmpty) {
      if (bookReaderImageSizeSnapshotState.containsKey(key)) {
        bookReaderImageSizeSnapshotState =
            Map<String, String>.from(bookReaderImageSizeSnapshotState)
              ..remove(key);
        await persistStringMap(
          settingsKeyBookReaderImageSizeSnapshotMap,
          bookReaderImageSizeSnapshotState,
        );
      }
      return;
    }
    if (value.length > settingsMaxReaderImageSizeSnapshotBytes) {
      return;
    }
    bookReaderImageSizeSnapshotState =
        Map<String, String>.from(bookReaderImageSizeSnapshotState)
          ..[key] = value;
    await persistStringMap(
      settingsKeyBookReaderImageSizeSnapshotMap,
      bookReaderImageSizeSnapshotState,
    );
  }
}
