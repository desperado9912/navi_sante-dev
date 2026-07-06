import 'package:flutter/material.dart';
import '../maps/map_widget.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      resizeToAvoidBottomInset: false,
      body: HomeMapWidget(),
    );
  }
}
