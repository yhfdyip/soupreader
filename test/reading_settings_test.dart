import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/features/reader/models/reading_settings.dart';

void main() {
  test('PageTurnModeUi uses legado-like display order', () {
    expect(
      PageTurnModeUi.values(current: PageTurnMode.cover),
      equals(<PageTurnMode>[
        PageTurnMode.cover,
        PageTurnMode.slide,
        PageTurnMode.simulation,
        PageTurnMode.scroll,
        PageTurnMode.none,
      ]),
    );
  });

  test('PageTurnModeUi keeps hidden simulation2 visible when selected', () {
    expect(
      PageTurnModeUi.values(current: PageTurnMode.simulation2),
      equals(<PageTurnMode>[
        PageTurnMode.cover,
        PageTurnMode.slide,
        PageTurnMode.simulation,
        PageTurnMode.simulation2,
        PageTurnMode.scroll,
        PageTurnMode.none,
      ]),
    );
  });

  test('ReadingSettings noAnimScrollPage defaults and survives json roundtrip',
      () {
    const defaults = ReadingSettings();
    expect(defaults.noAnimScrollPage, isFalse);

    final encoded = defaults.copyWith(noAnimScrollPage: true).toJson();
    final decoded = ReadingSettings.fromJson(encoded);
    expect(decoded.noAnimScrollPage, isTrue);

    final legacyDecoded = ReadingSettings.fromJson(<String, dynamic>{});
    expect(legacyDecoded.noAnimScrollPage, isFalse);
  });
}
