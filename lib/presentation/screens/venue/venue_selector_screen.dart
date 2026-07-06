import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../presentation/providers/auth_provider.dart';
import '../../../services/venue_storage.dart';
import '../../../data/repositories/venue_repository.dart';

/// Venue selector screen: pick from joined venues or add a new venue by code.
class VenueSelectorScreen extends ConsumerStatefulWidget {
  const VenueSelectorScreen({super.key});

  @override
  ConsumerState<VenueSelectorScreen> createState() => _VenueSelectorScreenState();
}

class _VenueSelectorScreenState extends ConsumerState<VenueSelectorScreen> {
  final _codeCtrl = TextEditingController();
  bool _isJoining = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectVenue(CachedVenue venue) async {
    final notifier = ref.read(authProvider.notifier);
    final ok = await notifier.switchVenue(venue.id);
    if (mounted) {
      if (ok) {
        context.go(RoutePaths.home);
      } else {
        setState(() => _error = 'Could not switch venues. Please sign in again.');
      }
    }
  }

  Future<void> _joinByCode() async {
    final code = _codeCtrl.text.trim().toUpperCase().replaceFirst('SCALES:', '');
    if (code.length != 6) {
      setState(() => _error = 'Enter a 6-character venue code.');
      return;
    }

    setState(() {
      _isJoining = true;
      _error = null;
    });

    try {
      final repo = VenueRepository();
      final venue = await repo.lookupByCode(code);
      if (venue == null) {
        setState(() => _error = 'Venue not found.');
        return;
      }

      final storage = await VenueStorage.create();
      await storage.saveVenue(CachedVenue(
        id: venue.id,
        name: venue.name,
        slug: venue.slug,
        venueCode: venue.venueCode,
        timezone: venue.timezone,
        isActive: venue.isActive,
      ));

      final notifier = ref.read(authProvider.notifier);
      final ok = await notifier.switchVenue(venue.id);
      if (mounted) {
        if (ok) {
          context.go(RoutePaths.home);
        } else {
          setState(() => _error = 'Could not join venue. Please sign in again.');
        }
      }
    } catch (e) {
      setState(() => _error = 'Network error: $e');
    } finally {
      setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final venuesAsync = ref.watch(savedVenuesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Select Venue')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Where are you singing tonight?',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              venuesAsync.when(
                data: (venues) => venues.isEmpty
                    ? Text(
                        'No venues yet. Add one below.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    : Column(
                        children: venues
                            .map((v) => Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      child: Text(v.name.substring(0, 1)),
                                    ),
                                    title: Text(v.name),
                                    subtitle: Text('Code: ${v.venueCode}'),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => _selectVenue(v),
                                  ),
                                ))
                            .toList(),
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e', textAlign: TextAlign.center),
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Join a new venue',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _codeCtrl,
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'Venue Code',
                  hintText: 'SCALES:XXXXXX',
                  prefixIcon: const Icon(Icons.qr_code),
                  errorText: _error,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isJoining ? null : _joinByCode,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isJoining
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Join Venue'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go(RoutePaths.auth),
                child: const Text('Use a different account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Provider that exposes saved venues from local storage.
final savedVenuesProvider = FutureProvider<List<CachedVenue>>((ref) async {
  final storage = await VenueStorage.create();
  return storage.getVenues();
});
