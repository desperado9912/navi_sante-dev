import 'package:flutter/material.dart';
import 'package:navi_sante/core/utils/platform_adaptive_app_bar.dart';


class FavouriteProducts extends StatelessWidget {
  const FavouriteProducts({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PlatformAdaptiveAppBar(title: 'Favourite Products'),
      backgroundColor: Color(0xFFF8F9F8),

      body: const Center(
        
      ),
    );
  }
}