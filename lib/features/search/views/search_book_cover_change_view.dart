import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_cover_image.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/services/settings_service.dart';
import '../../source/models/book_source.dart';
import '../../source/services/rule_parser_engine.dart';

/// 书籍信息编辑页「封面换源」承载（对齐 legado ChangeCoverDialog）。
class SearchBookCoverChangeView extends StatefulWidget {
  final String name;
  final String author;

  const SearchBookCoverChangeView({
    super.key,
    required this.name,
    required this.author,
  });

  @override
  State<SearchBookCoverChangeView> createState() =>
      _SearchBookCoverChangeViewState();
}

class _SearchBookCoverChangeViewState extends State<SearchBookCoverChangeView> {
  static final RegExp _authorRegex = RegExp(
    r'^\s*作\s*者[:：\s]+|\s+著',
  );

  late final SourceRepository _sourceRepository;
  late final SettingsService _settingsService;
  final ExceptionLogService _exceptionLogService = ExceptionLogService();

  late final String _bookName;
  late final String _bookAuthor;

  bool _searching = false;
  int _requestSerial = 0;
  CancelToken? _cancelToken;
  final List<_CoverCandidate> _candidates = <_CoverCandidate>[];
  final Set<String> _seenBookUrlKeys = <String>{};

  List<_CoverCandidate> get _displayCandidates => <_CoverCandidate>[
        _CoverCandidate.defaultCover(name: _bookName, author: _bookAuthor),
        ..._candidates,
      ];

  @override
  void initState() {
    super.initState();
    final db = DatabaseService();
    _sourceRepository = SourceRepository(db);
    _settingsService = SettingsService();
    _bookName = widget.name.trim();
    _bookAuthor = widget.author.replaceAll(_authorRegex, '').trim();
    unawaited(_startSearch());
  }

  @override
  void dispose() {
    _stopSearch();
    super.dispose();
  }

  Future<void> _toggleStartStopSearch() async {
    if (_searching) {
      _stopSearch();
      return;
    }
    await _startSearch();
  }

  void _stopSearch() {
    _requestSerial++;
    final token = _cancelToken;
    _cancelToken = null;
    if (token != null && !token.isCancelled) {
      token.cancel('用户停止封面换源搜索');
    }
    if (mounted && _searching) {
      setState(() => _searching = false);
    }
  }

  int _resolveWorkerCount() {
    final concurrency = _settingsService.appSettings.searchConcurrency;
    final normalized = concurrency.clamp(2, 12).toInt();
    return normalized < 1 ? 1 : normalized;
  }

  Future<List<_IndexedSource>> _loadCoverSearchSources() async {
    var allSources = _sourceRepository.getAllSources();
    if (allSources.isEmpty) {
      // 与现有页面一致：source repo 首次读可能尚未回填缓存，轻量重试一次。
      await Future<void>.delayed(const Duration(milliseconds: 80));
      allSources = _sourceRepository.getAllSources();
    }
    final indexed = allSources
        .asMap()
        .entries
        .where((entry) {
          final source = entry.value;
          if (!source.enabled) return false;
          if ((source.searchUrl ?? '').trim().isEmpty) return false;
          final coverRule = source.ruleSearch?.coverUrl;
          return (coverRule ?? '').trim().isNotEmpty;
        })
        .map(
          (entry) => _IndexedSource(
            source: entry.value,
            sourceIndex: entry.key,
          ),
        )
        .toList(growable: false);
    indexed.sort((left, right) {
      final orderCompare = left.source.customOrder.compareTo(
        right.source.customOrder,
      );
      if (orderCompare != 0) return orderCompare;
      return left.sourceIndex.compareTo(right.sourceIndex);
    });
    return indexed;
  }

