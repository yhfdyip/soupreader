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

  test('ReadingSettings 使用 legado v2 正文排版默认值', () {
    const defaults = ReadingSettings();
    expect(defaults.layoutPresetVersion,
        ReadingSettings.layoutPresetVersionLegadoV2);
    expect(defaults.fontSize, ReadingSettings.legadoV2FontSize);
    expect(defaults.lineHeight, ReadingSettings.legadoV2LineHeight);
    expect(defaults.paragraphSpacing, ReadingSettings.legadoV2ParagraphSpacing);
    expect(defaults.paddingLeft, ReadingSettings.legadoV2PaddingHorizontal);
    expect(defaults.paddingRight, ReadingSettings.legadoV2PaddingHorizontal);
    expect(defaults.paddingTop, ReadingSettings.legadoV2PaddingVertical);
    expect(defaults.paddingBottom, ReadingSettings.legadoV2PaddingVertical);
  });

  test('ReadingSettings 迁移 v1 旧默认到 legado v2 并提升预设版本', () {
    final legacyDecoded = ReadingSettings.fromJson(<String, dynamic>{
      'layoutPresetVersion': ReadingSettings.layoutPresetVersionLegacy,
      'fontSize': ReadingSettings.legacyV1FontSize,
      'lineHeight': ReadingSettings.legacyV1LineHeight,
      'paragraphSpacing': ReadingSettings.legacyV1ParagraphSpacing,
      'marginHorizontal': ReadingSettings.legacyV1PaddingHorizontal,
      'marginVertical': ReadingSettings.legacyV1MarginVertical,
      'paddingLeft': ReadingSettings.legacyV1PaddingHorizontal,
      'paddingRight': ReadingSettings.legacyV1PaddingHorizontal,
      'paddingTop': ReadingSettings.legacyV1PaddingTop,
      'paddingBottom': ReadingSettings.legacyV1PaddingBottom,
      'headerPaddingLeft': ReadingSettings.legacyV1PaddingHorizontal,
      'headerPaddingRight': ReadingSettings.legacyV1PaddingHorizontal,
      'footerPaddingLeft': ReadingSettings.legacyV1PaddingHorizontal,
      'footerPaddingRight': ReadingSettings.legacyV1PaddingHorizontal,
    });

    expect(legacyDecoded.layoutPresetVersion,
        ReadingSettings.layoutPresetVersionLegadoV2);
    expect(legacyDecoded.fontSize, ReadingSettings.legadoV2FontSize);
    expect(legacyDecoded.lineHeight, ReadingSettings.legadoV2LineHeight);
    expect(legacyDecoded.paragraphSpacing,
        ReadingSettings.legadoV2ParagraphSpacing);
    expect(
        legacyDecoded.paddingLeft, ReadingSettings.legadoV2PaddingHorizontal);
    expect(
        legacyDecoded.paddingRight, ReadingSettings.legadoV2PaddingHorizontal);
    expect(legacyDecoded.paddingTop, ReadingSettings.legadoV2PaddingVertical);
    expect(
        legacyDecoded.paddingBottom, ReadingSettings.legadoV2PaddingVertical);
  });

  test('ReadingSettings 迁移时保留用户自定义排版', () {
    final customized = ReadingSettings.fromJson(<String, dynamic>{
      'layoutPresetVersion': ReadingSettings.layoutPresetVersionLegacy,
      'fontSize': 28.0,
      'lineHeight': 1.6,
      'paragraphSpacing': 9.0,
      'paddingLeft': 30.0,
      'paddingRight': 30.0,
      'paddingTop': 12.0,
      'paddingBottom': 10.0,
    });

    expect(customized.layoutPresetVersion,
        ReadingSettings.layoutPresetVersionLegadoV2);
    expect(customized.fontSize, 28.0);
    expect(customized.lineHeight, 1.6);
    expect(customized.paragraphSpacing, 9.0);
    expect(customized.paddingLeft, 30.0);
    expect(customized.paddingRight, 30.0);
    expect(customized.paddingTop, 12.0);
    expect(customized.paddingBottom, 10.0);
  });

  test('ReadingSettings keeps shareLayout defaults and survives json roundtrip',
      () {
    const defaults = ReadingSettings();
    expect(defaults.shareLayout, isTrue);

    final encoded = defaults.copyWith(shareLayout: false).toJson();
    final decoded = ReadingSettings.fromJson(encoded);
    expect(decoded.shareLayout, isFalse);

    final legacyDecoded = ReadingSettings.fromJson(<String, dynamic>{});
    expect(legacyDecoded.shareLayout, isTrue);
  });

  test(
      'ReadingSettings keeps brightnessViewOnRight defaults and survives json roundtrip',
      () {
    const defaults = ReadingSettings();
    expect(defaults.brightnessViewOnRight, isFalse);

    final encoded = defaults.copyWith(brightnessViewOnRight: true).toJson();
    final decoded = ReadingSettings.fromJson(encoded);
    expect(decoded.brightnessViewOnRight, isTrue);

    final legacyDecoded = ReadingSettings.fromJson(<String, dynamic>{});
    expect(legacyDecoded.brightnessViewOnRight, isFalse);
  });

  test('ReadingSettings migrates legacy keepScreenOn to keepLightSeconds', () {
    final defaults = ReadingSettings.fromJson(<String, dynamic>{});
    expect(defaults.keepLightSeconds, ReadingSettings.keepLightFollowSystem);
    expect(defaults.keepScreenOn, isFalse);

    final legacyAlways = ReadingSettings.fromJson(<String, dynamic>{
      'keepScreenOn': true,
    });
    expect(legacyAlways.keepLightSeconds, ReadingSettings.keepLightAlways);
    expect(legacyAlways.keepScreenOn, isTrue);

    final timed = ReadingSettings.fromJson(<String, dynamic>{
      'keepLightSeconds': ReadingSettings.keepLightFiveMinutes,
    });
    expect(timed.keepLightSeconds, ReadingSettings.keepLightFiveMinutes);
    expect(timed.keepScreenOn, isFalse);

    final copied = legacyAlways.copyWith(
      keepLightSeconds: ReadingSettings.keepLightOneMinute,
    );
    expect(copied.keepLightSeconds, ReadingSettings.keepLightOneMinute);
    expect(copied.keepScreenOn, isFalse);
  });

  test('ReadingSettings keeps readStyleConfigs and clamps themeIndex', () {
    final decoded = ReadingSettings.fromJson(<String, dynamic>{
      'themeIndex': 9,
      'readStyleConfigs': <Map<String, dynamic>>[
        <String, dynamic>{
          'name': '护眼',
          'backgroundColor': 0xFFFDF6E3,
          'textColor': 0xFF2D2D2D,
        },
      ],
    });
    expect(decoded.readStyleConfigs.length, 1);
    expect(decoded.themeIndex, 0);

    final roundtrip = ReadingSettings.fromJson(decoded.toJson());
    expect(roundtrip.readStyleConfigs.length, 1);
    expect(roundtrip.readStyleConfigs.first.name, '护眼');
    expect(roundtrip.themeIndex, 0);
  });

  test('ReadStyleConfig accepts legacy signed and hex color values', () {
    final config = ReadStyleConfig.fromJson(<String, dynamic>{
      'name': '夜间',
      'backgroundColor': '-16777216',
      'textColor': '#ADADAD',
    });
    expect(config.backgroundColor, 0xFF000000);
    expect(config.textColor, 0xFFADADAD);
  });

  test('ReadingSettings keeps legado-like pageTouchSlop range', () {
    final defaults = ReadingSettings.fromJson(<String, dynamic>{});
    expect(defaults.pageTouchSlop, 0);

    final custom = ReadingSettings.fromJson(<String, dynamic>{
      'pageTouchSlop': 4096,
    });
    expect(custom.pageTouchSlop, 4096);

    final invalid = ReadingSettings.fromJson(<String, dynamic>{
      'pageTouchSlop': 12000,
    });
    expect(invalid.pageTouchSlop, 0);
  });

  test('ReadingSettings keeps legado core switch defaults for O-04 step1', () {
    final defaults = ReadingSettings.fromJson(<String, dynamic>{});
    expect(defaults.hideNavigationBar, isFalse);
    expect(defaults.paddingDisplayCutouts, isFalse);
    expect(defaults.mouseWheelPage, isTrue);
    expect(defaults.keyPageOnLongPress, isFalse);
    expect(defaults.volumeKeyPageOnPlay, isTrue);
    expect(defaults.disableReturnKey, isFalse);
    expect(defaults.showReadTitleAddition, isTrue);
    expect(defaults.readBarStyleFollowPage, isFalse);
    expect(
      defaults.screenOrientation,
      ReadingSettings.screenOrientationUnspecified,
    );
  });

  test('ReadingSettings keeps legacy MoreConfig extra switches after roundtrip',
      () {
    final encoded = const ReadingSettings()
        .copyWith(
          paddingDisplayCutouts: true,
          volumeKeyPageOnPlay: false,
          showReadTitleAddition: false,
          readBarStyleFollowPage: true,
        )
        .toJson();
    final decoded = ReadingSettings.fromJson(encoded);
    expect(decoded.paddingDisplayCutouts, isTrue);
    expect(decoded.volumeKeyPageOnPlay, isFalse);
    expect(decoded.showReadTitleAddition, isFalse);
    expect(decoded.readBarStyleFollowPage, isTrue);
  });

  test('ReadingSettings sanitizes legacy screenOrientation range', () {
    final valid = ReadingSettings.fromJson(<String, dynamic>{
      'screenOrientation': 4,
    });
    expect(
      valid.screenOrientation,
      ReadingSettings.screenOrientationReversePortrait,
    );

    final invalid = ReadingSettings.fromJson(<String, dynamic>{
      'screenOrientation': 99,
    });
    expect(
      invalid.screenOrientation,
      ReadingSettings.screenOrientationUnspecified,
    );
  });

  test('ReadingSettings keeps legacy fixed pageAnimDuration', () {
    final defaults = ReadingSettings.fromJson(<String, dynamic>{});
    expect(
      defaults.pageAnimDuration,
      ReadingSettings.legacyPageAnimDuration,
    );

    final custom = ReadingSettings.fromJson(<String, dynamic>{
      'pageAnimDuration': 120,
    });
    expect(
      custom.pageAnimDuration,
      ReadingSettings.legacyPageAnimDuration,
    );

    final copied = defaults.copyWith(pageAnimDuration: 600);
    expect(
      copied.pageAnimDuration,
      ReadingSettings.legacyPageAnimDuration,
    );
  });

  test('ReadingSettings migrates legacy chineseTraditional to converter type',
      () {
    final legacyTrue = ReadingSettings.fromJson(<String, dynamic>{
      'chineseTraditional': true,
    });
    expect(
      legacyTrue.chineseConverterType,
      ChineseConverterType.simplifiedToTraditional,
    );

    final legacyFalse = ReadingSettings.fromJson(<String, dynamic>{
      'chineseTraditional': false,
    });
    expect(legacyFalse.chineseConverterType, ChineseConverterType.off);
  });

  test('ReadingSettings keeps chinese converter type after json roundtrip', () {
    const settings = ReadingSettings(
      chineseConverterType: ChineseConverterType.traditionalToSimplified,
    );
    final encoded = settings.toJson();
    final decoded = ReadingSettings.fromJson(encoded);
    expect(
      decoded.chineseConverterType,
      ChineseConverterType.traditionalToSimplified,
    );
    expect(decoded.chineseTraditional, isFalse);
  });

  test('ClickAction uses legado default 9-grid mapping', () {
    final normalized = ClickAction.normalizeConfig(const <String, int>{});
    expect(
      normalized,
      equals(<String, int>{
        'tl': ClickAction.prevPage,
        'tc': ClickAction.prevPage,
        'tr': ClickAction.nextPage,
        'ml': ClickAction.prevPage,
        'mc': ClickAction.showMenu,
        'mr': ClickAction.nextPage,
        'bl': ClickAction.prevPage,
        'bc': ClickAction.nextPage,
        'br': ClickAction.nextPage,
      }),
    );
  });

  test('ClickAction auto recovers middle menu when all zones are non-menu', () {
    final noMenu = <String, int>{
      'tl': ClickAction.nextPage,
      'tc': ClickAction.nextPage,
      'tr': ClickAction.nextPage,
      'ml': ClickAction.nextPage,
      'mc': ClickAction.prevPage,
      'mr': ClickAction.nextPage,
      'bl': ClickAction.nextPage,
      'bc': ClickAction.nextPage,
      'br': ClickAction.nextPage,
    };
    expect(ClickAction.hasMenuZone(noMenu), isFalse);

    final normalized = ClickAction.normalizeConfig(noMenu);
    expect(ClickAction.hasMenuZone(normalized), isTrue);
    expect(normalized['mc'], ClickAction.showMenu);
  });

  test('ReadingSettings sanitizes click actions with legado action set', () {
    final decoded = ReadingSettings.fromJson(<String, dynamic>{
      'clickActions': <String, int>{
        'mc': ClickAction.off,
        'tl': 99,
        'tr': ClickAction.off,
        'bc': ClickAction.searchContent,
      },
    });

    expect(decoded.clickActions['tl'], ClickAction.showMenu);
    expect(decoded.clickActions['tr'], ClickAction.off);
    expect(decoded.clickActions['bc'], ClickAction.searchContent);
    expect(decoded.clickActions['mc'], ClickAction.off);
    expect(ClickAction.hasMenuZone(decoded.clickActions), isTrue);
  });

  test('ReadingSettings keeps legado-like header/footer mode defaults', () {
    const defaults = ReadingSettings();
    expect(
      defaults.headerMode,
      ReadingSettings.headerModeHideWhenStatusBarShown,
    );
    expect(defaults.footerMode, ReadingSettings.footerModeShow);
    expect(defaults.showHeaderLine, isFalse);
    expect(defaults.showFooterLine, isTrue);
    expect(defaults.shouldShowHeader(showStatusBar: true), isFalse);
    expect(defaults.shouldShowHeader(showStatusBar: false), isTrue);
    expect(defaults.shouldShowFooter(), isTrue);
  });

  test('ReadingSettings normalizes pageDirection with pageTurnMode', () {
    final scrollMode = ReadingSettings.fromJson(<String, dynamic>{
      'pageTurnMode': PageTurnMode.scroll.index,
      'pageDirection': PageDirection.horizontal.index,
    });
    expect(scrollMode.pageDirection, PageDirection.vertical);

    final coverMode = ReadingSettings.fromJson(<String, dynamic>{
      'pageTurnMode': PageTurnMode.cover.index,
      'pageDirection': PageDirection.vertical.index,
    });
    expect(coverMode.pageDirection, PageDirection.horizontal);

    final copied = scrollMode.copyWith(
      pageTurnMode: PageTurnMode.cover,
      pageDirection: PageDirection.vertical,
    );
    expect(copied.pageDirection, PageDirection.horizontal);
  });

  test('ReadingSettings migrates legacy hideHeader/hideFooter to mode fields',
      () {
    final hideAll = ReadingSettings.fromJson(<String, dynamic>{
      'hideHeader': true,
      'hideFooter': true,
    });
    expect(hideAll.headerMode, ReadingSettings.headerModeHide);
    expect(hideAll.footerMode, ReadingSettings.footerModeHide);

    final showAll = ReadingSettings.fromJson(<String, dynamic>{
      'hideHeader': false,
      'hideFooter': false,
    });
    expect(showAll.headerMode, ReadingSettings.headerModeShow);
    expect(showAll.footerMode, ReadingSettings.footerModeShow);

    final explicitMode = ReadingSettings.fromJson(<String, dynamic>{
      'headerMode': ReadingSettings.headerModeHideWhenStatusBarShown,
      'hideHeader': true,
    });
    expect(
      explicitMode.headerMode,
      ReadingSettings.headerModeHideWhenStatusBarShown,
    );
  });

  test('ReadingSettings sanitizes tip color fields with legacy signed ints',
      () {
    final decoded = ReadingSettings.fromJson(<String, dynamic>{
      'tipColor': -16711936, // legacy signed 0xFF00FF00
      'tipDividerColor': -15584170, // legacy signed 0xFF123456
    });
    expect(decoded.tipColor, 0xFF00FF00);
    expect(decoded.tipDividerColor, 0xFF123456);

    final roundtrip = ReadingSettings.fromJson(decoded.toJson());
    expect(roundtrip.tipColor, 0xFF00FF00);
    expect(roundtrip.tipDividerColor, 0xFF123456);
  });
}
