import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps [child] the same way `main.dart`'s `ChessApp` does
/// (`ScreenUtilInit` -> `MaterialApp`) so widgets that use
/// `flutter_screenutil`'s `.w`/`.h`/`.sp`/`.r` extensions — which is
/// most of this app's UI, including [ChessBoard] and
/// `showPromotionPicker` — don't throw "ScreenUtil not initialized" when
/// pumped in isolation.
///
/// Every widget test in this project should pump through this helper
/// rather than a bare `MaterialApp` for that reason.
Widget wrapForTest(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(360, 690),
    builder: (context, _) => MaterialApp(home: Scaffold(body: child)),
  );
}

/// Convenience for the common "pump [child] wrapped for test, then settle
/// any animations" pattern.
Future<void> pumpForTest(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(wrapForTest(child));
  await tester.pump();
}
