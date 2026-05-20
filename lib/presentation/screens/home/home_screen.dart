import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scales')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.queue_music),
            title: const Text('My Queue'),
            onTap: () => context.push(RoutePaths.singerQueue),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profile'),
            onTap: () => context.push(RoutePaths.singerProfile),
          ),
          ListTile(
            leading: const Icon(Icons.location_on),
            title: const Text('Venues'),
            subtitle: const Text('Explore nearby venues'),
            onTap: () => context.push('/venue/demo_venue_id'),
          ),
        ],
      ),
    );
  }
}
