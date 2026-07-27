class UserSettings {
  final String language;
  final String currency;
  final String theme;
  final bool notificationsEnabled;
  final bool emailNotifications;
  final bool aiEnabled;
  final String aiProvider;
  final String geminiModel;
  final String agentRouterModel;

  UserSettings({
    required this.language,
    required this.currency,
    required this.theme,
    this.notificationsEnabled = true,
    this.emailNotifications = true,
    this.aiEnabled = true,
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
        aiEnabled: j['aiEnabled'] ?? true,
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

  AppUser({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.avatarUrl,
    this.emailVerified = false,
    this.settings,
  });

  String get displayName {
    final n = [firstName, lastName].where((e) => e != null && e.isNotEmpty).join(' ');
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
      );
}
