import 'package:chess/firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

// Phase 7 (online multiplayer) needs Firebase initialized before any
// screen touches Firestore/Auth. See FIREBASE_SETUP.md for generating a
// real `firebase_options.dart` for your own project via `flutterfire
// configure` — until that's done, `Firebase.initializeApp()` below will
// throw, which is caught so local play, the AI, the analysis board, and
// puzzles all keep working with zero Firebase configuration. Only
// "Play online" needs it, and it fails with a clear in-app message
// (`MatchmakingScreen`) rather than a crash on launch.
import 'package:firebase_core/firebase_core.dart';

import 'core/constant/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'providers/game_provider.dart';
import 'screens/start_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.noScaling),
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
