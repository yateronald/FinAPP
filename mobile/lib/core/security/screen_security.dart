import 'package:flutter/foundation.dart';
import 'package:screen_protector/screen_protector.dart';

/// Banking-grade screen protection: blocks screenshots / screen recording
/// (Android FLAG_SECURE, iOS capture detection) and hides app content in the
/// task switcher (iOS) so sensitive financial data never leaks.
class ScreenSecurity {
  ScreenSecurity._();

  static Future<void> enable() async {
    if (kIsWeb) return;
    // Allow screenshots in debug/profile builds so development testing is easy;
    // only enforce the block in production release builds.
    if (!kReleaseMode) return;
    try {
      // Android: FLAG_SECURE. iOS: screenshot & screen-recording protection.
      await ScreenProtector.preventScreenshotOn();
      // iOS: blur the UI in the app switcher / when backgrounded.
      await ScreenProtector.protectDataLeakageWithBlur();
    } catch (_) {
      // Non-fatal: protection is best-effort on unsupported platforms.
    }
  }
}
