import 'dart:convert';

import '../models/app_settings.dart';
import 'settings_service_context.dart';

mixin SettingsServiceCodecMixin on SettingsServiceContext {
  DecodedAppSettings decodeAppSettings(Map<String, dynamic> rawJson) {
    final settings = AppSettings.fromJson(rawJson);
    final rawUpdateToVariant = rawJson['updateToVariant']?.toString().trim() ??
        AppSettings.defaultUpdateToVariant;
    final normalizedUpdateToVariant =
        AppSettings.normalizeUpdateToVariant(rawUpdateToVariant);
    final normalizedModeValue =
        resolveAppAppearanceModeLegacyValueFromJson(rawJson);
    final parsedThemeMode =
        tryParseAppAppearanceModeLegacyValue(rawJson['themeMode']);
    final parsedAppearanceMode =
        tryParseAppAppearanceModeLegacyValue(rawJson['appearanceMode']);
    final hasThemeMode = rawJson.containsKey('themeMode');
    final hasAppearanceMode = rawJson.containsKey('appearanceMode');
    final isValidThemeMode = parsedThemeMode != null &&
        isValidAppAppearanceModeLegacyValue(parsedThemeMode);
    final isValidAppearanceMode = parsedAppearanceMode != null &&
        isValidAppAppearanceModeLegacyValue(parsedAppearanceMode);
    final validThemeModeValue = isValidThemeMode ? parsedThemeMode : null;
    final validAppearanceModeValue =
        isValidAppearanceMode ? parsedAppearanceMode : null;
    final isLegacyThreeValueConfig = !hasThemeMode &&
        validAppearanceModeValue != null &&
        validAppearanceModeValue <= appAppearanceModeLegacyTriValueMax;
    final themeModeNeedsNormalize = !hasThemeMode ||
        validThemeModeValue == null ||
        validThemeModeValue != normalizedModeValue;
    final appearanceModeNeedsNormalize = !hasAppearanceMode ||
        validAppearanceModeValue == null ||
        validAppearanceModeValue != normalizedModeValue;

    return DecodedAppSettings(
      settings: settings,
      needsRewrite: isLegacyThreeValueConfig ||
          themeModeNeedsNormalize ||
          appearanceModeNeedsNormalize ||
          rawUpdateToVariant != normalizedUpdateToVariant,
    );
  }

  Map<String, bool> decodeBoolMap(String? rawJson) {
    if (rawJson == null || rawJson.trim().isEmpty) {
      return <String, bool>{};
    }
    try {
      final decoded = json.decode(rawJson);
      if (decoded is! Map) return <String, bool>{};
      final out = <String, bool>{};
      decoded.forEach((rawKey, rawValue) {
        final key = '$rawKey'.trim();
        if (key.isEmpty) return;
        if (rawValue is bool) {
          out[key] = rawValue;
          return;
        }
        if (rawValue is num) {
          out[key] = rawValue != 0;
          return;
        }
        if (rawValue is String) {
          final normalized = rawValue.trim().toLowerCase();
          if (normalized == 'true' || normalized == '1') {
            out[key] = true;
            return;
          }
          if (normalized == 'false' || normalized == '0') {
            out[key] = false;
          }
        }
      });
      return out;
    } catch (_) {
      return <String, bool>{};
    }
  }

  Future<void> persistBoolMap(String key, Map<String, bool> value) async {
    if (!isInitializedState) return;
    await prefsStoreState.setString(key, json.encode(value));
  }

  Map<String, int> decodeIntMap(String? rawJson) {
    if (rawJson == null || rawJson.trim().isEmpty) {
      return <String, int>{};
    }
    try {
      final decoded = json.decode(rawJson);
      if (decoded is! Map) return <String, int>{};
      final out = <String, int>{};
      decoded.forEach((rawKey, rawValue) {
        final key = '$rawKey'.trim();
        if (key.isEmpty) return;
        if (rawValue is int) {
          out[key] = rawValue;
          return;
        }
        if (rawValue is num) {
          out[key] = rawValue.round();
          return;
        }
        if (rawValue is String) {
          final parsed = int.tryParse(rawValue.trim());
          if (parsed != null) {
            out[key] = parsed;
          }
        }
      });
      return out;
    } catch (_) {
      return <String, int>{};
    }
  }

  Future<void> persistIntMap(String key, Map<String, int> value) async {
    if (!isInitializedState) return;
    await prefsStoreState.setString(key, json.encode(value));
  }

  Map<String, String> decodeStringMap(String? rawJson) {
    if (rawJson == null || rawJson.trim().isEmpty) {
      return <String, String>{};
    }
    try {
      final decoded = json.decode(rawJson);
      if (decoded is! Map) return <String, String>{};
      final out = <String, String>{};
      decoded.forEach((rawKey, rawValue) {
        final key = '$rawKey'.trim();
        final value = '$rawValue'.trim();
        if (key.isEmpty || value.isEmpty) return;
        out[key] = value;
      });
      return out;
    } catch (_) {
      return <String, String>{};
    }
  }

  Future<void> persistStringMap(String key, Map<String, String> value) async {
    if (!isInitializedState) return;
    await prefsStoreState.setString(key, json.encode(value));
  }

  int normalizeReadRecordSort(int value) {
    if (value == 1 || value == 2) return value;
    return 0;
  }
}
