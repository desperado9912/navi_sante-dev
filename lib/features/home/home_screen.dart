import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("navbar", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
      ), 

      bottomNavigationBar: NavigationBar(destinations: [
        NavigationDestination(icon: Icon(Icons.home_outlined), label: "Home"),
        NavigationDestination(icon: Icon(Icons.home_outlined), label: "Home"),
        NavigationDestination(icon: Icon(Icons.home_outlined), label: "Home"),
        NavigationDestination(icon: Icon(Icons.home_outlined), label: "Home"),
      ])
    );
  }
}
