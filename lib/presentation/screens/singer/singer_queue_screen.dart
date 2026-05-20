import 'package:flutter/material.dart';

class SingerQueueScreen extends StatelessWidget {
  const SingerQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Queue')),
      body: Center(
        child: Text('Queue placeholder', style: Theme.of(context).textTheme.headlineSmall),
      ),
    );
  }
}
