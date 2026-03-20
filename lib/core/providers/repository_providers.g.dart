// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'repository_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 书籍仓储（全局单例）。

@ProviderFor(bookRepository)
final bookRepositoryProvider = BookRepositoryProvider._();

/// 书籍仓储（全局单例）。

final class BookRepositoryProvider
    extends $FunctionalProvider<BookRepository, BookRepository, BookRepository>
    with $Provider<BookRepository> {
  /// 书籍仓储（全局单例）。
  BookRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'bookRepositoryProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$bookRepositoryHash();

  @$internal
  @override
  $ProviderElement<BookRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BookRepository create(Ref ref) {
    return bookRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BookRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BookRepository>(value),
    );
  }
}

String _$bookRepositoryHash() => r'fc7acfc8cf4a29458810f454ea9301241d28507b';

/// 章节仓储（全局单例）。

@ProviderFor(chapterRepository)
final chapterRepositoryProvider = ChapterRepositoryProvider._();

/// 章节仓储（全局单例）。

final class ChapterRepositoryProvider extends $FunctionalProvider<
    ChapterRepository,
    ChapterRepository,
    ChapterRepository> with $Provider<ChapterRepository> {
  /// 章节仓储（全局单例）。
  ChapterRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'chapterRepositoryProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$chapterRepositoryHash();

  @$internal
  @override
  $ProviderElement<ChapterRepository> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ChapterRepository create(Ref ref) {
    return chapterRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChapterRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChapterRepository>(value),
    );
  }
}

String _$chapterRepositoryHash() => r'584f6970f9d1f015cdf84db4fccabd806e063fcd';

/// 书源仓储（全局单例）。

@ProviderFor(sourceRepository)
final sourceRepositoryProvider = SourceRepositoryProvider._();

/// 书源仓储（全局单例）。

final class SourceRepositoryProvider extends $FunctionalProvider<
    SourceRepository,
    SourceRepository,
    SourceRepository> with $Provider<SourceRepository> {
  /// 书源仓储（全局单例）。
  SourceRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'sourceRepositoryProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$sourceRepositoryHash();

  @$internal
  @override
  $ProviderElement<SourceRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SourceRepository create(Ref ref) {
    return sourceRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SourceRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SourceRepository>(value),
    );
  }
}

String _$sourceRepositoryHash() => r'7868085e6b1c2c5c3b69cd66ebba3595309608e7';

/// 替换规则仓储（全局单例）。

@ProviderFor(replaceRuleRepository)
final replaceRuleRepositoryProvider = ReplaceRuleRepositoryProvider._();

/// 替换规则仓储（全局单例）。

final class ReplaceRuleRepositoryProvider extends $FunctionalProvider<
    ReplaceRuleRepository,
    ReplaceRuleRepository,
    ReplaceRuleRepository> with $Provider<ReplaceRuleRepository> {
  /// 替换规则仓储（全局单例）。
  ReplaceRuleRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'replaceRuleRepositoryProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$replaceRuleRepositoryHash();

  @$internal
  @override
  $ProviderElement<ReplaceRuleRepository> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ReplaceRuleRepository create(Ref ref) {
    return replaceRuleRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReplaceRuleRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReplaceRuleRepository>(value),
    );
  }
}

String _$replaceRuleRepositoryHash() =>
    r'fe8ef3a2c8c15e23a8b8ee4cc7af9f5c966db282';

/// 书签仓储（全局单例）。

@ProviderFor(bookmarkRepository)
final bookmarkRepositoryProvider = BookmarkRepositoryProvider._();

/// 书签仓储（全局单例）。

final class BookmarkRepositoryProvider extends $FunctionalProvider<
    BookmarkRepository,
    BookmarkRepository,
    BookmarkRepository> with $Provider<BookmarkRepository> {
  /// 书签仓储（全局单例）。
  BookmarkRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'bookmarkRepositoryProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$bookmarkRepositoryHash();

  @$internal
  @override
  $ProviderElement<BookmarkRepository> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BookmarkRepository create(Ref ref) {
    return bookmarkRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BookmarkRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BookmarkRepository>(value),
    );
  }
}

