import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../services/venue_storage.dart';
import '../../../core/constants/app_constants.dart';

/// Venue switcher screen — accessible from home/profile.
///
/// Shows all cached venues, allows switching active venue,
/// and provides entry to onboard a new venue.
class VenueSwitcherScreen extends ConsumerStatefulWidget {
  const VenueSwitcherScreen({super.key});

  @override
  ConsumerState<VenueSwitcherScreen> createState() => _VenueSwitcherScreenState();
}

class _VenueSwitcherScreenState extends ConsumerState<VenueSwitcherScreen> {
  List<CachedVenue> _venues = [];
  String? _activeVenueId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVenues();
  }

  Future<void> _loadVenues() async {
    final storage = await VenueStorage.create();
    setState(() {
      _venues = storage.getVenues();
      _activeVenueId = storage.getActiveVenueId();
      _loading = false;
    });
  }

  Future<void> _switchVenue(String venueId) async {
    if (venueId == _activeVenueId) {
      context.pop();
      return;
    }
    final storage = await VenueStorage.create();
    await storage.setActiveVenue(venueId);
    // Clear auth for the new venue context
    await storage.clearToken(venueId);
    setState(() => _activeVenueId = venueId);
    if (mounted) {
      context.go(RoutePaths.auth);
    }
  }

  Future<void> _removeVenue(String venueId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Venue?'),
        content: const Text(
          'This will remove the venue from your device. Your singer account and points remain on the server.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Remove',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final storage = await VenueStorage.create();
    await storage.removeVenue(venueId);
    await _loadVenues();

    // If we removed the active venue and there's nothing left, go to onboarding
    if (_venues.isEmpty && mounted) {
      context.go(RoutePaths.onboarding);
    }
  }

  Future<void> _addVenue() async {
    // Reset onboarding so they can enter a new code
    final storage = await VenueStorage.create();
    await storage.setOnboardingComplete(false);
    await storage.clearActiveVenue();
    if (mounted) {
      context.go(RoutePaths.onboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Venues'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addVenue,
            tooltip: 'Add venue',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _venues.isEmpty
              ? _buildEmptyState(theme)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _venues.length,
                  itemBuilder: (context, index) {
                    final venue = _venues[index];
                    final isActive = venue.id == _activeVenueId;
                    return Card(
                      elevation: isActive ? 2 : 0,
                      color: isActive
                          ? theme.colorScheme.primaryContainer
                          : null,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isActive
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            isActive ? Icons.check : Icons.music_note,
                            color: isActive
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        title: Text(venue.name),
                        subtitle: Text('Code: ${venue.venueCode}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isActive)
                              Chip(
                                label: const Text('Active'),
                                backgroundColor: theme.colorScheme.primary,
                                labelStyle: TextStyle(
                                  color: theme.colorScheme.onPrimary,
                                  fontSize: 12,
                                ),
                              )
                            else
                              TextButton(
                                onPressed: () => _switchVenue(venue.id),
                                child: const Text('Switch'),
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _removeVenue(venue.id),
                              tooltip: 'Remove',
                            ),
                          ],
                        ),
                        onTap: isActive ? null : () => _switchVenue(venue.id),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_note_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No venues yet',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first venue to start singing.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _addVenue,
              icon: const Icon(Icons.add),
              label: const Text('Add Venue'),
            ),
          ],
        ),
      ),
    );
  }
}
