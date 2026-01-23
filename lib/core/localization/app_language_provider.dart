import 'package:flutter/material.dart';

import 'package:ana_ifs_app/core/services/firestore_service.dart';

class AppLanguageProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  String _language = 'en';

  AppLanguageProvider() {
    _loadLanguage();
  }

  String get language => _language;
  bool get isArabic => _language == 'ar';

  Future<void> _loadLanguage() async {
    try {
      _language = await _firestoreService.getUserLanguage();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setLanguage(String language) async {
    if (_language == language) return;
    _language = language;
    notifyListeners();
    try {
      await _firestoreService.setUserLanguage(language);
    } catch (_) {}
  }

  Future<void> toggleLanguage() async {
    final next = _language == 'ar' ? 'en' : 'ar';
    await setLanguage(next);
  }
}
