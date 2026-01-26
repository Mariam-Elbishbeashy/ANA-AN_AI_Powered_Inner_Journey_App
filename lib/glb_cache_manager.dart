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

  O3DController? getController(String glbPath) {
    return _controllerCache[glbPath];
  }

  void cacheController(String glbPath, O3DController controller) {
    _controllerCache[glbPath] = controller;
    if (kDebugMode) {
      print('✅ Cached controller for: $glbPath');
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
    // Note: O3DController doesn't have dispose(), it handles its own cleanup
    if (kDebugMode) {
      print('🗑️ Removed from cache: $glbPath');
    }
  }

  void clearCache() {
    _controllerCache.clear();
    _displayedModels.clear();
    if (kDebugMode) {
      print('🧹 Cleared all GLB cache');
    }
  }
}