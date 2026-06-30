import 'package:flutter/material.dart';

import 'home_screen.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sanket',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: const HomeScreen(),
    );
  }
}
