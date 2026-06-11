import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleController extends GetxController {
  static const _prefKey = 'locale';

  final currentLocale = const Locale('en').obs;

  bool get isArabic => currentLocale.value.languageCode == 'ar';

  @override
  void onInit() {
    super.onInit();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefKey) ?? 'en';
    final locale = Locale(code);
    currentLocale.value = locale;
    Get.updateLocale(locale);
  }

  Future<void> toggle() async {
    final next = isArabic ? const Locale('en') : const Locale('ar');
    currentLocale.value = next;
    Get.updateLocale(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, next.languageCode);
  }
}
