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
  final String cacheKey; // Optional custom cache key

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
  late final O3DController _controller;
  final GLBCacheManager _cacheManager = GLBCacheManager();
  bool _isInitialized = false;
  String get _effectiveCacheKey => widget.cacheKey.isNotEmpty ? widget.cacheKey : widget.glbPath;

  @override
  void initState() {
    super.initState();

    // Check if we have a cached controller
    final cachedController = _cacheManager.getController(_effectiveCacheKey);

    if (cachedController != null) {
      // Reuse cached controller
      _controller = cachedController;
      _isInitialized = true;
      if (kDebugMode) {
        print('⚡ Reusing cached controller for: ${widget.glbPath}');
      }
    } else {
      // Create new controller and cache it
      _controller = O3DController();
      _cacheManager.cacheController(_effectiveCacheKey, _controller);
      _isInitialized = true;
      if (kDebugMode) {
        print('🔄 Created new controller for: ${widget.glbPath}');
      }
    }

    // Mark this model as displayed
    _cacheManager.markAsDisplayed(_effectiveCacheKey);
  }

  @override
  void dispose() {
    // We DON'T dispose the controller here because it's cached globally
    // The cache manager will handle cleanup when appropriate
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: _isInitialized
          ? O3D(
        controller: _controller,
        src: widget.glbPath,
        autoPlay: widget.autoPlay,
        cameraControls: widget.cameraControls,
        ar: widget.ar,
        backgroundColor: widget.backgroundColor,
        autoRotate: false,
        loading: Loading.eager,
      )
          : const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
        ),
      ),
    );
  }
}