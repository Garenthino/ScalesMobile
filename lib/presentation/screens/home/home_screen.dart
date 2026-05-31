import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../services/venue_storage.dart';

/// Home screen — singer dashboard.
///
/// Shows venue-branded header and navigation to core features.
/// The active venue name is pulled from local storage.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  CachedVenue? _activeVenue;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVenue();
  }

  Future<void> _loadVenue() async {
    final storage = await VenueStorage.create();
    setState(() {
      _activeVenue = storage.getActiveVenue();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final venueName = _activeVenue?.name ?? 'Scales';

    return Scaffold(
      appBar: AppBar(
        title: Text(venueName),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Switch venue',
            onPressed: () => context.push('/venue/switch'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Venue branding header
                if (_activeVenue != null)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: theme.colorScheme.primary,
                          child: Icon(
                            Icons.music_note,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                venueName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Code: ${_activeVenue!.venueCode}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ListTile(
                  leading: const Icon(Icons.library_music),
                  title: const Text('Browse Songs'),
                  subtitle: const Text('Search the active venue catalog'),
                  onTap: () => context.push(RoutePaths.songBrowser),
                ),
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
                  onTap: () {
                    final vid = _activeVenue?.id ?? 'default_venue';
                    context.push(RoutePaths.leaderboard, extra: vid);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.location_on),
                  title: const Text('Venues'),
                  subtitle: const Text('View your active venue details'),
                  enabled: _activeVenue != null,
                  onTap: _activeVenue == null
                      ? null
                      : () => context.push('/venue/${_activeVenue!.id}'),
                ),
              ],
            ),
    );
  }
}
