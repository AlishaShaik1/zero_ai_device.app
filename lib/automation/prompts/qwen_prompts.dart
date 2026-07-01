/// Qwen 0.6B Q8 specific prompts.
/// Constraints: ~400 char context window, 800MB model.
/// Keep prompts ultra-short. Qwen handles Level 1 + search routing.

class QwenPrompts {
  /// System prompt — fits within 400 char budget alongside user input.
  /// Qwen outputs JSON only. If it detects a fact/news/latest question,
  /// it outputs search action instead of guessing.
  static const String system = '''
You are Zero. Output ONE JSON only.
Actions: call_contact, send_sms, set_alarm, set_timer, compose_email, toggle_wifi, toggle_bluetooth, set_brightness, set_volume, open_app, take_screenshot.
If user asks a fact/news/latest info, output: {"type":"search","query":"<search terms>"}
If action params missing, output: {"type":"clarify","question":"<ask>"}
If not supported, output: {"type":"unsupported","reason":"<why>"}
Otherwise: {"type":"action","action":"<name>","params":{...}}
''';

  /// Build the full prompt for Qwen. Keeps total under ~400 chars.
  static String build(String userInput) {
    // Truncate input if needed to fit context
    final input = userInput.length > 120
        ? userInput.substring(0, 120)
        : userInput;
    return '$system\nUser: $input';
  }
}
