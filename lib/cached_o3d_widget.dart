// cached_o3d_widget.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:o3d/o3d.dart';

import 'glb_cache_manager.dart';

class CachedO3D extends StatefulWidget {
  final String glbPath;
  final bool autoPlay;
  final bool cameraControls;
  final double? width;
  final double? height;
  final bool ar;
  final Color backgroundColor;
  final String cacheKey;

  const CachedO3D({
    super.key,
    required this.glbPath,
    this.autoPlay = true,
    this.cameraControls = false,
    this.width,
    this.height,
    this.ar = false,
    this.backgroundColor = Colors.transparent,
    this.cacheKey = '',
  });

  @override
  State<CachedO3D> createState() => _CachedO3DState();
}

class _CachedO3DState extends State<CachedO3D> {
  late O3DController _controller;
  Future<void>? _assetPreloadFuture;
  final GLBCacheManager _cacheManager = GLBCacheManager();
  bool _isInitialized = false;

  String get _effectiveCacheKey =>
      widget.cacheKey.isNotEmpty ? widget.cacheKey : widget.glbPath;

  String _effectiveCacheKeyFor(CachedO3D widget) {
    return widget.cacheKey.isNotEmpty ? widget.cacheKey : widget.glbPath;
  }

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  @override
  void didUpdateWidget(CachedO3D oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldCacheKey = _effectiveCacheKeyFor(oldWidget);
    final newCacheKey = _effectiveCacheKey;

    // Important:
    // Do NOT remove the cached controller when only the widget key changes.
    // The map uses refresh keys often, and removing here makes the dialog reload.
    // Reinitialize only when the actual GLB/cache key changes.
    if (oldCacheKey != newCacheKey || oldWidget.glbPath != widget.glbPath) {
      if (kDebugMode) {
        print('🔄 Model changed, using cached/new controller for: ${widget.glbPath}');
      }

      _initializeController();
    }
  }

  void _initializeController() {
    _assetPreloadFuture = _cacheManager.preloadAsset(widget.glbPath);

    final cachedController = _cacheManager.getController(_effectiveCacheKey);

    if (cachedController != null) {
      _controller = cachedController;
      _isInitialized = true;

      if (kDebugMode) {
        print('⚡ Reusing cached controller for: ${widget.glbPath}');
      }
    } else {
      _controller = O3DController();
      _cacheManager.cacheController(_effectiveCacheKey, _controller);
      _isInitialized = true;

      if (kDebugMode) {
        print('🔄 Created new controller for: ${widget.glbPath}');
      }
    }

    _cacheManager.markAsDisplayed(_effectiveCacheKey);
  }

  @override
  void dispose() {
    // Do not dispose the controller here because it is cached globally.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = O3D(
      controller: _controller,
      src: widget.glbPath,
      autoPlay: widget.autoPlay,
      cameraControls: widget.cameraControls,
      ar: widget.ar,
      backgroundColor: widget.backgroundColor,
      autoRotate: false,
      loading: Loading.eager,
      key: ValueKey(_effectiveCacheKey),
    );

    Widget child;

    if (!_isInitialized) {
      child = const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
        ),
      );
    } else if (_cacheManager.isAssetPreloaded(widget.glbPath)) {
      child = model;
    } else {
      child = FutureBuilder<void>(
        future: _assetPreloadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done ||
              snapshot.hasError) {
            return model;
          }

          return const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
            ),
          );
        },
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: child,
    );
  }
}
