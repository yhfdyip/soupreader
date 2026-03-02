class BuildInfo {
  BuildInfo._();

  static const String gitSha = String.fromEnvironment(
    'GIT_SHA',
    defaultValue: 'unknown',
  );

  static const String gitRef = String.fromEnvironment(
    'GIT_REF',
    defaultValue: 'unknown',
  );

  static const String buildNumber = String.fromEnvironment(
    'BUILD_NUMBER',
    defaultValue: 'unknown',
  );

  static const bool isRelease = bool.fromEnvironment('dart.vm.product');

  static String get gitShaShort {
    final sha = gitSha.trim();
    if (sha.length <= 8) return sha;
    return sha.substring(0, 8);
  }
}
