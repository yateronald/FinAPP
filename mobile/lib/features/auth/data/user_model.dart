class UserSettings {
  final String language;
  final String currency;
  final String theme;
  final bool notificationsEnabled;
  final bool emailNotifications;
  final bool aiEnabled;
  final DateTime? aiConsentAt;
  final String? aiConsentVersion;
  final String aiProvider;
  final String geminiModel;
  final String agentRouterModel;

  UserSettings({
    required this.language,
    required this.currency,
    required this.theme,
    this.notificationsEnabled = true,
    this.emailNotifications = true,
    this.aiEnabled = false,
    this.aiConsentAt,
    this.aiConsentVersion,
    this.aiProvider = 'GEMINI',
    this.geminiModel = 'gemini-3.5-flash',
    this.agentRouterModel = 'claude-opus-4-8',
  });

  factory UserSettings.fromJson(Map<String, dynamic> j) => UserSettings(
    language: j['language'] ?? 'FR',
    currency: j['currency'] ?? 'XOF',
    theme: j['theme'] ?? 'SYSTEM',
    notificationsEnabled: j['notificationsEnabled'] ?? true,
    emailNotifications: j['emailNotifications'] ?? true,
    // AI is always opt-in. Missing or older settings must never silently
    // turn it on in the client.
    aiEnabled: j['aiEnabled'] == true,
    aiConsentAt: j['aiConsentAt'] == null
        ? null
        : DateTime.tryParse(j['aiConsentAt'].toString()),
    aiConsentVersion: j['aiConsentVersion'] as String?,
    aiProvider: j['aiProvider'] ?? 'GEMINI',
    geminiModel: j['geminiModel'] ?? 'gemini-3.5-flash',
    agentRouterModel: j['agentRouterModel'] ?? 'claude-opus-4-8',
  );
}

class AppUser {
  final String id;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;
  final bool emailVerified;
  final UserSettings? settings;

  /// Which sign-in methods this account has. Google-created accounts start
  /// with no password, so Settings must offer "Set a password" rather than
  /// "Change password" (there is nothing to confirm against).
  final bool hasPassword;
  final bool hasGoogle;

  AppUser({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.avatarUrl,
    this.emailVerified = false,
    this.settings,
    this.hasPassword = true,
    this.hasGoogle = false,
  });

  String get displayName {
    final n = [
      firstName,
      lastName,
    ].where((e) => e != null && e.isNotEmpty).join(' ');
    return n.isNotEmpty ? n : email.split('@').first;
  }

  String get initials {
    final n = displayName.trim();
    return n.isEmpty ? '?' : n[0].toUpperCase();
  }

  String get currency => settings?.currency ?? 'XOF';

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    id: j['id'] ?? '',
    email: j['email'] ?? '',
    firstName: j['firstName'],
    lastName: j['lastName'],
    avatarUrl: j['avatarUrl'],
    emailVerified: j['emailVerified'] ?? false,
    settings: j['settings'] != null
        ? UserSettings.fromJson(Map<String, dynamic>.from(j['settings']))
        : null,
    // Only /users/me carries these. Elsewhere (login response) default to
    // "has a password" so we never wrongly hide the current-password field.
    hasPassword: j['hasPassword'] ?? true,
    hasGoogle: j['hasGoogle'] ?? false,
  );
}
