import 'package:flutter/material.dart';
import 'package:navi_sante/core/performance/memory_leak_tracker.dart';
import 'package:navi_sante/core/utils/platform_adaptive_app_bar.dart';

class FavouriteProducts extends StatefulWidget {
  const FavouriteProducts({super.key});

  @override
  State<FavouriteProducts> createState() => _FavouriteProductsState();
}

class _FavouriteProductsState extends State<FavouriteProducts> {
  @override
  void initState() {
    super.initState();
    MemoryLeakTracker.logInit(this);
  }

  @override
  void dispose() {
    MemoryLeakTracker.logDispose(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PlatformAdaptiveAppBar(title: 'Favourite Products'),

      body: const Center(),
    );
  }
}
