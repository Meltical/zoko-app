const _foldedChars = {
  'à': 'a',
  'â': 'a',
  'ä': 'a',
  'á': 'a',
  'ã': 'a',
  'å': 'a',
  'ç': 'c',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'î': 'i',
  'ï': 'i',
  'í': 'i',
  'ì': 'i',
  'ô': 'o',
  'ö': 'o',
  'ó': 'o',
  'ò': 'o',
  'õ': 'o',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ú': 'u',
  'ÿ': 'y',
  'ñ': 'n',
  'œ': 'oe',
  'æ': 'ae',
};

final _alphanumeric = RegExp(r'[a-z0-9]');

/// Mots en minuscules, sans accents ni ponctuation, ramenés au singulier
/// (« Pavés de Saumon » → [pave, de, saumon]).
List<String> searchTokens(String input) {
  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_foldedChars[char] ?? (_alphanumeric.hasMatch(char) ? char : ' '));
  }
  return [
    for (final token in buffer.toString().split(' '))
      if (token.isNotEmpty) _singular(token),
  ];
}

String normalizeText(String input) => searchTokens(input).join(' ');

String _singular(String token) =>
    token.length > 3 && (token.endsWith('s') || token.endsWith('x')) ? token.substring(0, token.length - 1) : token;

bool containsSequence(List<String> haystack, List<String> needle) {
  if (needle.isEmpty || needle.length > haystack.length) return false;
  outer:
  for (var start = 0; start <= haystack.length - needle.length; start++) {
    for (var i = 0; i < needle.length; i++) {
      if (haystack[start + i] != needle[i]) continue outer;
    }
    return true;
  }
  return false;
}

String capitalize(String input) => input.isEmpty ? input : input[0].toUpperCase() + input.substring(1);
