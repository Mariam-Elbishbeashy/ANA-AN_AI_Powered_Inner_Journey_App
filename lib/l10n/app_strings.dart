import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_language_provider.dart';

String tr(BuildContext context, String en, String ar) {
  final isArabic = context.watch<AppLanguageProvider>().isArabic;
  return isArabic ? ar : en;
}

bool isArabic(BuildContext context) {
  return context.watch<AppLanguageProvider>().isArabic;
}
