import 'package:flutter/material.dart';

class AppWordmark extends StatelessWidget {
  const AppWordmark({this.textAlign, super.key});

  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Lumina Chat',
      textAlign: textAlign,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}
