import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/app/widgets/option_picker_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('OptionPickerSheet 点击选项后返回选中值', (tester) async {
    String? selected;

    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Builder(
            builder: (context) => Center(
              child: CupertinoButton(
                onPressed: () async {
                  selected = await showOptionPickerSheet<String>(
                    context: context,
                    title: '选择字体',
                    currentValue: '系统字体',
                    items: const [
                      OptionPickerItem<String>(
                        value: '系统字体',
                        label: '系统字体',
                      ),
                      OptionPickerItem<String>(
                        value: '思源宋体',
                        label: '思源宋体',
                      ),
                    ],
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('选择字体'), findsOneWidget);
    expect(find.text('系统字体'), findsOneWidget);
    expect(find.text('思源宋体'), findsOneWidget);

    await tester.tap(find.text('思源宋体').last);
    await tester.pumpAndSettle();

    expect(selected, '思源宋体');
  });

  testWidgets('OptionPickerSheet 点击取消返回 null', (tester) async {
    String? selected = 'initial';

    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Builder(
            builder: (context) => Center(
              child: CupertinoButton(
                onPressed: () async {
                  selected = await showOptionPickerSheet<String>(
                    context: context,
                    title: '选择编码',
                    currentValue: 'UTF-8',
                    items: const [
                      OptionPickerItem<String>(
                        value: 'UTF-8',
                        label: 'UTF-8',
                      ),
                      OptionPickerItem<String>(
                        value: 'GBK',
                        label: 'GBK',
                      ),
                    ],
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(selected, isNull);
  });
}
