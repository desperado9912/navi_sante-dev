import 'package:flutter/material.dart';
import 'package:navi_sante/core/performance/memory_leak_tracker.dart';
import 'package:navi_sante/core/utils/platform_adaptive_app_bar.dart';

class SavedFacilities extends StatefulWidget {
  const SavedFacilities({super.key});

  @override
  State<SavedFacilities> createState() => _SavedFacilitiesState();
}

class _SavedFacilitiesState extends State<SavedFacilities> {
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
      appBar: const PlatformAdaptiveAppBar(title: 'Saved Facilities'),

      body: const Center(),
    );
  }
}
