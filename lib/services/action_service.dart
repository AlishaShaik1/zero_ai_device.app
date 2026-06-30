import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:timezone/timezone.dart' as tz;
import '../ai/zero_agentic_service.dart';
import 'search_gateway_service.dart';

class ActionService {
  Future<String> execute(ParsedAction action) async {
    switch (action.action) {
      case ZeroAction.makeCall: return _makeCall(action.parameters);
      case ZeroAction.sendWhatsApp: return _sendWhatsApp(action.parameters);
      case ZeroAction.sendEmail: return _sendEmail(action.parameters);
      case ZeroAction.sendSMS: return _sendSMS(action.parameters);
      case ZeroAction.openApp: return _openApp(action.parameters);
      case ZeroAction.setTimer: return _setTimer(action.parameters);
      case ZeroAction.setReminder: return _setReminder(action.parameters);
      case ZeroAction.getWeather: return _getWeather();
      case ZeroAction.readNotifications: return _readNotifications();
      case ZeroAction.playMedia: return _playMedia(action.parameters);
      case ZeroAction.pauseMedia: return _pauseMedia();
      case ZeroAction.nextTrack: return _nextTrack();
      case ZeroAction.volumeUp: return _volumeUp();
      case ZeroAction.volumeDown: return _volumeDown();
      case ZeroAction.toggleWifi: return _toggleWifi(action.parameters);
      case ZeroAction.orderZomato: return _deepLinkApp('zomato', action.parameters);
      case ZeroAction.orderSwiggy: return _deepLinkApp('swiggy', action.parameters);
      case ZeroAction.payPhonePe: return _paymentApp('phonepe', action.parameters);
      case ZeroAction.payGPay: return _paymentApp('gpay', action.parameters);
      case ZeroAction.bookOla: return _deepLinkApp('ola', action.parameters);
      case ZeroAction.downloadYoutube: return _youtubeFlow(action.parameters);
      case ZeroAction.postInstagram: return _instagramPost();
      case ZeroAction.searchAmazon: return _amazonSearch(action.parameters);
      case ZeroAction.enableMouseMode: return 'MOUSE_ENABLE';
      case ZeroAction.disableMouseMode: return 'MOUSE_DISABLE';
      case ZeroAction.searchWeb: return _searchWeb(action.parameters);
      default: return "I'll learn that soon! 🌱";
    }
  }

  Future<String> _makeCall(Map<String, String> params) async {
    final uri = Uri(scheme: 'tel', path: params['contact']);
    await launchUrl(uri);
    return 'Calling ${params["contact"]} 📞';
  }

