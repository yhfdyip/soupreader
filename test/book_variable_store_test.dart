import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soupreader/core/services/book_variable_store.dart';

void main() {
  test('BookVariableStore 保存并读取书籍变量', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    expect(await BookVariableStore.getVariable('book://1'), isNull);

    await BookVariableStore.putVariable('book://1', '{"custom":"value"}');
    expect(
      await BookVariableStore.getVariable('book://1'),
      '{"custom":"value"}',
    );
  });

  test('BookVariableStore 写入空白字符串时保留变量', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'bookVariable_book://2': 'legacy',
    });

    expect(await BookVariableStore.getVariable('book://2'), 'legacy');
    await BookVariableStore.putVariable('book://2', '   ');
    expect(await BookVariableStore.getVariable('book://2'), '   ');
  });

  test('BookVariableStore 仅在写入 null 时删除变量', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'bookVariable_book://4': 'legacy',
    });

    await BookVariableStore.putVariable('book://4', null);
    expect(await BookVariableStore.getVariable('book://4'), isNull);
  });

  test('BookVariableStore 可显式移除变量', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'bookVariable_book://3': 'cached',
    });

    await BookVariableStore.removeVariable('book://3');
    expect(await BookVariableStore.getVariable('book://3'), isNull);
  });
}
