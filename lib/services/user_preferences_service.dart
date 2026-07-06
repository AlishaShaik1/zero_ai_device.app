import 'package:shared_preferences/shared_preferences.dart';

/// Supported STT / TTS locales shown in Settings.
class SupportedLanguage {
  final String label;
  final String sttLocale;  // format: en_IN  (underscore, for speech_to_text)
  final String ttsLocale;  // format: en-IN  (hyphen, for flutter_tts)

  const SupportedLanguage({
    required this.label,
    required this.sttLocale,
    required this.ttsLocale,
  });
}

const List<SupportedLanguage> kSupportedLanguages = [
  SupportedLanguage(label: 'English (India)',    sttLocale: 'en_IN', ttsLocale: 'en-IN'),
  SupportedLanguage(label: 'English (US)',       sttLocale: 'en_US', ttsLocale: 'en-US'),
  SupportedLanguage(label: 'Hindi',              sttLocale: 'hi_IN', ttsLocale: 'hi-IN'),
  SupportedLanguage(label: 'Telugu',             sttLocale: 'te_IN', ttsLocale: 'te-IN'),
  SupportedLanguage(label: 'Tamil',              sttLocale: 'ta_IN', ttsLocale: 'ta-IN'),
  SupportedLanguage(label: 'Kannada',            sttLocale: 'kn_IN', ttsLocale: 'kn-IN'),
];

class UserPreferencesService {
  static const String _kSttLocaleKey  = 'stt_locale';
  static const String _kDefaultLocale = 'en_IN';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Returns the saved STT locale string (e.g. "en_IN", "te_IN").
  String get sttLocale =>
      _prefs?.getString(_kSttLocaleKey) ?? _kDefaultLocale;

  /// Returns the full [SupportedLanguage] object for the currently saved locale.
  SupportedLanguage get selectedLanguage =>
      kSupportedLanguages.firstWhere(
        (l) => l.sttLocale == sttLocale,
        orElse: () => kSupportedLanguages.first,
      );

  /// Persist the chosen STT locale.
  Future<void> setSttLocale(String locale) async {
    await _prefs?.setString(_kSttLocaleKey, locale);
  }
}
