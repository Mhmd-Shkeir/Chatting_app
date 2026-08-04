import 'package:flutter/material.dart';

class AppWordmark extends StatelessWidget {
  const AppWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Lumina Chat',
      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}
