//Load inner characters data from JSON file.
import 'dart:convert';

import 'package:flutter/services.dart';

import 'package:ana_ifs_app/features/chat/data/models/inner_character_profile.dart';

class InnerCharacterLocalDataSource {
  Future<InnerCharacterProfile?> getCharacterById(String id) async {
    final raw = await rootBundle.loadString(
      'assets/data/inner_characters_data.json',
    );
    final List<dynamic> decoded = json.decode(raw);
    for (final entry in decoded) {
      if (entry is Map<String, dynamic> && entry['id'] == id) {
        return InnerCharacterProfile.fromJson(entry);
      }
    }
    return null;
  }

  //Find a character by name.
  Future<InnerCharacterProfile?> findCharacterByName(String name) async {
    final raw = await rootBundle.loadString(
      'assets/data/inner_characters_data.json',
    );
    final List<dynamic> decoded = json.decode(raw);
    final targetNames = <String>{
      _normalize(name),
      _compact(name),
    }..removeWhere((value) => value.isEmpty);

    for (final entry in decoded) {
      if (entry is Map<String, dynamic>) {
        final displayName = entry['displayName']?.toString() ?? '';
        final id = entry['id']?.toString() ?? '';
        final normalizedDisplay = _normalize(displayName);
        final normalizedId = _normalize(id);
        final compactDisplay = _compact(displayName);
        final compactId = _compact(id);
        final matches = targetNames.any(
          (target) =>
              target == normalizedDisplay ||
              target == normalizedId ||
              target == compactDisplay ||
              target == compactId ||
              target.contains(normalizedDisplay) ||
              normalizedDisplay.contains(target) ||
              target.contains(compactDisplay) ||
              compactDisplay.contains(target),
        );
        if (matches) {
          return InnerCharacterProfile.fromJson(entry);
        }
      }
    }
    return null;
  }

  //Normalize a string by removing special characters and converting to lowercase.
  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s_]'), '')
        .replaceAll('the ', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _compact(String value) {
    return _normalize(value).replaceAll(' ', '');
  }
}
