import 'package:flutter/foundation.dart';

/// Base URL resolution. Defaults to the dev machine's LAN IP so physical
/// devices on the same Wi-Fi can reach the backend. Override with
/// --dart-define=API_URL=... (e.g. http://10.0.2.2:4000/api/v1 for the emulator).
class ApiConfig {
  ApiConfig._();

  static const _override = String.fromEnvironment('API_URL');

  /// Dev machine's LAN address (same Wi-Fi as the phone).
  static const _lanUrl = 'http://192.168.100.8:4000/api/v1';

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (kIsWeb) return 'http://localhost:4000/api/v1';
    return _lanUrl;
  }

  static const connectTimeout = Duration(seconds: 20);
  // AI chat can run several model rounds (thinking + tool calls); allow ample
  // time before giving up so slow AgentRouter/Gemini answers still arrive.
  static const receiveTimeout = Duration(seconds: 180);
}
