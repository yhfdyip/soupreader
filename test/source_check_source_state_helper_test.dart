import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/source_check_source_state_helper.dart';

void main() {
  group('SourceCheckSourceStateHelper', () {
    BookSource source({
      String? group,
      String? comment,
    }) {
      return BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '示例',
        bookSourceGroup: group,
        bookSourceComment: comment,
      );
    }

    test('splitGroups 支持逗号与分号分隔并去重', () {
      expect(
        SourceCheckSourceStateHelper.splitGroups('A, B；C;A，D'),
        ['A', 'B', 'C', 'D'],
      );
    });

    test('applyGroupMutations 可增删分组', () {
      final current = source(group: '搜索失效,旧分组');
      final updated = SourceCheckSourceStateHelper.applyGroupMutations(
        current,
        add: const {'发现失效'},
        remove: const {'搜索失效'},
      );
      expect(
        SourceCheckSourceStateHelper.splitGroups(updated.bookSourceGroup),
        ['旧分组', '发现失效'],
      );
    });

    test('removeInvalidGroups 仅移除失效与超时分组', () {
      final current = source(group: '搜索失效,校验超时,常用');
      final updated = SourceCheckSourceStateHelper.removeInvalidGroups(current);
      expect(
        SourceCheckSourceStateHelper.splitGroups(updated.bookSourceGroup),
        ['常用'],
      );
    });

    test('removeErrorComment 移除错误前缀块并保持普通备注', () {
      final current = source(
        comment: '// Error: fail one\n\n保留备注\n\n// Error: fail two',
      );
      final updated = SourceCheckSourceStateHelper.removeErrorComment(current);
      expect(updated.bookSourceComment, '保留备注');
    });

    test('addErrorComment 按前插语义写入', () {
      final current = source(comment: '原备注');
      final updated = SourceCheckSourceStateHelper.addErrorComment(
        current,
        '网络失败',
      );
      expect(updated.bookSourceComment, '// Error: 网络失败\n\n原备注');
    });

    test('prepareForCheck 同时清理无效分组与错误备注', () {
      final current = source(
        group: '发现失效,日常',
        comment: '// Error: old\n\n业务备注',
      );
      final updated = SourceCheckSourceStateHelper.prepareForCheck(current);
      expect(
        SourceCheckSourceStateHelper.splitGroups(updated.bookSourceGroup),
        ['日常'],
      );
      expect(updated.bookSourceComment, '业务备注');
    });

    test('invalidGroupNames 返回失效分组列表', () {
      expect(
        SourceCheckSourceStateHelper.invalidGroupNames('A,搜索失效,校验超时'),
        '搜索失效,校验超时',
      );
    });
  });
}
