import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:scales_mobile/core/constants/app_constants.dart';

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
            subtitle: const Text('Manage your song requests'),
            onTap: () => context.push(RoutePaths.singerQueue),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profile'),
            subtitle: const Text('View stats, history, QR code'),
            onTap: () => context.push(RoutePaths.singerProfile),
          ),
          ListTile(
            leading: const Icon(Icons.login),
            title: const Text('Check In'),
            subtitle: const Text('Join a venue queue'),
            onTap: () => context.push(RoutePaths.checkIn),
          ),
          ListTile(
            leading: const Icon(Icons.emoji_events),
            title: const Text('Leaderboard'),
            subtitle: const Text('Top singers at your venue'),
            onTap: () => context.push(RoutePaths.leaderboard),
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
