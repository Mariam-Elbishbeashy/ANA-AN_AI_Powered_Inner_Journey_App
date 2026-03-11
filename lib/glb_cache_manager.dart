// glb_cache_manager.dart
import 'package:flutter/foundation.dart';
import 'package:o3d/o3d.dart';

class GLBCacheManager {
  static final GLBCacheManager _instance = GLBCacheManager._internal();
  factory GLBCacheManager() => _instance;

  GLBCacheManager._internal();

  // Cache of O3DControllers by their GLB path
  final Map<String, O3DController> _controllerCache = {};

  // Keep track of which models are currently displayed
  final Map<String, bool> _displayedModels = {};

  // Add version tracking for each cached item
  final Map<String, int> _cacheVersions = {};

  O3DController? getController(String glbPath) {
    return _controllerCache[glbPath];
  }

  void cacheController(String glbPath, O3DController controller) {
    _controllerCache[glbPath] = controller;
    _cacheVersions[glbPath] = (_cacheVersions[glbPath] ?? 0) + 1;

    if (kDebugMode) {
      print('✅ Cached controller for: $glbPath (v${_cacheVersions[glbPath]})');
    }
  }

  void markAsDisplayed(String glbPath) {
    _displayedModels[glbPath] = true;
  }

  bool isDisplayed(String glbPath) {
    return _displayedModels[glbPath] ?? false;
  }

  void removeFromCache(String glbPath) {
    final controller = _controllerCache.remove(glbPath);
    _displayedModels.remove(glbPath);
    _cacheVersions.remove(glbPath);

    if (kDebugMode) {
      print('🗑️ Removed from cache: $glbPath');
    }
  }

  void clearCache() {
    _controllerCache.clear();
    _displayedModels.clear();
    _cacheVersions.clear();

    if (kDebugMode) {
      print('🧹 Cleared all GLB cache');
    }
  }

  int getVersion(String glbPath) {
    return _cacheVersions[glbPath] ?? 0;
  }
}