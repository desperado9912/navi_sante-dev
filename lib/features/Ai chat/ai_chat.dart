import 'package:flutter/material.dart';
import 'package:navi_sante/core/performance/memory_leak_tracker.dart';
import 'package:navi_sante/core/utils/platform_adaptive_app_bar.dart';

class AIChatPage extends StatefulWidget {
  const AIChatPage({super.key});

  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
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
      appBar: const PlatformAdaptiveAppBar(title: 'AI Chat'),
      backgroundColor: Color(0xFFF8F9F8),

      body: const Center(),
    );
  }
}
