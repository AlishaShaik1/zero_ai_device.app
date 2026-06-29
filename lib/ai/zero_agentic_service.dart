enum ZeroAction {
  // Communication
  makeCall, sendWhatsApp, sendSMS, sendEmail,
  // Media
  playMedia, pauseMedia, nextTrack, prevTrack,
  volumeUp, volumeDown,
  // Device
  openApp, toggleWifi, toggleBluetooth,
  brightnessUp, brightnessDown,
  // Productivity
  setTimer, setAlarm, setReminder, addCalendar,
  // Information
  getWeather, readNotifications, searchWeb,
  // Vision
  analyzeCamera, scanQR, translateCamera,
  // Air Mouse
  enableMouseMode, disableMouseMode,
  // Tier 1 Automation
  orderZomato, orderSwiggy,
  payPhonePe, payGPay, payPaytm,
  bookOla, bookUber,
  downloadYoutube, postInstagram,
  searchAmazon, searchFlipkart,
  // Multi-step
  customWorkflow,
  // Unknown
  unknown
}

class ParsedAction {
  final ZeroAction action;
  final Map<String, String> parameters;
  final String confirmMessage;
  final bool needsConfirm;
  final bool isMultiStep;

  ParsedAction({
    required this.action,
    required this.parameters,
    required this.confirmMessage,
    required this.needsConfirm,
    required this.isMultiStep,
  });
}

class ZeroAgenticService {
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  Future<void> initialize() async {
    // Zero Agentic uses rule-based parsing + keyword matching
    // FunctionGemma .task file loaded via MediaPipe LLM API
    // For now implement smart keyword parser
    // Full model integration in Phase 3 after firmware
    _isLoaded = true;
  }

