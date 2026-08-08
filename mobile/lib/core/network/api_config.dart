import 'package:flutter/foundation.dart';

/// Base URL resolution.
///
/// Release builds always talk to production; debug builds default to the dev
/// machine's LAN IP so a physical device on the same Wi-Fi can reach it. Either
/// can be overridden with --dart-define=API_URL=...
/// (e.g. http://10.0.2.2:4000/api/v1 for the Android emulator).
class ApiConfig {
  ApiConfig._();

  static const _override = String.fromEnvironment('API_URL');

  /// Production API (TLS via Let's Encrypt).
  static const _prodUrl = 'https://api.fynexa.in/api/v1';

  /// Dev machine's LAN address (same Wi-Fi as the phone).
  static const _lanUrl = 'http://192.168.100.8:4000/api/v1';

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    // Never ship a build pointing at a laptop on someone's Wi-Fi.
    if (kReleaseMode) return _prodUrl;
    if (kIsWeb) return 'http://localhost:4000/api/v1';
    return _lanUrl;
  }

  static const connectTimeout = Duration(seconds: 20);
  // AI chat can run several model rounds (thinking + tool calls); allow ample
  // time before giving up so slow AgentRouter/Gemini answers still arrive.
  static const receiveTimeout = Duration(seconds: 180);
}
