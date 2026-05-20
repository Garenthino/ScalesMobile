import 'package:flutter/material.dart';

class VenueDetailScreen extends StatelessWidget {
  final String venueId;

  const VenueDetailScreen({super.key, required this.venueId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Venue')),
      body: Center(
        child: Text(
          'Venue: $venueId',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}