String _$bookmarkRepositoryHash() =>
    r'9796ba521b5c91dd261710c63db79d1e7acd6340';

/// RSS 源仓储（全局单例）。

@ProviderFor(rssSourceRepository)
final rssSourceRepositoryProvider = RssSourceRepositoryProvider._();

/// RSS 源仓储（全局单例）。

final class RssSourceRepositoryProvider extends $FunctionalProvider<
    RssSourceRepository,
    RssSourceRepository,
    RssSourceRepository> with $Provider<RssSourceRepository> {
  /// RSS 源仓储（全局单例）。
  RssSourceRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'rssSourceRepositoryProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$rssSourceRepositoryHash();

  @$internal
  @override
  $ProviderElement<RssSourceRepository> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RssSourceRepository create(Ref ref) {
    return rssSourceRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RssSourceRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RssSourceRepository>(value),
    );
  }
}

String _$rssSourceRepositoryHash() =>
    r'77b1ee5824c443bfee4e2b5c7cc3842664779c3a';

/// RSS 文章仓储（全局单例）。

@ProviderFor(rssArticleRepository)
final rssArticleRepositoryProvider = RssArticleRepositoryProvider._();

/// RSS 文章仓储（全局单例）。

final class RssArticleRepositoryProvider extends $FunctionalProvider<
    RssArticleRepository,
    RssArticleRepository,
    RssArticleRepository> with $Provider<RssArticleRepository> {
  /// RSS 文章仓储（全局单例）。
  RssArticleRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'rssArticleRepositoryProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$rssArticleRepositoryHash();

  @$internal
  @override
  $ProviderElement<RssArticleRepository> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RssArticleRepository create(Ref ref) {
    return rssArticleRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RssArticleRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RssArticleRepository>(value),
    );
  }
}

String _$rssArticleRepositoryHash() =>
    r'c17ea112e43514f003e40a21ddcc11207981ad92';

/// RSS 阅读记录仓储（全局单例）。

@ProviderFor(rssReadRecordRepository)
final rssReadRecordRepositoryProvider = RssReadRecordRepositoryProvider._();

/// RSS 阅读记录仓储（全局单例）。

final class RssReadRecordRepositoryProvider extends $FunctionalProvider<
    RssReadRecordRepository,
    RssReadRecordRepository,
    RssReadRecordRepository> with $Provider<RssReadRecordRepository> {
  /// RSS 阅读记录仓储（全局单例）。
  RssReadRecordRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'rssReadRecordRepositoryProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$rssReadRecordRepositoryHash();

  @$internal
  @override
  $ProviderElement<RssReadRecordRepository> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RssReadRecordRepository create(Ref ref) {
    return rssReadRecordRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RssReadRecordRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RssReadRecordRepository>(value),
    );
  }
}

String _$rssReadRecordRepositoryHash() =>
    r'bf1b08c3ff154c46e0b792e5be6d35549257e3a9';

/// RSS 收藏仓储（全局单例）。

@ProviderFor(rssStarRepository)
final rssStarRepositoryProvider = RssStarRepositoryProvider._();

/// RSS 收藏仓储（全局单例）。

final class RssStarRepositoryProvider extends $FunctionalProvider<
    RssStarRepository,
    RssStarRepository,
    RssStarRepository> with $Provider<RssStarRepository> {
  /// RSS 收藏仓储（全局单例）。
  RssStarRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'rssStarRepositoryProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$rssStarRepositoryHash();

  @$internal
  @override
  $ProviderElement<RssStarRepository> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RssStarRepository create(Ref ref) {
    return rssStarRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RssStarRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RssStarRepository>(value),
    );
  }
}

String _$rssStarRepositoryHash() => r'38e76138f6efa54977c0add841b718e78563eec9';
