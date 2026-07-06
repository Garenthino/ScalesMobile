import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../data/repositories/venue_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../services/venue_storage.dart';
import '../../../core/constants/app_constants.dart';

/// QR Scanner for venue discovery.
///
/// Scans a QR code containing a venue code, looks it up, and
/// if valid, stores it and proceeds to the onboarding confirmation.
class VenueQrScannerScreen extends StatefulWidget {
  const VenueQrScannerScreen({super.key});

  @override
  State<VenueQrScannerScreen> createState() => _VenueQrScannerScreenState();
}

class _VenueQrScannerScreenState extends State<VenueQrScannerScreen> {
  final _repo = VenueRepository();
  bool _processing = false;
  String? _error;

  Future<void> _onScan(String code) async {
    if (_processing) return;
    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      // QR code format: "SCALES:{venue_code}" or just the code
      final venueCode = code.toUpperCase().replaceFirst('SCALES:', '');
      if (venueCode.length != 6) {
        setState(() => _error = 'Invalid QR code format.');
        return;
      }

      final venue = await _repo.lookupByCode(venueCode);
      if (venue == null) {
        setState(() => _error = 'Venue not found. Please check your QR code.');
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
      await storage.setActiveVenue(venue.id);
      await storage.setOnboardingComplete(true);

      // If already logged in as global account, join this venue immediately
      final accountToken = storage.getAccountToken();
      if (accountToken != null && accountToken.isNotEmpty) {
        final authRepo = AccountAuthRepository();
        final venueResult = await authRepo.joinVenue(
          venueId: venue.id,
          accountToken: accountToken,
        );
        await storage.setToken(venue.id, venueResult.accessToken);
        await storage.setRefreshToken(venue.id, venueResult.refreshToken);
        await storage.setSingerId(venue.id, venueResult.singerId);
        if (mounted) {
          context.go(RoutePaths.home);
          return;
        }
      }

      if (mounted) {
        context.go(RoutePaths.auth);
      }
    } catch (e) {
      setState(() => _error = 'Network error. Please try again.');
    } finally {
      setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Venue QR'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final value = barcode.rawValue;
                if (value != null && value.isNotEmpty) {
                  _onScan(value);
                  break;
                }
              }
            },
          ),
          // Overlay instructions
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: Column(
              children: [
                if (_error != null)
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                if (_processing)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('Looking up venue...'),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Text(
                    'Point your camera at the venue QR code',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
