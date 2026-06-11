// api_helper.dart
class ApiHelper {
  static String getBaseUrl() {
    // Use your ngrok URL
    return "https://lionlike-unambulant-yolanda.ngrok-free.dev";
  }

  static Uri analyserOrdonnanceUrl() {
    return Uri.parse("${getBaseUrl()}/analyser_ordonnance_url/");
  }
}