  Future<ParsedAction> parseIntent(String rawInput) async {
    final input = rawInput.toLowerCase().trim();

    // ═══ COMMUNICATION ═══

    // CALLS
    if (_contains(input, ['call', 'phone', 'dial', 'ring'])) {
      final contact = _extractAfter(input, ['call', 'phone', 'dial', 'ring']);
      return ParsedAction(
        action: ZeroAction.makeCall,
        parameters: {'contact': contact},
        confirmMessage: 'Calling $contact 📞',
        needsConfirm: false,
        isMultiStep: false,
      );
    }

    // WHATSAPP
    if (_contains(input, ['whatsapp', 'wa', 'wp']) ||
        (_contains(input, ['text', 'message', 'msg']) &&
         _contains(input, ['send', 'tell']))) {
      final contact = _extractContact(input);
      final message = _extractMessage(input);
      return ParsedAction(
        action: ZeroAction.sendWhatsApp,
        parameters: {'contact': contact, 'message': message},
        confirmMessage: 'Sending WhatsApp to $contact ✉️',
        needsConfirm: false,
        isMultiStep: false,
      );
    }

    // EMAIL
    if (_contains(input, ['email', 'mail', 'gmail'])) {
      final contact = _extractContact(input);
      final subject = _extractAfter(input, ['about', 'subject', 'regarding']);
      return ParsedAction(
        action: ZeroAction.sendEmail,
        parameters: {'contact': contact, 'subject': subject},
        confirmMessage: 'Opening Gmail to $contact 📧',
        needsConfirm: false,
        isMultiStep: false,
      );
    }

    // ═══ APPS ═══

    // OPEN APP
    if (_contains(input, ['open', 'launch', 'start', 'go to'])) {
      final appName = _extractAfter(input, ['open', 'launch', 'start', 'go to']);
      return ParsedAction(
        action: ZeroAction.openApp,
        parameters: {'appName': appName},
        confirmMessage: 'Opening $appName 📱',
        needsConfirm: false,
        isMultiStep: false,
      );
    }

    // ═══ PRODUCTIVITY ═══

    // TIMER
    if (_contains(input, ['timer', 'countdown'])) {
      final minutes = _extractNumber(input);
      return ParsedAction(
        action: ZeroAction.setTimer,
        parameters: {'minutes': minutes.toString()},
        confirmMessage: 'Setting $minutes minute timer ⏱️',
        needsConfirm: false,
        isMultiStep: false,
      );
    }

    // REMINDER / ALARM
    if (_contains(input, ['remind', 'alarm', 'wake me'])) {
      final time = _extractTime(input);
      final label = _extractAfter(input, ['to', 'about', 'for']);
      return ParsedAction(
        action: ZeroAction.setReminder,
        parameters: {'time': time, 'label': label},
        confirmMessage: 'Setting reminder for $time 🔔',
        needsConfirm: false,
        isMultiStep: false,
      );
    }

    // WEATHER
    if (_contains(input, ['weather', 'temperature', 'rain',
      'hot', 'cold', 'climate'])) {
      return ParsedAction(
        action: ZeroAction.getWeather,
        parameters: {},
        confirmMessage: 'Checking weather 🌤️',
        needsConfirm: false,
        isMultiStep: false,
      );
    }

    // NOTIFICATIONS
    if (_contains(input, ['notification', 'messages',
      'missed', 'unread', 'inbox'])) {
      return ParsedAction(
        action: ZeroAction.readNotifications,
        parameters: {},
        confirmMessage: 'Reading your notifications 📬',
        needsConfirm: false,
        isMultiStep: false,
      );
    }

    // ═══ MEDIA ═══

    // MUSIC CONTROL
    if (_contains(input, ['play', 'music', 'song', 'spotify'])) {
      return ParsedAction(
        action: ZeroAction.playMedia,
        parameters: {'query': _extractAfter(input, ['play'])},
        confirmMessage: 'Playing music 🎵',
        needsConfirm: false,
        isMultiStep: false,
      );
    }

    if (_contains(input, ['pause', 'stop music'])) {
      return ParsedAction(
        action: ZeroAction.pauseMedia,
        parameters: {},
        confirmMessage: 'Paused 🎵',
        needsConfirm: false,
        isMultiStep: false,
      );
    }

    if (_contains(input, ['next', 'skip'])) {
      return ParsedAction(
        action: ZeroAction.nextTrack,
        parameters: {},
        confirmMessage: 'Next track ⏭️',
        needsConfirm: false,
        isMultiStep: false,
      );
    }

    // VOLUME
    if (_contains(input, ['volume up', 'louder', 'increase volume'])) {
      return ParsedAction(action: ZeroAction.volumeUp,
        parameters: {}, confirmMessage: 'Volume up 🔊',
        needsConfirm: false, isMultiStep: false);
    }

    if (_contains(input, ['volume down', 'quieter', 'lower volume'])) {
      return ParsedAction(action: ZeroAction.volumeDown,
        parameters: {}, confirmMessage: 'Volume down 🔉',
        needsConfirm: false, isMultiStep: false);
    }

    // ═══ DEVICE ═══

    if (_contains(input, ['wifi on', 'turn on wifi', 'enable wifi'])) {
      return ParsedAction(action: ZeroAction.toggleWifi,
        parameters: {'enable': 'true'}, confirmMessage: 'WiFi on 📶',
        needsConfirm: false, isMultiStep: false);
    }

    if (_contains(input, ['wifi off', 'turn off wifi'])) {
      return ParsedAction(action: ZeroAction.toggleWifi,
        parameters: {'enable': 'false'}, confirmMessage: 'WiFi off 📶',
        needsConfirm: false, isMultiStep: false);
    }

    // MOUSE MODE
    if (_contains(input, ['mouse', 'cursor', 'control laptop',
      'control computer', 'air mouse'])) {
      return ParsedAction(
        action: ZeroAction.enableMouseMode,
        parameters: {},
        confirmMessage: 'Air mouse activated 🖱️',
        needsConfirm: false,
        isMultiStep: false,
      );
    }

    // ═══ AUTOMATION TIER 1 ═══

    // ZOMATO
    if (_contains(input, ['zomato']) ||
        (_contains(input, ['order', 'food']) &&
         !_contains(input, ['swiggy']))) {
      final item = _extractFoodItem(input);
      return ParsedAction(
        action: ZeroAction.orderZomato,
        parameters: {'item': item},
        confirmMessage: 'Opening Zomato${item.isNotEmpty ? " for $item" : ""} 🍔',
        needsConfirm: true,
        isMultiStep: true,
      );
    }

    // SWIGGY
    if (_contains(input, ['swiggy'])) {
      final item = _extractFoodItem(input);
      return ParsedAction(
        action: ZeroAction.orderSwiggy,
        parameters: {'item': item},
        confirmMessage: 'Opening Swiggy 🛵',
        needsConfirm: true,
        isMultiStep: true,
      );
    }

    // PHONEPAY
    if (_contains(input, ['phonepe', 'phone pe', 'phone pay'])) {
      final amount = _extractAmount(input);
      final recipient = _extractContact(input);
      return ParsedAction(
        action: ZeroAction.payPhonePe,
        parameters: {'amount': amount, 'recipient': recipient},
        confirmMessage: 'Opening PhonePe 💸',
        needsConfirm: true,
        isMultiStep: true,
      );
    }

    // GPAY
    if (_contains(input, ['gpay', 'google pay', 'tez'])) {
      final amount = _extractAmount(input);
      final recipient = _extractContact(input);
      return ParsedAction(
        action: ZeroAction.payGPay,
        parameters: {'amount': amount, 'recipient': recipient},
        confirmMessage: 'Opening GPay 💳',
        needsConfirm: true,
        isMultiStep: true,
      );
    }

    // OLA
    if (_contains(input, ['ola', 'cab', 'taxi', 'ride'])) {
      final destination = _extractDestination(input);
      return ParsedAction(
        action: ZeroAction.bookOla,
        parameters: {'destination': destination},
        confirmMessage: 'Booking Ola to $destination 🚗',
        needsConfirm: true,
        isMultiStep: true,
      );
    }

    // YOUTUBE DOWNLOAD
    if (_contains(input, ['download']) &&
        _contains(input, ['youtube', 'video', 'yt'])) {
      final query = _extractAfter(input, ['download', 'video']);
      return ParsedAction(
        action: ZeroAction.downloadYoutube,
        parameters: {'query': query},
        confirmMessage: 'Searching YouTube to download 📥',
        needsConfirm: true,
        isMultiStep: true,
      );
    }

    // INSTAGRAM POST
    if (_contains(input, ['instagram', 'insta']) &&
        _contains(input, ['post', 'share', 'upload', 'story'])) {
      return ParsedAction(
        action: ZeroAction.postInstagram,
        parameters: {},
        confirmMessage: 'Opening Instagram to post 📸',
        needsConfirm: true,
        isMultiStep: true,
      );
    }

    // AMAZON SEARCH
    if (_contains(input, ['amazon', 'buy', 'purchase', 'order']) &&
        !_contains(input, ['food', 'zomato', 'swiggy'])) {
      final query = _extractAfter(input, ['amazon', 'buy', 'purchase', 'order']);
      return ParsedAction(
        action: ZeroAction.searchAmazon,
        parameters: {'query': query},
        confirmMessage: 'Searching Amazon for $query 🛒',
        needsConfirm: false,
        isMultiStep: false,
      );
    }

    // WEB SEARCH
    if (_contains(input, ['search', 'google', 'look up', 'find out']) &&
        !_contains(input, ['amazon', 'flipkart'])) {
      final query = _extractAfter(input, ['search for', 'search', 'google', 'look up', 'find out about', 'find out']);
      return ParsedAction(
        action: ZeroAction.searchWeb,
        parameters: {'query': query},
        confirmMessage: 'Searching web for $query 🔍',
        needsConfirm: false,
        isMultiStep: false,
      );
    }

    // DEFAULT
    return ParsedAction(
      action: ZeroAction.unknown,
      parameters: {},
      confirmMessage: '',
      needsConfirm: false,
      isMultiStep: false,
    );
  }

