class ListCodec {
  ListCodec._();

  static String encode(List<String> values) {
    return values.map((String value) => value.trim()).where((String value) => value.isNotEmpty).join('|');
  }

  static List<String> decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return <String>[];
    }
    return raw.split('|').map((String value) => value.trim()).where((String value) => value.isNotEmpty).toList();
  }
}
