class ReceiptParseResult {
  const ReceiptParseResult({
    required this.rawText,
    this.description,
    this.amount,
    this.category,
  });

  final String rawText;
  final String? description;
  final double? amount;
  final String? category;
}

class ReceiptTextParser {
  static final RegExp _amountPattern = RegExp(
    r'(?:total|amount|sum|grand\s*total|balance due)?[^\d]{0,12}(\$?\d{1,6}(?:[.,]\d{2}))',
    caseSensitive: false,
  );

  static ReceiptParseResult parse(String rawText) {
    final String text = rawText.trim();
    if (text.isEmpty) {
      return const ReceiptParseResult(rawText: '');
    }

    final List<String> lines = text
        .split(RegExp(r'[\r\n]+'))
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty)
        .toList();

    double? amount;
    final Iterable<RegExpMatch> matches = _amountPattern.allMatches(text);
    for (final RegExpMatch match in matches) {
      final String? raw = match.group(1);
      if (raw == null) {
        continue;
      }
      final double? value = double.tryParse(raw.replaceAll('\$', '').replaceAll(',', '.'));
      if (value != null && value > 0) {
        amount = value;
      }
    }

    String? description;
    for (final String line in lines) {
      if (RegExp(r'^\$?\d').hasMatch(line)) {
        continue;
      }
      if (line.toLowerCase().contains('total') || line.toLowerCase().contains('amount')) {
        continue;
      }
      description = line.length > 48 ? '${line.substring(0, 48)}…' : line;
      break;
    }

    final String lower = text.toLowerCase();
    String? category;
    if (lower.contains('uber') || lower.contains('lyft') || lower.contains('taxi') || lower.contains('fuel')) {
      category = 'Transport';
    } else if (lower.contains('pharmacy') || lower.contains('clinic') || lower.contains('hospital')) {
      category = 'Health';
    } else if (lower.contains('restaurant') || lower.contains('cafe') || lower.contains('coffee') || lower.contains('food')) {
      category = 'Food';
    } else if (lower.contains('amazon') || lower.contains('store') || lower.contains('market')) {
      category = 'Shopping';
    }

    return ReceiptParseResult(
      rawText: text,
      description: description,
      amount: amount,
      category: category,
    );
  }
}
