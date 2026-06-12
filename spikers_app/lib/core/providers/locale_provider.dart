import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App locale with SharedPreferences persistence. Replaces the GetX
/// LocaleController.
class LocaleNotifier extends Notifier<Locale> {
  static const _prefKey = 'locale';

  @override
  Locale build() {
    _loadSaved();
    return const Locale('en');
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefKey) ?? 'en';
    state = Locale(code);
  }

  bool get isArabic => state.languageCode == 'ar';

  Future<void> toggle() async {
    final next = isArabic ? const Locale('en') : const Locale('ar');
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, next.languageCode);
  }
}

final localeProvider =
    NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);
