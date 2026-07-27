import 'package:shared_preferences/shared_preferences.dart';

class AppPrefs {
  AppPrefs._();
  static final instance = AppPrefs._();

  static const _kOnboarded = 'ft_onboarded';

  Future<bool> get onboarded async =>
      (await SharedPreferences.getInstance()).getBool(_kOnboarded) ?? false;

  Future<void> setOnboarded() async =>
      (await SharedPreferences.getInstance()).setBool(_kOnboarded, true);
}