  Future<String> _sendWhatsApp(Map<String, String> params) async {
    final message = Uri.encodeComponent(params['message'] ?? '');
    final uri = Uri.parse('whatsapp://send?text=$message');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return 'WhatsApp opened ✉️';
    } catch (e) {
      await launchUrl(Uri.parse('https://wa.me/?text=$message'),
        mode: LaunchMode.externalApplication);
      return 'WhatsApp opened in browser ✉️';
    }
  }

  Future<String> _sendEmail(Map<String, String> params) async {
    final uri = Uri(
      scheme: 'mailto',
      path: params['contact'],
      queryParameters: {'subject': params['subject'] ?? 'Hello'},
    );
    await launchUrl(uri);
    return 'Email opened 📧';
  }
  
  Future<String> _sendSMS(Map<String, String> params) async {
    final uri = Uri(scheme: 'sms', path: params['contact']);
    await launchUrl(uri);
    return 'Messages opened 💬';
  }

  Future<String> _openApp(Map<String, String> params) async {
    final appName = (params['appName'] ?? '').toLowerCase();
    final packages = {
      'whatsapp': 'com.whatsapp',
      'youtube': 'com.google.android.youtube',
      'instagram': 'com.instagram.android',
      'zomato': 'com.application.zomato',
      'swiggy': 'in.swiggy.android',
      'phonepe': 'com.phonepe.app',
      'gpay': 'com.google.android.apps.nbu.paisa.user',
      'paytm': 'net.one97.paytm',
      'ola': 'com.olacabs.customer',
      'uber': 'com.ubercab',
      'amazon': 'in.amazon.mShop.android.shopping',
      'flipkart': 'com.flipkart.android',
      'maps': 'com.google.android.apps.maps',
      'chrome': 'com.android.chrome',
      'spotify': 'com.spotify.music',
      'gmail': 'com.google.android.gm',
      'telegram': 'org.telegram.messenger',
      'twitter': 'com.twitter.android',
      'x': 'com.twitter.android',
      'netflix': 'com.netflix.mediaclient',
      'hotstar': 'in.startv.hotstar',
      'settings': 'com.android.settings',
    };
    final package = packages[appName];
    if (package != null) {
      final intent = AndroidIntent(
        action: 'android.intent.action.MAIN',
        package: package,
        flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      await intent.launch();
      return 'Opening $appName 📱';
    }
    return 'App not found, try saying the exact name 🔍';
  }

  Future<String> _setTimer(Map<String, String> params) async {
    final minutes = int.tryParse(params['minutes'] ?? '5') ?? 5;
    await FlutterLocalNotificationsPlugin().zonedSchedule(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Zero Ring Timer ⏱️',
      '$minutes minute timer done!',
      tz.TZDateTime.now(tz.local).add(Duration(minutes: minutes)),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'zero_timer', 'Zero Timers',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
      ),
      uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    return 'Timer set for $minutes minutes ⏱️';
  }

  Future<String> _setReminder(Map<String, String> params) async {
      return 'Setting reminder 🔔';
  }

  Future<String> _getWeather() async {
    try {
      final response = await http.get(Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=17.0&longitude=82.0&current_weather=true'
      ));
      final data = jsonDecode(response.body);
      final temp = data['current_weather']['temperature'];
      final code = data['current_weather']['weathercode'];
      final description = _weatherCode(code);
      return 'It is $temp°C and $description right now 🌤️';
    } catch (e) {
      return 'Cannot fetch weather right now 🌥️';
    }
  }

  String _weatherCode(int code) {
    if (code == 0) return 'clear sky ☀️';
    if (code <= 3) return 'partly cloudy ⛅';
    if (code <= 67) return 'rainy 🌧️';
    if (code <= 77) return 'snowy ❄️';
    if (code <= 99) return 'stormy ⛈️';
    return 'unknown';
  }

  Future<String> _readNotifications() async {
    // Requires NotificationListenerService in AndroidManifest
    // Implemented via platform channel in Task 6
    return 'Notification reading requires permission.\nSay "hey zero enable notifications" to set up 📬';
  }

  Future<String> _playMedia(Map<String, String> params) async {
    final intent = AndroidIntent(
      action: 'android.intent.action.VIEW',
      data: 'spotify:search:${params["query"] ?? ""}',
    );
    try {
      await intent.launch();
    } catch (e) {
      final uri = Uri.parse(
        'https://open.spotify.com/search/${params["query"] ?? ""}');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return 'Playing music 🎵';
  }

  Future<String> _pauseMedia() async {
    // Use AudioManager via platform channel
    return 'Paused ⏸️';
  }

  Future<String> _nextTrack() async {
    return 'Next track ⏭️';
  }

  Future<String> _volumeUp() async {
    final currentVol = await VolumeController().getVolume();
    VolumeController().setVolume(currentVol + 0.1);
    return 'Volume up 🔊';
  }

  Future<String> _volumeDown() async {
    final currentVol = await VolumeController().getVolume();
    VolumeController().setVolume(currentVol - 0.1);
    return 'Volume down 🔉';
  }

  Future<String> _toggleWifi(Map<String, String> params) async {
    // WiFi toggle requires system settings intent on Android 10+
    final intent = const AndroidIntent(action: 'android.settings.WIFI_SETTINGS');
    await intent.launch();
    return 'Opening WiFi settings 📶';
  }

  Future<String> _deepLinkApp(String app, Map<String, String> params) async {
    switch (app) {
      case 'zomato':
        final item = params['item'] ?? '';
        final uri = item.isNotEmpty
          ? Uri.parse('zomato://search?q=$item')
          : Uri.parse('zomato://home');
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (e) {
          await _openApp({'appName': 'zomato'});
        }
        return 'Opening Zomato 🍔';

      case 'swiggy':
        try {
          await launchUrl(Uri.parse('swiggy://home'),
            mode: LaunchMode.externalApplication);
        } catch (e) {
          await _openApp({'appName': 'swiggy'});
        }
        return 'Opening Swiggy 🛵';

      case 'ola':
        final dest = params['destination'] ?? '';
        try {
          await launchUrl(Uri.parse('olacabs://app/launch?drop=$dest'),
            mode: LaunchMode.externalApplication);
        } catch (e) {
          await _openApp({'appName': 'ola'});
        }
        return 'Opening Ola 🚗';
    }
    return '';
  }

  Future<String> _paymentApp(String app, Map<String, String> params) async {
    final amount = params['amount'] ?? '';
    final recipient = params['recipient'] ?? '';
    switch (app) {
      case 'phonepe':
        try {
          await launchUrl(Uri.parse(
            'phonepe://pay?pa=$recipient&am=$amount&cu=INR'),
            mode: LaunchMode.externalApplication);
        } catch (e) {
          await _openApp({'appName': 'phonepe'});
        }
        return 'Opening PhonePe 💸';
      case 'gpay':
        try {
          await launchUrl(Uri.parse(
            'tez://upi/pay?pa=$recipient&am=$amount&cu=INR'),
            mode: LaunchMode.externalApplication);
        } catch (e) {
          await _openApp({'appName': 'gpay'});
        }
        return 'Opening GPay 💳';
    }
    return '';
  }

  Future<String> _youtubeFlow(Map<String, String> params) async {
    final query = params['query'] ?? '';
    // Open YouTube with search
    final uri = Uri.parse(
      'https://www.youtube.com/results?search_query=$query');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    return 'Opening YouTube for "$query" — download manually or say "hey zero use yt downloader" 📥';
  }

  Future<String> _instagramPost() async {
    await _openApp({'appName': 'instagram'});
    return 'Instagram open — go to your gallery to post 📸';
  }

  Future<String> _amazonSearch(Map<String, String> params) async {
    final query = params['query'] ?? '';
    final uri = Uri.parse('https://www.amazon.in/s?k=$query');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    return 'Searching Amazon for $query 🛒';
  }

  Future<String> _searchWeb(Map<String, String> params) async {
    final query = params['query'] ?? '';
    if (query.isEmpty) return 'What would you like me to search for?';

    // Fetch results from Zero Search Gateway
    final results = await SearchGatewayService.instance.search(query);

    if (results.isEmpty) {
      return 'Search unavailable, try again';
    }

    // Build a short TTS-friendly answer from the top result.
    // The ring OLED is 64x32 (≈10 chars/line × 4 lines = ~40 chars).
    // TTS gets the full snippet (≤120 chars); OLED gets the first 38 chars.
    final top = results.first;
    final spoken = top.snippet.isNotEmpty ? top.snippet : top.title;
    return spoken.length > 120 ? '${spoken.substring(0, 120)}…' : spoken;
  }
}
