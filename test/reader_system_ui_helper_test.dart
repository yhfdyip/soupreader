import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/features/reader/models/reading_settings.dart';
import 'package:soupreader/features/reader/services/reader_system_ui_helper.dart';

void main() {
  test('resolvePreferredOrientations maps legado screenOrientation values', () {
    expect(
      ReaderSystemUiHelper.resolvePreferredOrientations(
        ReadingSettings.screenOrientationUnspecified,
      ),
      isEmpty,
    );

    expect(
      ReaderSystemUiHelper.resolvePreferredOrientations(
        ReadingSettings.screenOrientationPortrait,
      ),
      equals(const <DeviceOrientation>[DeviceOrientation.portraitUp]),
    );

    expect(
      ReaderSystemUiHelper.resolvePreferredOrientations(
        ReadingSettings.screenOrientationLandscape,
      ),
      equals(const <DeviceOrientation>[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]),
    );

    expect(
      ReaderSystemUiHelper.resolvePreferredOrientations(
        ReadingSettings.screenOrientationSensor,
      ),
      equals(const <DeviceOrientation>[
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
        DeviceOrientation.portraitDown,
      ]),
    );

    expect(
      ReaderSystemUiHelper.resolvePreferredOrientations(
        ReadingSettings.screenOrientationReversePortrait,
      ),
      equals(const <DeviceOrientation>[DeviceOrientation.portraitDown]),
    );
  });

  test('resolveReaderUiConfig keeps system bars visible when menu is open', () {
    const settings = ReadingSettings(
      showStatusBar: false,
      hideNavigationBar: true,
    );

    final config = ReaderSystemUiHelper.resolveReaderUiConfig(
      settings: settings,
      showOverlay: true,
    );

    expect(config.mode, SystemUiMode.manual);
    expect(
      config.overlays,
      equals(const <SystemUiOverlay>[
        SystemUiOverlay.top,
        SystemUiOverlay.bottom,
      ]),
    );
  });

  test('resolveReaderUiConfig follows hideNavigationBar/showStatusBar matrix',
      () {
    final keepAll = ReaderSystemUiHelper.resolveReaderUiConfig(
      settings: const ReadingSettings(
        showStatusBar: true,
        hideNavigationBar: false,
      ),
      showOverlay: false,
    );
    expect(
      keepAll.overlays,
      equals(const <SystemUiOverlay>[
        SystemUiOverlay.top,
        SystemUiOverlay.bottom,
      ]),
    );

    final hideTopOnly = ReaderSystemUiHelper.resolveReaderUiConfig(
      settings: const ReadingSettings(
        showStatusBar: false,
        hideNavigationBar: false,
      ),
      showOverlay: false,
    );
    expect(
      hideTopOnly.overlays,
      equals(const <SystemUiOverlay>[SystemUiOverlay.bottom]),
    );

    final hideBottomOnly = ReaderSystemUiHelper.resolveReaderUiConfig(
      settings: const ReadingSettings(
        showStatusBar: true,
        hideNavigationBar: true,
      ),
      showOverlay: false,
    );
    expect(
      hideBottomOnly.overlays,
      equals(const <SystemUiOverlay>[SystemUiOverlay.top]),
    );

    final hideAll = ReaderSystemUiHelper.resolveReaderUiConfig(
      settings: const ReadingSettings(
        showStatusBar: false,
        hideNavigationBar: true,
      ),
      showOverlay: false,
    );
    expect(hideAll.overlays, isEmpty);
  });
}
