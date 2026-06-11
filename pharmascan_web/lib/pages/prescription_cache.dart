class PrescriptionCache {
  static final Map<String, Map<String, dynamic>> _cache = {};

  static Map<String, dynamic>? get(String imageUrl) => _cache[imageUrl];

  static void set(String imageUrl, Map<String, dynamic> data) =>
      _cache[imageUrl] = data;
}
