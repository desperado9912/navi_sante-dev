import 'package:flutter/material.dart';
import 'package:navi_sante/features/shared/widgets/platform_adaptive_app_bar.dart';

class SavedFacilities extends StatelessWidget {
  const SavedFacilities({super.key});

  @override
  Widget build(BuildContext context) {


    return Scaffold(
      appBar: const PlatformAdaptiveAppBar(title: 'Saved Facilities'),
      backgroundColor: Color(0xFFF8F9F8),

      body: const Center(
        
      ),
    );
  }
}