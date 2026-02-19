import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/reader/models/reading_settings.dart';

void main() {
  const shaderAssetPath = 'lib/features/reader/shaders/page_curl.frag';

  test('simulation mode remains visible in page turn modes', () {
    final modes = PageTurnModeUi.values(current: PageTurnMode.cover);
    expect(modes.contains(PageTurnMode.simulation), isTrue);
    expect(PageTurnModeUi.isHidden(PageTurnMode.simulation), isFalse);
  });

  test('pubspec keeps page curl shader asset declaration', () {
    final text = File('pubspec.yaml').readAsStringSync();
    expect(text.contains(shaderAssetPath), isTrue);
  });

  test('paged reader still loads page curl shader by asset path', () {
    final text = File(
      'lib/features/reader/widgets/paged_reader_widget.dart',
    ).readAsStringSync();
    expect(text.contains("FragmentProgram.fromAsset("), isTrue);
    expect(text.contains("'$shaderAssetPath'"), isTrue);
  });
}
