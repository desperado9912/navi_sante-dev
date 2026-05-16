import 'package:flutter/material.dart';
import 'package:navi_sante/features/shared/widgets/platform_adaptive_app_bar.dart';

class SavedFacilities extends StatelessWidget {
  const SavedFacilities({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Facilities')),
      body: const Center(
        child: Text('Saved Facilities'),
      ),
    );
  }
}