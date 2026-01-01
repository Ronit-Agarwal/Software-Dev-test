class NlpService {
  const NlpService();

  List<String> tokenize(String input) {
    final normalized = input
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9\s']"), ' ')
        .replaceAll(RegExp(r"\s+"), ' ')
        .trim();

    if (normalized.isEmpty) return const [];
    return normalized.split(' ');
  }

  String lemmatize(String token) {
    if (token.length <= 3) return token;

    // basic rules for English inflections
    if (token.endsWith('ies') && token.length > 4) {
      return '${token.substring(0, token.length - 3)}y';
    }

    if (token.endsWith('ing') && token.length > 5) {
      return token.substring(0, token.length - 3);
    }

    if (token.endsWith('ed') && token.length > 4) {
      return token.substring(0, token.length - 2);
    }

    if (token.endsWith('s') && token.length > 4) {
      return token.substring(0, token.length - 1);
    }

    return token;
  }
}
