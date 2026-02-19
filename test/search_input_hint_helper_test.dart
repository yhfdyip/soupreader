import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/features/bookshelf/models/book.dart';
import 'package:soupreader/features/search/services/search_input_hint_helper.dart';

Book _book({
  required String id,
  required String title,
  required String author,
}) {
  return Book(
    id: id,
    title: title,
    author: author,
  );
}

void main() {
  test('shouldAutoSubmitInitialKeyword: 非空初始关键词自动提交', () {
    expect(
      SearchInputHintHelper.shouldAutoSubmitInitialKeyword(
        initialKeyword: '诛仙',
      ),
      isTrue,
    );
    expect(
      SearchInputHintHelper.shouldAutoSubmitInitialKeyword(
        initialKeyword: '  诛仙  ',
      ),
      isTrue,
    );
    expect(
      SearchInputHintHelper.shouldAutoSubmitInitialKeyword(
        initialKeyword: '',
      ),
      isFalse,
    );
  });

  test('shouldRequestFocusOnOpen: 空初始关键词请求焦点', () {
    expect(
      SearchInputHintHelper.shouldRequestFocusOnOpen(
        initialKeyword: '',
      ),
      isTrue,
    );
    expect(
      SearchInputHintHelper.shouldRequestFocusOnOpen(
        initialKeyword: '   ',
      ),
      isTrue,
    );
    expect(
      SearchInputHintHelper.shouldRequestFocusOnOpen(
        initialKeyword: '诛仙',
      ),
      isFalse,
    );
  });

  test('filterBookshelfBooks: 仅在关键字非空时按书名/作者过滤', () {
    final books = <Book>[
      _book(id: '1', title: '诛仙', author: '萧鼎'),
      _book(id: '2', title: '三体', author: '刘慈欣'),
      _book(id: '3', title: '庆余年', author: '猫腻'),
    ];

    expect(
      SearchInputHintHelper.filterBookshelfBooks(books, ''),
      isEmpty,
    );
    expect(
      SearchInputHintHelper.filterBookshelfBooks(books, '三体')
          .map((item) => item.id)
          .toList(),
      <String>['2'],
    );
    expect(
      SearchInputHintHelper.filterBookshelfBooks(books, '猫腻')
          .map((item) => item.id)
          .toList(),
      <String>['3'],
    );
  });

  test('filterHistoryKeywords: 空关键字返回全部，非空按包含过滤', () {
    final history = <String>[
      '诛仙',
      '庆余年',
      '凡人修仙传',
    ];

    expect(
      SearchInputHintHelper.filterHistoryKeywords(history, ''),
      history,
    );
    expect(
      SearchInputHintHelper.filterHistoryKeywords(history, '余'),
      <String>['庆余年'],
    );
  });

  test('hasExactBookTitle: 仅精确匹配书名时为 true', () {
    final books = <Book>[
      _book(id: '1', title: '诛仙', author: '萧鼎'),
      _book(id: '2', title: '三体', author: '刘慈欣'),
    ];

    expect(SearchInputHintHelper.hasExactBookTitle(books, '诛仙'), isTrue);
    expect(SearchInputHintHelper.hasExactBookTitle(books, ' 诛仙 '), isTrue);
    expect(SearchInputHintHelper.hasExactBookTitle(books, '诛'), isFalse);
  });

  test('shouldSubmitHistoryKeyword: 对齐 legado 点击历史词触发条件', () {
    expect(
      SearchInputHintHelper.shouldSubmitHistoryKeyword(
        currentKeyword: '诛仙',
        selectedKeyword: '诛仙',
        hasExactBookshelfTitle: true,
      ),
      isTrue,
    );
    expect(
      SearchInputHintHelper.shouldSubmitHistoryKeyword(
        currentKeyword: '诛',
        selectedKeyword: '诛仙',
        hasExactBookshelfTitle: true,
      ),
      isFalse,
    );
    expect(
      SearchInputHintHelper.shouldSubmitHistoryKeyword(
        currentKeyword: '诛',
        selectedKeyword: '诛仙',
        hasExactBookshelfTitle: false,
      ),
      isTrue,
    );
  });

  test('shouldShowInputHelpPanel: 搜索中始终隐藏', () {
    expect(
      SearchInputHintHelper.shouldShowInputHelpPanel(
        isSearching: true,
        hasInputFocus: true,
        resultCount: 0,
        currentKeyword: '',
      ),
      isFalse,
    );
  });

  test('shouldShowInputHelpPanel: 输入框有焦点时显示', () {
    expect(
      SearchInputHintHelper.shouldShowInputHelpPanel(
        isSearching: false,
        hasInputFocus: true,
        resultCount: 10,
        currentKeyword: '诛仙',
      ),
      isTrue,
    );
  });

  test('shouldShowInputHelpPanel: 无焦点且有结果且输入非空时隐藏', () {
    expect(
      SearchInputHintHelper.shouldShowInputHelpPanel(
        isSearching: false,
        hasInputFocus: false,
        resultCount: 3,
        currentKeyword: '三体',
      ),
      isFalse,
    );
  });

  test('shouldShowInputHelpPanel: 无焦点但输入为空或无结果时显示', () {
    expect(
      SearchInputHintHelper.shouldShowInputHelpPanel(
        isSearching: false,
        hasInputFocus: false,
        resultCount: 3,
        currentKeyword: '',
      ),
      isTrue,
    );
    expect(
      SearchInputHintHelper.shouldShowInputHelpPanel(
        isSearching: false,
        hasInputFocus: false,
        resultCount: 0,
        currentKeyword: '诛仙',
      ),
      isTrue,
    );
  });

  test('shouldAutoSearchOnScopeChanged: 输入为空时不自动搜索', () {
    expect(
      SearchInputHintHelper.shouldAutoSearchOnScopeChanged(
        isSearching: false,
        hasInputFocus: false,
        resultCount: 3,
        currentKeyword: '',
      ),
      isFalse,
    );
  });

  test('shouldAutoSearchOnScopeChanged: 输入帮助可见时不自动搜索', () {
    expect(
      SearchInputHintHelper.shouldAutoSearchOnScopeChanged(
        isSearching: false,
        hasInputFocus: true,
        resultCount: 5,
        currentKeyword: '诛仙',
      ),
      isFalse,
    );
    expect(
      SearchInputHintHelper.shouldAutoSearchOnScopeChanged(
        isSearching: false,
        hasInputFocus: false,
        resultCount: 0,
        currentKeyword: '诛仙',
      ),
      isFalse,
    );
  });

  test('shouldAutoSearchOnScopeChanged: 输入帮助隐藏时自动搜索', () {
    expect(
      SearchInputHintHelper.shouldAutoSearchOnScopeChanged(
        isSearching: false,
        hasInputFocus: false,
        resultCount: 2,
        currentKeyword: '诛仙',
      ),
      isTrue,
    );
    expect(
      SearchInputHintHelper.shouldAutoSearchOnScopeChanged(
        isSearching: true,
        hasInputFocus: true,
        resultCount: 2,
        currentKeyword: '诛仙',
      ),
      isTrue,
      reason: '搜索中输入帮助层应隐藏，scope 变更可触发重搜',
    );
  });

  test('shouldConsumeBackToClearFocus: 输入框有焦点时先消费返回事件', () {
    expect(
      SearchInputHintHelper.shouldConsumeBackToClearFocus(
        hasInputFocus: true,
      ),
      isTrue,
    );
    expect(
      SearchInputHintHelper.shouldConsumeBackToClearFocus(
        hasInputFocus: false,
      ),
      isFalse,
    );
  });
}
