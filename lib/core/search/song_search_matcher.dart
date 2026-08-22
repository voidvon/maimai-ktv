import 'package:pinyin_pro_flutter/pinyin_pro_flutter.dart';

import '../models/song.dart';

const MatchOptions _initialMatchOptions = MatchOptions(
  precision: MatchPrecision.first,
  lastPrecision: MatchPrecision.first,
  continuous: true,
);
final RegExp _initialQueryPattern = RegExp(r'^[a-z]+$');

bool matchesSongSearch(Song song, String query) {
  final String normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) {
    return true;
  }
  if (song.searchIndex.toLowerCase().contains(normalizedQuery)) {
    return true;
  }
  return matchesPinyinInitials(song.title, normalizedQuery) ||
      matchesPinyinInitials(song.artist, normalizedQuery);
}

bool matchesTextSearch(String text, String query, {String? exactSearchIndex}) {
  final String normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) {
    return true;
  }
  final String normalizedExactText = (exactSearchIndex ?? text).toLowerCase();
  if (normalizedExactText.contains(normalizedQuery)) {
    return true;
  }
  return matchesPinyinInitials(text, normalizedQuery);
}

bool matchesPinyinInitials(String text, String query) {
  final String normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty ||
      !_initialQueryPattern.hasMatch(normalizedQuery)) {
    return false;
  }

  final List<int>? matchedIndices = matchPinyin(
    text,
    normalizedQuery,
    options: _initialMatchOptions,
  );
  if (matchedIndices == null) {
    return false;
  }

  // matchPinyin also accepts complete syllables. Requiring exactly one query
  // letter per matched character keeps this feature initials-only.
  return _matchedRuneCount(text, matchedIndices) == normalizedQuery.length;
}

int _matchedRuneCount(String text, List<int> matchedCodeUnitIndices) {
  final Set<int> matchedIndices = matchedCodeUnitIndices.toSet();
  int codeUnitOffset = 0;
  int matchedRunes = 0;
  for (final int rune in text.runes) {
    final int codeUnitLength = rune > 0xffff ? 2 : 1;
    bool matched = false;
    for (int index = 0; index < codeUnitLength; index += 1) {
      if (matchedIndices.contains(codeUnitOffset + index)) {
        matched = true;
        break;
      }
    }
    if (matched) {
      matchedRunes += 1;
    }
    codeUnitOffset += codeUnitLength;
  }
  return matchedRunes;
}
