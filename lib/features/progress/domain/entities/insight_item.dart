// insight_item.dart
import 'package:flutter/material.dart';
import 'package:ana_ifs_app/l10n/app_strings.dart';

enum InsightType {
  newlyDiscovered,
  stable,
  inactive,
  active,
}

class InsightItem {
  final String id;
  final String characterName;
  final String displayNameEn;
  final String displayNameAr;
  final String archetype;
  final InsightType type;
  final DateTime date;
  final String messageEn;
  final String messageAr;

  InsightItem({
    required this.id,
    required this.characterName,
    required this.displayNameEn,
    required this.displayNameAr,
    required this.archetype,
    required this.type,
    required this.date,
    required this.messageEn,
    required this.messageAr,
  });

  String getDisplayName(BuildContext context) {
    return isArabic(context) ? displayNameAr : displayNameEn;
  }

  String getMessage(BuildContext context) {
    return isArabic(context) ? messageAr : messageEn;
  }
}