  // HELPER METHODS
  bool _contains(String input, List<String> keywords) {
    return keywords.any((k) => input.contains(k));
  }

  String _extractAfter(String input, List<String> triggers) {
    for (final trigger in triggers) {
      final idx = input.indexOf(trigger);
      if (idx != -1) {
        return input.substring(idx + trigger.length).trim();
      }
    }
    return '';
  }

  String _extractContact(String input) {
    // Extract name after 'to', 'call', 'text' etc
    final patterns = ['to ', 'call ', 'text ', 'message '];
    for (final p in patterns) {
      if (input.contains(p)) {
        final after = input.substring(input.indexOf(p) + p.length);
        // take first word as contact name
        return after.split(' ').first.trim();
      }
    }
    return '';
  }

  String _extractMessage(String input) {
    final patterns = ['saying ', 'say ', 'that ', 'message '];
    for (final p in patterns) {
      if (input.contains(p)) {
        return input.substring(input.indexOf(p) + p.length).trim();
      }
    }
    return '';
  }

  int _extractNumber(String input) {
    final match = RegExp(r'\d+').firstMatch(input);
    return match != null ? int.parse(match.group(0)!) : 5;
  }

  String _extractTime(String input) {
    final match = RegExp(r'\d+:\d+|\d+ (am|pm)').firstMatch(input);
    return match?.group(0) ?? '';
  }

  String _extractFoodItem(String input) {
    final triggers = ['order ', 'get ', 'want ', 'craving '];
    for (final t in triggers) {
      if (input.contains(t)) {
        String after = input.substring(input.indexOf(t) + t.length);
        final remove = ['from zomato', 'from swiggy', 'on zomato', 'food'];
        for (final r in remove) {
          after = after.replaceAll(r, '');
        }
        return after.trim();
      }
    }
    return '';
  }

  String _extractAmount(String input) {
    final match = RegExp(r'₹?\d+').firstMatch(input);
    return match?.group(0)?.replaceAll('₹', '') ?? '';
  }

  String _extractDestination(String input) {
    final triggers = ['to ', 'drop ', 'at ', 'towards '];
    for (final t in triggers) {
      if (input.contains(t)) {
        return input.substring(input.indexOf(t) + t.length).trim();
      }
    }
    return '';
  }
}
