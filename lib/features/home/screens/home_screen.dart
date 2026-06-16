import 'package:flutter/material.dart';
import '../widgets/map_widget.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScaffoldMessenger(
      child: Scaffold(resizeToAvoidBottomInset: false, body: HomeMapWidget()),
    );
  }
}
