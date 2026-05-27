import 'package:flutter/material.dart';

class VenueDetailScreen extends StatelessWidget {
  final String venueId;

  const VenueDetailScreen({super.key, required this.venueId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Venue')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Venue ID', style: Theme.of(context).textTheme.labelSmall),
            Text(venueId, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Text(
              'Venue details will be fetched from the API in a future sprint.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            const Card(
              child: ListTile(
                leading: Icon(Icons.queue_music),
                title: Text('Current Queue'),
                subtitle: Text('12 singers'),
                trailing: Icon(Icons.chevron_right),
              ),
            ),
            const SizedBox(height: 12),
            const Card(
              child: ListTile(
                leading: Icon(Icons.location_on),
                title: Text('Address'),
                subtitle: Text('123 Main St, Music City'),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Navigate to check-in with this venue pre-filled
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Redirecting to check-in...')),
                  );
                },
                icon: const Icon(Icons.login),
                label: const Text('Check In Here'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
