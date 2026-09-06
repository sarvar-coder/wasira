import 'package:flutter/material.dart';

void main() => runApp(const WasiraApp());

class WasiraApp extends StatelessWidget {
  const WasiraApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Wasira',
        home: const Scaffold(body: Center(child: Text('Wasira'))),
      );
}
