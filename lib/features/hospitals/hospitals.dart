import 'package:flutter/material.dart';

class Hospitals extends StatelessWidget {
  const Hospitals({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "Hospitals",
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}