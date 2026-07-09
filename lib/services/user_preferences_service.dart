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
  static const String _kWakeWordKey   = 'wake_word_enabled';
  static const String _kPrimeKey      = 'prime_enabled';
  static const String _kWebSearchKey  = 'web_search_enabled';
  static const String _kAutoUpdateKey = 'auto_update_enabled';

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

  bool get isWakeWordEnabled => _prefs?.getBool(_kWakeWordKey) ?? true;
  Future<void> setWakeWordEnabled(bool val) async {
    await _prefs?.setBool(_kWakeWordKey, val);
  }

  bool get isPrimeEnabled => _prefs?.getBool(_kPrimeKey) ?? true;
  Future<void> setPrimeEnabled(bool val) async {
    await _prefs?.setBool(_kPrimeKey, val);
  }

  bool get isWebSearchEnabled => _prefs?.getBool(_kWebSearchKey) ?? true;
  Future<void> setWebSearchEnabled(bool val) async {
    await _prefs?.setBool(_kWebSearchKey, val);
  }

  bool get isAutoUpdateEnabled => _prefs?.getBool(_kAutoUpdateKey) ?? false;
  Future<void> setAutoUpdateEnabled(bool val) async {
    await _prefs?.setBool(_kAutoUpdateKey, val);
  }
}
