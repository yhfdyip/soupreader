import 'package:flutter/services.dart';

import '../models/reading_settings.dart';

class ReaderSystemUiConfig {
  final SystemUiMode mode;
  final List<SystemUiOverlay> overlays;

  const ReaderSystemUiConfig({
    required this.mode,
    required this.overlays,
  });
}

class ReaderSystemUiHelper {
  static const ReaderSystemUiConfig appDefault = ReaderSystemUiConfig(
    mode: SystemUiMode.manual,
    overlays: <SystemUiOverlay>[
      SystemUiOverlay.top,
      SystemUiOverlay.bottom,
    ],
  );

  static List<DeviceOrientation> resolvePreferredOrientations(
    int screenOrientation,
  ) {
    switch (screenOrientation) {
      case ReadingSettings.screenOrientationPortrait:
        return const <DeviceOrientation>[DeviceOrientation.portraitUp];
      case ReadingSettings.screenOrientationLandscape:
        return const <DeviceOrientation>[
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ];
      case ReadingSettings.screenOrientationSensor:
        return const <DeviceOrientation>[
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
          DeviceOrientation.portraitDown,
        ];
      case ReadingSettings.screenOrientationReversePortrait:
        return const <DeviceOrientation>[DeviceOrientation.portraitDown];
      case ReadingSettings.screenOrientationUnspecified:
      default:
        return const <DeviceOrientation>[];
    }
  }

  static ReaderSystemUiConfig resolveReaderUiConfig({
    required ReadingSettings settings,
    required bool showOverlay,
  }) {
    if (showOverlay) {
      return appDefault;
    }

    final overlays = <SystemUiOverlay>[];
    if (settings.showStatusBar) {
      overlays.add(SystemUiOverlay.top);
    }
    if (!settings.hideNavigationBar) {
      overlays.add(SystemUiOverlay.bottom);
    }
    return ReaderSystemUiConfig(
      mode: SystemUiMode.manual,
      overlays: overlays,
    );
  }
}