  Future<_CoverCandidate?> _searchCoverInSource({
    required _IndexedSource indexedSource,
    required String name,
    required String author,
    required CancelToken cancelToken,
    required int requestSerial,
  }) async {
    try {
      final source = indexedSource.source;
      final results = await RuleParserEngine().search(
        source,
        name,
        filter: (resultName, resultAuthor) {
          return resultName == name && resultAuthor == author;
        },
        shouldBreak: (size) => size > 0,
        cancelToken: cancelToken,
      );
      if (cancelToken.isCancelled || requestSerial != _requestSerial) {
        return null;
      }
      for (final item in results) {
        final coverUrl = item.coverUrl.trim();
        if (coverUrl.isEmpty) continue;
        if (item.name.trim() != name || item.author.trim() != author) {
          continue;
        }
        return _CoverCandidate(
          coverUrl: coverUrl,
          title: item.name.trim(),
          author: item.author.trim(),
          sourceName: source.bookSourceName.trim().isEmpty
              ? source.bookSourceUrl.trim()
              : source.bookSourceName.trim(),
          sourceUrl: source.bookSourceUrl.trim(),
          bookUrl: item.bookUrl.trim(),
          orderRank: source.customOrder,
          sourceIndex: indexedSource.sourceIndex,
          isDefault: false,
        );
      }
      return null;
    } catch (error, stackTrace) {
      if (error is DioException && error.type == DioExceptionType.cancel) {
        return null;
      }
      _exceptionLogService.record(
        node: 'search_book_info.edit.change_cover.search',
        message: '封面换源搜索失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'bookName': name,
          'bookAuthor': author,
          'sourceUrl': indexedSource.source.bookSourceUrl,
          'sourceName': indexedSource.source.bookSourceName,
        },
      );
      return null;
    }
  }

  Future<void> _startSearch() async {
    if (_bookName.isEmpty || _searching) return;

    final requestSerial = ++_requestSerial;
    final cancelToken = CancelToken();
    final oldToken = _cancelToken;
    _cancelToken = cancelToken;
    if (oldToken != null && !oldToken.isCancelled) {
      oldToken.cancel('重启封面换源搜索');
    }

    if (!mounted || requestSerial != _requestSerial) {
      return;
    }
    setState(() {
      _searching = true;
      _candidates.clear();
      _seenBookUrlKeys.clear();
    });

    try {
      final sources = await _loadCoverSearchSources();
      if (!mounted ||
          cancelToken.isCancelled ||
          requestSerial != _requestSerial) {
        return;
      }
      if (sources.isEmpty) {
        return;
      }

      var nextSourceIndex = 0;
      final workerCount = sources.length < _resolveWorkerCount()
          ? sources.length
          : _resolveWorkerCount();

      Future<void> runWorker() async {
        while (true) {
          if (!mounted ||
              cancelToken.isCancelled ||
              requestSerial != _requestSerial) {
            return;
          }
          if (nextSourceIndex >= sources.length) {
            return;
          }
          final indexedSource = sources[nextSourceIndex++];
          final found = await _searchCoverInSource(
            indexedSource: indexedSource,
            name: _bookName,
            author: _bookAuthor,
            cancelToken: cancelToken,
            requestSerial: requestSerial,
          );
          if (found == null) continue;
          if (!mounted ||
              cancelToken.isCancelled ||
              requestSerial != _requestSerial) {
            return;
          }
          setState(() {
            final bookUrlKey = _normalizeForCompare(found.bookUrl);
            if (!_seenBookUrlKeys.add(bookUrlKey)) {
              return;
            }
            _candidates.add(found);
            _candidates.sort((left, right) {
              final orderCompare = left.orderRank.compareTo(right.orderRank);
              if (orderCompare != 0) return orderCompare;
              return left.sourceIndex.compareTo(right.sourceIndex);
            });
          });
        }
      }

      await Future.wait(
        List<Future<void>>.generate(workerCount, (_) => runWorker()),
      );
    } finally {
      if (_cancelToken == cancelToken) {
        _cancelToken = null;
      }
      if (mounted && requestSerial == _requestSerial) {
        setState(() => _searching = false);
      }
    }
  }

  String _normalizeForCompare(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  void _selectCandidate(_CoverCandidate candidate) {
    Navigator.of(context).pop(candidate.coverUrl);
  }

  Widget _buildStartStopAction() {
    final actionLabel = _searching ? '停止' : '刷新';
    final actionIcon =
        _searching ? CupertinoIcons.stop_fill : CupertinoIcons.refresh;
    return AppNavBarButton(
      onPressed: _bookName.isEmpty ? null : _toggleStartStopSearch,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(actionIcon, size: 18),
          const SizedBox(width: 4),
          Text(actionLabel),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = CupertinoTheme.of(context).textTheme.textStyle;
    final cardColor =
        CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context);
    final cardBorderColor = CupertinoColors.separator.resolveFrom(context);
    final cardTextColor = CupertinoColors.label.resolveFrom(context);
    final loadingColor = CupertinoColors.activeBlue.resolveFrom(context);
    final candidates = _displayCandidates;

    return AppCupertinoPageScaffold(
      title: '封面换源',
      leading: AppNavBarButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('关闭'),
      ),
      trailing: _buildStartStopAction(),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            height: 2,
            color: _searching ? loadingColor : const Color(0x00000000),
          ),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.fromLTRB(
                12,
                12,
                12,
                16 + MediaQuery.paddingOf(context).bottom,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 12,
                childAspectRatio: 0.56,
              ),
              itemCount: candidates.length,
              itemBuilder: (context, index) {
                final candidate = candidates[index];
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _selectCandidate(candidate),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: cardBorderColor,
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
                    child: Column(
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth;
                            return AppCoverImage(
                              urlOrPath: candidate.coverUrl,
                              title: candidate.title,
                              author: candidate.author,
                              width: width,
                              height: width * 1.45,
                              borderRadius: 8,
                              showTextOnPlaceholder: !candidate.isDefault,
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          candidate.isDefault ? '默认封面' : candidate.sourceName,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: textStyle.copyWith(
                            fontSize: 12,
                            color: cardTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _IndexedSource {
  final BookSource source;
  final int sourceIndex;

  const _IndexedSource({
    required this.source,
    required this.sourceIndex,
  });
}

class _CoverCandidate {
  final String coverUrl;
  final String title;
  final String author;
  final String sourceName;
  final String sourceUrl;
  final String bookUrl;
  final int orderRank;
  final int sourceIndex;
  final bool isDefault;

  const _CoverCandidate({
    required this.coverUrl,
    required this.title,
    required this.author,
    required this.sourceName,
    required this.sourceUrl,
    required this.bookUrl,
    required this.orderRank,
    required this.sourceIndex,
    required this.isDefault,
  });

  factory _CoverCandidate.defaultCover({
    required String name,
    required String author,
  }) {
    return _CoverCandidate(
      coverUrl: 'use_default_cover',
      title: name,
      author: author,
      sourceName: '默认封面',
      sourceUrl: '',
      bookUrl: 'use_default_cover',
      orderRank: -2147483648,
      sourceIndex: -1,
      isDefault: true,
    );
  }
}
