/// Text helpers for the on-device suggestion engine. Everything works on a
/// lower-cased, diacritic-free copy so "Đi chợ" ≡ "di cho".
library;

final Map<String, String> _fold = () {
  const groups = {
    'a': 'àáạảãâầấậẩẫăằắặẳẵäå',
    'e': 'èéẹẻẽêềếệểễë',
    'i': 'ìíịỉĩïî',
    'o': 'òóọỏõôồốộổỗơờớợởỡö',
    'u': 'ùúụủũưừứựửữüû',
    'y': 'ỳýỵỷỹÿ',
    'd': 'đ',
    'c': 'ç',
    'n': 'ñ',
  };
  return {
    for (final entry in groups.entries)
      for (final ch in entry.value.split('')) ch: entry.key,
  };
}();

/// Lower-cases and strips diacritics (precomposed and combining)
String foldText(String input) {
  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    // Combining marks (NFD input)
    if (rune >= 0x0300 && rune <= 0x036F) {
      continue;
    }
    final ch = String.fromCharCode(rune);
    buffer.write(_fold[ch] ?? ch);
  }
  return buffer.toString();
}

/// Function words that say nothing about what a task is. Matched BEFORE
/// folding: folded, "chợ" (market) would equal "cho" (for), "nhà" (house)
/// "nha", "thi" (exam) "thì", "dạ" (stomach) "đã".
const _stopWords = {
  // English
  'a', 'an', 'the', 'to', 'of', 'for', 'and', 'or', 'in', 'on', 'at', 'with',
  'my', 'your', 'is', 'are', 'be', 'this', 'that', 'it', 'some', 'up',
  // Vietnamese
  'và', 'với', 'cho', 'của', 'ở', 'tại', 'là', 'thì', 'mà', 'những', 'các',
  'một', 'nhé', 'nha', 'nhỉ', 'rồi', 'cần', 'phải', 'sẽ', 'đã', 'đang',
};

final _splitter = RegExp(r'[^\p{L}\p{M}\p{N}]+', unicode: true);

/// "eggs" → "egg", "vitamins" → "vitamin". Safe for Vietnamese: no
/// syllable ends in "s".
String _stem(String word) =>
    word.length > 3 && word.endsWith('s') && !word.endsWith('ss')
    ? word.substring(0, word.length - 1)
    : word;

/// Meaningful words of [text], folded, in order
List<String> words(String text) => [
  for (final raw in text.toLowerCase().split(_splitter))
    if (raw.isNotEmpty && !_stopWords.contains(raw)) _stem(foldText(raw)),
];

/// Words plus adjacent pairs. Vietnamese words are often two syllables
/// ("sieu thi", "bao cao"), so pairs carry most of the meaning.
List<String> features(String text) {
  final w = words(text);
  return [...w, for (var i = 0; i + 1 < w.length; i++) '${w[i]} ${w[i + 1]}'];
}

/// Character trigrams of the folded text (spaces collapsed), for fuzzy
/// matching that survives typos and word order
Set<String> trigrams(String text) {
  final s = ' ${words(text).join(' ')} ';
  return {for (var i = 0; i + 3 <= s.length; i++) s.substring(i, i + 3)};
}

/// |a ∩ b| / |a ∪ b|, 0 when both are empty
double jaccard(Set<Object> a, Set<Object> b) {
  if (a.isEmpty && b.isEmpty) {
    return 0;
  }
  final inter = a.where(b.contains).length;
  return inter / (a.length + b.length - inter);
}
