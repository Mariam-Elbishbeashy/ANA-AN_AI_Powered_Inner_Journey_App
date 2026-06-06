// glb_cache_manager.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

  // Asset preload cache. The map warms this cache before opening details,
  // so the dialog can show the already loaded GLB faster.
  final Set<String> _preloadedAssets = <String>{};
  final Map<String, Future<void>> _assetPreloadFutures =
  <String, Future<void>>{};

  bool isAssetPreloaded(String glbPath) {
    return _preloadedAssets.contains(glbPath);
  }

  Future<void> preloadAsset(String glbPath) {
    if (glbPath.trim().isEmpty || _preloadedAssets.contains(glbPath)) {
      return Future<void>.value();
    }

    return _assetPreloadFutures.putIfAbsent(glbPath, () async {
      try {
        await rootBundle.load(glbPath);
        _preloadedAssets.add(glbPath);

        if (kDebugMode) {
          print('⚡ Preloaded GLB asset: $glbPath');
        }
      } catch (e) {
        _assetPreloadFutures.remove(glbPath);

        if (kDebugMode) {
          print('⚠️ Failed to preload GLB asset $glbPath: $e');
        }

        rethrow;
      }
    });
  }

  Future<void> preloadAssets(Iterable<String> glbPaths) async {
    final uniquePaths = glbPaths
        .where((path) => path.trim().isNotEmpty)
        .toSet()
        .toList();

    for (final path in uniquePaths) {
      try {
        await preloadAsset(path);
      } catch (_) {
        // Continue preloading the remaining models even if one asset is missing.
      }
    }
  }

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
    _preloadedAssets.clear();
    _assetPreloadFutures.clear();

    if (kDebugMode) {
      print('🧹 Cleared all GLB cache');
    }
  }

  int getVersion(String glbPath) {
    return _cacheVersions[glbPath] ?? 0;
  }
}