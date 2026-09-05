import 'package:chess/firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'package:firebase_core/firebase_core.dart';

import 'core/constant/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/account/presentation/auth_provider.dart';
import 'features/account/presentation/settings_provider.dart';
import 'providers/game_provider.dart';
import 'screens/start_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Local key/value store for Phase 9's device-only data: app settings
  // (`HiveSettingsRepository`) and the offline saved-games cache
  // (`HiveCachedSavedGamesRepository`). Safe to initialize unconditionally
  // — unlike Firebase below, this has no remote config to fail against.
  await Hive.initFlutter();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // No `firebase_options.dart` / native config present yet — see the
    // note above. Falling through instead of rethrowing keeps every
    // non-multiplayer feature usable out of the box.
  }

  runApp(const ChessApp());
}

class ChessApp extends StatelessWidget {
  const ChessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameProvider()),
        // Registered at the app root (rather than per-screen, like the
        // rest of this app's providers) because both outlive any single
        // game or screen: the signed-in identity and app preferences
        // need to be available from `StartScreen` onward, and every
        // screen that reads or writes them (matchmaking's display-name
        // field, the game-over save/rating hooks, the settings screen
        // itself) expects one shared instance rather than a fresh one
        // per navigation.
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ScreenUtilInit(
            designSize: _getDesignSize(constraints.maxWidth),
            minTextAdapt: true,
            splitScreenMode: true,
            builder: (context, _) {
              return MaterialApp(
                title: AppConstants.appName,
                debugShowCheckedModeBanner: false,
                theme: AppTheme.dark,
                themeAnimationDuration: const Duration(milliseconds: 350),
                themeAnimationCurve: Curves.easeInOut,
                builder: (context, child) {
                  return MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.noScaling),
                    child: child!,
                  );
                },
                home: const StartScreen(),
              );
            },
          );
        },
      ),
    );
  }
}

Size _getDesignSize(double width) {
  if (width < 600) return const Size(360, 690); // phones
  if (width < 1200) return const Size(834, 1194); // tablets
  return const Size(1440, 1024); // desktop / web
}
