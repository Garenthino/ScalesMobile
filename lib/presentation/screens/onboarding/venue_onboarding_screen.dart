import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/repositories/venue_repository.dart';
import '../../../services/venue_storage.dart';
import '../../../core/constants/app_constants.dart';

/// Onboarding screen — first launch after install.
///
/// The user enters a venue code to discover their karaoke venue.
/// Once resolved, the venue is cached and the app proceeds to auth.
class VenueOnboardingScreen extends ConsumerStatefulWidget {
  const VenueOnboardingScreen({super.key});

  @override
  ConsumerState<VenueOnboardingScreen> createState() => _VenueOnboardingScreenState();
}

class _VenueOnboardingScreenState extends ConsumerState<VenueOnboardingScreen> {
  final _codeCtrl = TextEditingController();
  final _repo = VenueRepository();
  bool _loading = false;
  String? _error;
  VenueCompact? _foundVenue;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _error = 'Please enter a 6-character venue code.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _foundVenue = null;
    });

    try {
      final venue = await _repo.lookupByCode(code);
      if (venue == null) {
        setState(() => _error = 'Venue not found. Please check your code.');
        return;
      }
      setState(() => _foundVenue = venue);
    } catch (e) {
      setState(() => _error = 'Network error. Please try again.');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _confirmVenue() async {
    final venue = _foundVenue;
    if (venue == null) return;

    final storage = await VenueStorage.create();
    await storage.saveVenue(CachedVenue(
      id: venue.id,
      name: venue.name,
      slug: venue.slug,
      venueCode: venue.venueCode,
      timezone: venue.timezone,
      isActive: venue.isActive,
    ));
    await storage.setActiveVenue(venue.id);
    await storage.setOnboardingComplete(true);

    if (mounted) {
      context.go(RoutePaths.auth);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              Icon(
                Icons.music_note,
                size: 64,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Welcome to Scales',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your venue code to get started.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _codeCtrl,
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                enabled: !_loading,
                decoration: InputDecoration(
                  labelText: 'Venue Code',
                  hintText: 'e.g. GOLDEN',
                  prefixIcon: const Icon(Icons.place),
                  errorText: _error,
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onSubmitted: (_) => _lookup(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loading ? null : _lookup,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Find Venue'),
              ),
              // QR code scanning placeholder — will be wired up later
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  context.push('/scan-qr');
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan QR Code'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (_foundVenue != null) ...[
                const SizedBox(height: 32),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: colorScheme.primary,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _foundVenue!.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Code: ${_foundVenue!.venueCode}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _confirmVenue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Join This Venue'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
