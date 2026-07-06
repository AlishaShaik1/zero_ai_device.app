import 'package:flutter/foundation.dart';

class ConversationManager extends ChangeNotifier {
  final List<Map<String, String>> _history = [];
  final int maxHistoryLength = 20; // Increased context length
  
  String _currentStreamingMessage = "";

  List<Map<String, String>> get history => _history;
  String get currentStreamingMessage => _currentStreamingMessage;

  void addMessage(String role, String content) {
    _history.add({'role': role, 'content': content});
    if (_history.length > maxHistoryLength) {
      _history.removeAt(0);
    }
    notifyListeners();
  }

  void startStreamingAssistantMessage() {
    _currentStreamingMessage = "";
    notifyListeners();
  }

  void appendStreamingToken(String token) {
    _currentStreamingMessage += token;
    notifyListeners();
  }

  void finishStreamingAssistantMessage() {
    if (_currentStreamingMessage.trim().isNotEmpty) {
      addMessage('assistant', _currentStreamingMessage.trim());
    }
    _currentStreamingMessage = "";
    notifyListeners();
  }

  String getFormattedContext() {
    if (_history.isEmpty) return "";
    StringBuffer buffer = StringBuffer();
    for (var msg in _history) {
      buffer.writeln("${msg['role'] == 'user' ? 'User' : 'Assistant'}: ${msg['content']}");
    }
    return buffer.toString();
  }

  void clear() {
    _history.clear();
    _currentStreamingMessage = "";
    notifyListeners();
  }
}
