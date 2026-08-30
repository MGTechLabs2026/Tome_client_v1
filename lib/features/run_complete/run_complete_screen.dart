// lib/features/run_complete/run_complete_screen.dart
import 'package:flutter/material.dart';

class RunCompleteScreen extends StatelessWidget {
  const RunCompleteScreen({super.key, required this.onRestart});
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Run Complete!', style: TextStyle(fontSize: 28)),
          FilledButton(onPressed: onRestart, child: const Text('Start New Run')),
        ]),
      ),
    );
  }
}
