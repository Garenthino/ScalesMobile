import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scales_mobile/core/constants/app_constants.dart';
import 'package:scales_mobile/data/repositories/venue_repository.dart';
import 'package:scales_mobile/services/venue_storage.dart';

final venueDetailProvider = FutureProvider.autoDispose
    .family<VenueDetail?, String>((ref, id) async {
  final repo = VenueRepository();
  return repo.fetchVenue(id);
});

class VenueDetailScreen extends ConsumerWidget {
  final String venueId;

  const VenueDetailScreen({super.key, required this.venueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venueAsync = ref.watch(venueDetailProvider(venueId));

    return Scaffold(
      appBar: AppBar(title: const Text('Venue')),
      body: venueAsync.when(
        data: (venue) {
          if (venue == null) {
            return const Center(child: Text('Venue not found.'));
          }
          return _VenueBody(venue: venue);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _VenueBody extends StatelessWidget {
  final VenueDetail venue;

  const _VenueBody({required this.venue});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (venue.logoUrl != null && venue.logoUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                venue.logoUrl!,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            venue.name,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          if (venue.address != null)
            _InfoRow(icon: Icons.location_on, text: venue.address!),
          if (venue.phone != null)
            _InfoRow(icon: Icons.phone, text: venue.phone!),
          if (venue.capacity != null)
            _InfoRow(icon: Icons.groups, text: 'Capacity: ${venue.capacity}'),
          if (venue.description != null) ...[
            const SizedBox(height: 16),
            Text(
              venue.description!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final storage = await VenueStorage.create();
                final cached = storage.getVenues().firstWhere(
                  (v) => v.id == venue.id,
                  orElse: () => throw StateError('Venue not saved'),
                );
                await storage.saveVenue(cached);
                await storage.setActiveVenue(venue.id);
                if (context.mounted) {
                  context.go(RoutePaths.checkIn, extra: venue.id);
                }
              },
              icon: const Icon(Icons.login),
              label: const Text('Check In Here'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
