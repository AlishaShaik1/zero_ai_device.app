abstract class TranslationService {
  Future<String> translate(String text, String from, String to);
  Future<String> detectLanguage(String text);
}

class MockTranslationService implements TranslationService {
  @override
  Future<String> translate(String text, String from, String to) async {
    // Note: User requested not to use the unofficial translator package.
    // In a production app, plug in Google Translate REST API, ML Kit, or offline translation here.
    return text;
  }

  @override
  Future<String> detectLanguage(String text) async {
    // Defaulting to English for mock
    return 'en_US';
  }
}
