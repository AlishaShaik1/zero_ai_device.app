import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ring_state.dart';

/// Represents an idle behavior that Zero can exhibit
class IdleBehavior {
  final ZeroEmotion emotion;
  final String? message;
  final int durationSeconds;

  IdleBehavior({required this.emotion, this.message, this.durationSeconds = 3});
}

/// PersonalityService — Makes Zero feel alive.
/// Tracks mood, reacts to environment, learns user patterns.
class PersonalityService {
  final Random _random = Random();

  // ═══ STATE ═══
  String _userName = '';
  int _totalInteractions = 0;
  int _todayInteractions = 0;
  int _petCount = 0;
  int _shakeCount = 0;
  int _consecutiveIdleSeconds = 0;
  double _moodScore = 0.7; // 0.0 = sad, 1.0 = ecstatic
  DateTime _lastInteraction = DateTime.now();
  DateTime _lastPet = DateTime.now();
  bool _ringConnected = false;
  List<String> _recentActions = [];

  // ═══ GETTERS ═══
  double get moodScore => _moodScore;
  int get totalInteractions => _totalInteractions;
  String get userName => _userName;
  int get todayInteractions => _todayInteractions;
  int get shakeCount => _shakeCount;
  int get consecutiveIdleSeconds => _consecutiveIdleSeconds;
  DateTime get lastPet => _lastPet;
  bool get ringConnected => _ringConnected;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _userName = prefs.getString('user_name') ?? '';
    _totalInteractions = prefs.getInt('total_interactions') ?? 0;
    _petCount = prefs.getInt('pet_count') ?? 0;
    _moodScore = prefs.getDouble('mood_score') ?? 0.7;
    _todayInteractions = 0;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('total_interactions', _totalInteractions);
    await prefs.setInt('pet_count', _petCount);
    await prefs.setDouble('mood_score', _moodScore);
    if (_userName.isNotEmpty) {
      await prefs.setString('user_name', _userName);
    }
  }

  // ═══ GREETINGS ═══

  String getGreeting() {
    final hour = DateTime.now().hour;
    final name = _userName.isNotEmpty ? ', $_userName' : '';
    
    if (_totalInteractions == 0) {
      return "Hey there$name! I'm Zero ✨ Tap the orb and talk to me!";
    }
    
    if (hour < 6) {
      return _pick([
        "Up late$name? I don't sleep either 🌙",
        "Night owl mode$name! What's up? 🦉",
        "Burning the midnight oil$name? 🕯️",
      ]);
    } else if (hour < 12) {
      return _pick([
        "Good morning$name! Ready to roll ☀️",
        "Morning$name! What shall we do today? 🌅",
        "Rise and shine$name! ✨",
      ]);
    } else if (hour < 17) {
      return _pick([
        "Hey$name! Afternoon vibes 😎",
        "What's on your mind$name? 💭",
        "Back for more$name? Let's go! 🚀",
      ]);
    } else if (hour < 21) {
      return _pick([
        "Evening$name! Winding down? 🌆",
        "Hey$name! Ready for tonight? ✨",
        "Evening mode$name 🌇",
      ]);
    } else {
      return _pick([
        "Hey$name! Late night adventures? 🌃",
        "Still going$name? I'm here for it 💫",
        "Night mode activated$name 🌙",
      ]);
    }
  }

  String getConnectionMessage() {
    if (_totalInteractions < 5) {
      return "Ring connected! Nice to meet you!";
    }
    return _pick([
      "Ring connected! Hey there!",
      "We're linked! Ready to go!",
      "Ring online! Let's rock!",
      "Connected! Missed you!",
    ]);
  }

  // ═══ EVENT HANDLERS ═══

  void onInteraction() {
    _totalInteractions++;
    _todayInteractions++;
    _lastInteraction = DateTime.now();
    _consecutiveIdleSeconds = 0;
    _moodScore = (_moodScore + 0.02).clamp(0.0, 1.0);
    _save();
  }

  void onPetted() {
    _petCount++;
    _lastPet = DateTime.now();
    _moodScore = (_moodScore + 0.05).clamp(0.0, 1.0);
    _save();
  }

  void onRingConnected() {
    _ringConnected = true;
    _moodScore = (_moodScore + 0.1).clamp(0.0, 1.0);
  }

  void onRingDisconnected() {
    _ringConnected = false;
    _moodScore = (_moodScore - 0.05).clamp(0.0, 1.0);
  }

  void onShake() {
    _shakeCount++;
    _consecutiveIdleSeconds = 0;
  }

  void onUpsideDown() {
    _consecutiveIdleSeconds = 0;
  }

  void recordAction(String actionName) {
    _recentActions.add(actionName);
    if (_recentActions.length > 20) {
      _recentActions.removeAt(0);
    }
  }

  void updateMotionState(double magnitude) {
    if (magnitude < 1.1) {
      _consecutiveIdleSeconds++;
    } else {
      _consecutiveIdleSeconds = 0;
    }
  }

  // ═══ REACTIONS ═══

  String getReaction(String event) {
    switch (event) {
      case 'upside_down':
        return _pick([
          "Woah! Everything's upside down! 🙃",
          "Hey! I'm dizzy! 😵‍💫",
          "The world just flipped! 🌍",
          "Wheeee! Roller coaster! 🎢",
        ]);
      case 'shake':
        return _pick([
          "Earthquake?! 😱",
          "Whoa, hold on tight! 🌪️",
          "That's quite a shake! 💫",
          "I'm getting dizzy! 🌀",
        ]);
      default:
        return "Hmm, that was interesting! 🤔";
    }
  }

  String getPetResponse() {
    if (_petCount > 50) {
      return _pick([
        "Hehe, you always know how to make me happy! 💕",
        "Best human ever! ✨",
        "I love our bond! 💖",
      ]);
    } else if (_petCount > 10) {
      return _pick([
        "Hehe, that tickles! ✨",
        "Aww, you're sweet! 💕",
        "More pets please! 🥰",
        "You're my favorite human! 💫",
      ]);
    } else {
      return _pick([
        "Oh! That's nice! ✨",
        "Hehe, that tickles! 😊",
        "Hey, that felt good! 💫",
      ]);
    }
  }

  String getNoModelResponse(String input) {
    return _pick([
      "I'm still downloading my brain! Give me a sec 🧠",
      "My AI models aren't ready yet — try again after setup! 📥",
      "I need my models first! Go to Settings → Download All 🚀",
      "Almost there! Finish the model download and I'll be smart ✨",
    ]);
  }

  // ═══ IDLE BEHAVIORS ═══

  IdleBehavior? getIdleBehavior() {
    // Only trigger occasionally
    if (_random.nextInt(100) > 25) return null; // 25% chance each 30s

    final hour = DateTime.now().hour;
    final minutesSinceInteraction = DateTime.now().difference(_lastInteraction).inMinutes;

    // Sleeping if very idle
    if (minutesSinceInteraction > 10 || (hour >= 23 || hour < 6)) {
      return IdleBehavior(
        emotion: ZeroEmotion.sleeping,
        message: _pick([
          "💤 *yawns*",
          "zzz... poke me if you need me 💤",
          "Taking a tiny nap... 😴",
        ]),
        durationSeconds: 15,
      );
    }

    // Random cute behaviors
    final behaviors = [
      IdleBehavior(
        emotion: ZeroEmotion.thinking,
        message: _pick([
          "Hmm, I wonder what we'll do next... 🤔",
          "Processing the meaning of life... 🧠",
          "Thinking about cool ring tricks... 💭",
        ]),
        durationSeconds: 5,
      ),
      IdleBehavior(
        emotion: ZeroEmotion.excited,
        message: _pick([
          "Hey! I just learned something cool! ⚡",
          "Did you know I can control your phone? 🤯",
          "Try saying 'play music' or 'what's the weather'! 🎵",
        ]),
        durationSeconds: 4,
      ),
      IdleBehavior(
        emotion: ZeroEmotion.happy,
        message: _pick([
          "Just vibing on your finger ✨",
          "Living my best ring life 💍",
          "Ring life is the best life 🌟",
        ]),
        durationSeconds: 3,
      ),
    ];

    return behaviors[_random.nextInt(behaviors.length)];
  }

  // ═══ HELPERS ═══

  String _pick(List<String> options) {
    return options[_random.nextInt(options.length)];
  }

  void setUserName(String name) {
    _userName = name;
    _save();
  }
}
