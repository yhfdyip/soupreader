import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/search/services/search_book_info_menu_helper.dart';

void main() {
  group('SearchBookInfoMenuHelper.shouldShowLogin', () {
    test('loginUrl 为空时不显示登录入口', () {
      expect(
        SearchBookInfoMenuHelper.shouldShowLogin(loginUrl: null),
        isFalse,
      );
      expect(
        SearchBookInfoMenuHelper.shouldShowLogin(loginUrl: ''),
        isFalse,
      );
      expect(
        SearchBookInfoMenuHelper.shouldShowLogin(loginUrl: '   '),
        isFalse,
      );
    });

    test('loginUrl 非空时显示登录入口', () {
      expect(
        SearchBookInfoMenuHelper.shouldShowLogin(
          loginUrl: 'https://login.example.com',
        ),
        isTrue,
      );
    });
  });
}
