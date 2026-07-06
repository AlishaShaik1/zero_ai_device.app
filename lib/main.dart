import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:provider/provider.dart';
import 'controllers/zero_controller.dart';
import 'services/download_service.dart';
import 'services/search_gateway_service.dart';
<<<<<<< HEAD
import 'services/marketplace_service.dart';
=======
import 'screens/home_screen.dart';
import 'screens/download_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/debug_screen.dart';
>>>>>>> 9aaa7ef (updated file strcture and model development)

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Catch ALL unhandled Flutter framework errors — prevents white screen crashes.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[FlutterError] ${details.exceptionAsString()}');
  };
  
  try {
    await FlutterDownloader.initialize(
      debug: true,
      ignoreSsl: true,
    );
  } catch (e) {
    debugPrint('[ZeroApp] FlutterDownloader initialization failed: $e');
  }

  await SearchGatewayService.instance.init();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DownloadService()),
<<<<<<< HEAD
        ChangeNotifierProvider.value(value: MarketplaceService.instance),
=======
        ChangeNotifierProvider(
          create: (_) {
            final controller = ZeroController();
            // BUG FIX: initState() is async but create() is sync.
            // Schedule it on the next microtask so it runs properly async
            // without blocking the widget tree construction.
            Future.microtask(() => controller.initState());
            return controller;
          },
        ),
>>>>>>> 9aaa7ef (updated file strcture and model development)
      ],
      child: const ZeroApp(),
    ),
  );
}

class ZeroApp extends StatelessWidget {
  const ZeroApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zero AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF070710),
        fontFamily: 'Inter',
      ),
      initialRoute: '/downloads',
      routes: {
        '/downloads': (context) => const DownloadScreen(),
        '/home': (context) => const HomeScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/debug': (context) => const DebugScreen(),
      },
    );
  }
}
