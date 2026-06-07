import 'package:flutter/material.dart';
import 'package:navi_sante/core/utils/platform_adaptive_app_bar.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PlatformAdaptiveAppBar(title: 'Notifications settings'),

      body: const Center(
        
      ),
    );
  }
}
