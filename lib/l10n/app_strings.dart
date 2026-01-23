import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/localization/app_language_provider.dart';

String tr(BuildContext context, String en, String ar, {bool listen = true}) {
  final isArabic = listen
      ? context.watch<AppLanguageProvider>().isArabic
      : context.read<AppLanguageProvider>().isArabic;
  return isArabic ? ar : en;
}

bool isArabic(BuildContext context, {bool listen = true}) {
  return listen
      ? context.watch<AppLanguageProvider>().isArabic
      : context.read<AppLanguageProvider>().isArabic;
}
