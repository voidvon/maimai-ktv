class ParsedSongMetadata {
  const ParsedSongMetadata({
    required this.title,
    required this.artist,
    this.languages = const <String>['其它'],
    this.tags = const <String>[],
  });

  final String title;
  final String artist;
  final List<String> languages;
  final List<String> tags;
}

class SongMetadataParser {
  const SongMetadataParser();

  static const List<String> _artistHyphenWhitelist = <String>[
    'A-Lin',
    'G-DRAGON',
    'T-ara',
  ];

  static const Map<String, String> _languageKeywordMap = <String, String>{
    '国语': '国语',
    '普通话': '国语',
    '华语': '国语',
    '粤语': '粤语',
    '广东话': '粤语',
    '白话': '粤语',
    '闽南语': '闽南语',
    '闽南话': '闽南语',
    '台语': '闽南语',
    '福建话': '闽南语',
    '英语': '英语',
    '英文': '英语',
    '日语': '日语',
    '日文': '日语',
    '韩语': '韩语',
    '韩文': '韩语',
    '客语': '客语',
    '客家话': '客语',
  };

  static const Map<String, String> _tagKeywordMap = <String, String>{
    '流行': '流行',
    '流行音乐': '流行',
    '流行歌曲': '流行',
    '经典': '经典',
    '经典老歌': '经典',
    '怀旧': '经典',
    '摇滚': '摇滚',
    '摇滚乐': '摇滚',
    '民谣': '民谣',
    '校园民谣': '民谣',
    '舞曲': '舞曲',
    '劲爆': '舞曲',
    '嗨歌': '舞曲',
    'dj': 'DJ',
    '电音': 'DJ',
    '情歌': '情歌',
    '抒情': '情歌',
    '儿歌': '儿歌',
    '童谣': '儿歌',
    '戏曲': '戏曲',
    '黄梅戏': '戏曲',
    '京剧': '戏曲',
    '越剧': '戏曲',
    '对唱': '对唱',
    '合唱': '合唱',
    '现场版': '现场版',
    'live': 'Live',
    '演唱会': '演唱会',
    'mv': 'MV',
    '伴奏版': '伴奏版',
    '原版': '原版',
    '重制版': '重制版',
    '单音轨': '单音轨',
    '双音轨': '双音轨',
  };

  ParsedSongMetadata parseFileName(String fileName) {
    final int dotIndex = fileName.lastIndexOf('.');
    final String baseName = dotIndex == -1
        ? fileName
        : fileName.substring(0, dotIndex);

    final List<String> segments = _splitSegments(baseName);
    if (segments.length < 2) {
      return ParsedSongMetadata(title: baseName.trim(), artist: '未识别歌手');
    }

    final int artistSegmentCount = _resolveArtistSegmentCount(segments);
    final String artist = segments.take(artistSegmentCount).join('-').trim();
    if (artist.isEmpty) {
      return ParsedSongMetadata(title: baseName.trim(), artist: '未识别歌手');
    }

    final List<String> reversedLanguages = <String>[];
    final List<String> reversedTags = <String>[];
    int titleEndExclusive = segments.length;
    for (
      int index = segments.length - 1;
      index >= artistSegmentCount;
      index--
    ) {
      final String strippedKeyword = _stripTrailingNoise(
        segments[index].trim(),
      );
      if (strippedKeyword.isEmpty) {
        titleEndExclusive = index;
        continue;
      }
      final String? normalizedKeyword = _normalizeKeyword(strippedKeyword);
      if (normalizedKeyword == null) {
        break;
      }
      final String? language = _languageKeywordMap[normalizedKeyword];
      if (language != null) {
        _appendUnique(reversedLanguages, language);
        titleEndExclusive = index;
        continue;
      }
      final String? tag = _tagKeywordMap[normalizedKeyword];
      if (tag != null) {
        _appendUnique(reversedTags, tag);
        titleEndExclusive = index;
        continue;
      }
      break;
    }

    final List<String> titleSegments = segments.sublist(
      artistSegmentCount,
      titleEndExclusive,
    );
    final String title = titleSegments.join('-').trim();
    return ParsedSongMetadata(
      title: title.isEmpty ? baseName.trim() : title,
      artist: artist,
      languages: reversedLanguages.isEmpty
          ? const <String>['其它']
          : reversedLanguages.reversed.toList(growable: false),
      tags: reversedTags.reversed.toList(growable: false),
    );
  }

  List<String> _splitSegments(String baseName) {
    final String normalized = baseName
        .replaceAll(' - ', '-')
        .replaceAll(' — ', '-')
        .replaceAll(' – ', '-')
        .trim();
    return normalized
        .split('-')
        .map((String segment) => segment.trim())
        .where((String segment) => segment.isNotEmpty)
        .toList(growable: false);
  }

  int _resolveArtistSegmentCount(List<String> segments) {
    for (int count = segments.length - 1; count >= 1; count--) {
      final String candidate = segments.take(count).join('-');
      if (_artistHyphenWhitelist.contains(candidate) &&
          segments.length - count >= 1) {
        return count;
      }
    }
    return 1;
  }

  String? _normalizeKeyword(String rawSegment) {
    String normalized = rawSegment.trim();
    if (normalized.isEmpty) {
      return null;
    }
    normalized = _normalizeFullWidth(normalized)
        .replaceAll('國語', '国语')
        .replaceAll('粵語', '粤语')
        .replaceAll('廣東話', '广东话')
        .replaceAll('閩南語', '闽南语')
        .replaceAll('閩南話', '闽南话')
        .replaceAll('臺語', '台语')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.isEmpty) {
      return null;
    }
    return normalized.toLowerCase();
  }

  String _stripTrailingNoise(String rawSegment) {
    String value = rawSegment.trim();
    if (value.isEmpty) {
      return value;
    }
    final List<RegExp> patterns = <RegExp>[
      RegExp(r'[_ ]?副本(?:\(\d+\))?$', caseSensitive: false),
      RegExp(r'[_ ]?copy$', caseSensitive: false),
      RegExp(r'\(\d+\)$'),
    ];
    bool changed = true;
    while (changed && value.isNotEmpty) {
      changed = false;
      for (final RegExp pattern in patterns) {
        final String nextValue = value.replaceFirst(pattern, '').trim();
        if (nextValue != value) {
          value = nextValue;
          changed = true;
        }
      }
    }
    return value;
  }

  String _normalizeFullWidth(String input) {
    final StringBuffer buffer = StringBuffer();
    for (final int codePoint in input.runes) {
      if (codePoint == 0x3000) {
        buffer.writeCharCode(0x20);
        continue;
      }
      if (codePoint >= 0xFF01 && codePoint <= 0xFF5E) {
        buffer.writeCharCode(codePoint - 0xFEE0);
        continue;
      }
      buffer.writeCharCode(codePoint);
    }
    return buffer.toString();
  }

  void _appendUnique(List<String> values, String value) {
    if (!values.contains(value)) {
      values.add(value);
    }
  }
}
