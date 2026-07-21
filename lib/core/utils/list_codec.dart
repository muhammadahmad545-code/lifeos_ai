class ListCodec {
  ListCodec._();

  static String encode(List<String> values) {
    return values.where((String value) => value.trim().isNotEmpty).join('|');
  }

  static List<String> decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return <String>[];
    }
    return raw.split('|').where((String value) => value.trim().isNotEmpty).toList();
  }
}
