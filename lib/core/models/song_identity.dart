String buildAggregateSongId({required String title, required String artist}) {
  final String normalizedTitle = normalizeSongIdentityPart(title);
  final String normalizedArtist = normalizeSongIdentityPart(artist);
  return '$normalizedTitle::$normalizedArtist';
}

String buildLocalSourceSongId({required String fingerprint}) {
  return 'local::$fingerprint';
}

String buildLocalMetadataFingerprint({
  required String locator,
  int? fileSize,
  int? modifiedAtMillis,
}) {
  final String normalizedLocator = normalizeSongIdentityPart(
    locator.replaceAll('\\', '/'),
  );
  final String sizePart = fileSize?.toString() ?? '';
  final String modifiedPart = modifiedAtMillis?.toString() ?? '';
  return 'meta::$normalizedLocator::$sizePart::$modifiedPart';
}

String normalizeSongIdentityPart(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('（', '(')
      .replaceAll('）', ')')
      .replaceAll(RegExp(r'\s+'), ' ');
}
