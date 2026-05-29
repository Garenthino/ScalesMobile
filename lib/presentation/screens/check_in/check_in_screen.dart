import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scales_mobile/core/constants/app_constants.dart';
import 'package:scales_mobile/domain/entities/singer_profile.dart';
import 'package:scales_mobile/presentation/providers/checkin_provider.dart';
import 'package:scales_mobile/presentation/providers/auth_provider.dart';
import 'package:scales_mobile/services/venue_storage.dart';

class CheckInScreen extends ConsumerWidget {
  const CheckInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final userId = switch (authState) {
      Authenticated(:final userId) => userId,
      _ => 'demo_user',
    };

    final currentCheckInAsync = ref.watch(currentCheckInProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('Check In')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            currentCheckInAsync.when(
              data: (checkIn) => _CurrentCheckInCard(checkIn: checkIn),
              loading: () => const LinearProgressIndicator(),
              error: (err, _) => Text('Error: $err'),
            ),
            const SizedBox(height: 24),
            _VenueCodeForm(userId: userId),
          ],
        ),
      ),
    );
  }
}

class _CurrentCheckInCard extends StatelessWidget {
  final CheckInResult checkIn;
  const _CurrentCheckInCard({required this.checkIn});

  @override
  Widget build(BuildContext context) {
    final bool active = checkIn.success && checkIn.venueName != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  active ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: active
                      ? Colors.greenAccent
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  active ? 'Checked In' : 'Not Checked In',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            if (active) ...[
              const SizedBox(height: 8),
              Text('Venue: ${checkIn.venueName}', style: Theme.of(context).textTheme.bodyLarge),
              if (checkIn.queuePosition != null)
                Text('Queue position: #${checkIn.queuePosition}',
                    style: Theme.of(context).textTheme.bodyMedium),
            ] else ...[
              const SizedBox(height: 8),
              Text(checkIn.message ?? 'You are not checked into any venue.',
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

class _VenueCodeForm extends ConsumerStatefulWidget {
  final String userId;
  const _VenueCodeForm({required this.userId});

  @override
  ConsumerState<_VenueCodeForm> createState() => _VenueCodeFormState();
}

class _VenueCodeFormState extends ConsumerState<_VenueCodeForm> {
  final _controller = TextEditingController();
  bool _isSubmitting = false;
  CheckInResult? _lastResult;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkIn() async {
    final code = _controller.text.trim();
    if (code.isEmpty) return;
    setState(() => _isSubmitting = true);

    // Look up venue by code to get the venue ID
    final storage = await VenueStorage.create();
    final venues = storage.getVenues();
    CachedVenue? venue;
    try {
      venue = venues.firstWhere((v) => v.venueCode == code.toUpperCase());
    } catch (e) {
      // no match
    }

    if (venue == null) {
      setState(() {
        _isSubmitting = false;
        _lastResult = const CheckInResult(
          success: false,
          message: 'Venue not found. Please enter a valid code.',
        );
      });
      return;
    }

    final repo = ref.read(checkInRepoProvider);
    final result = await repo.checkIn(venue.id, widget.userId, code: code);

    if (mounted) {
      setState(() {
        _isSubmitting = false;
        _lastResult = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Enter Venue Code',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Type the venue check-in code or scan a QR code to join the queue instantly.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          decoration: const InputDecoration(
            labelText: 'Venue Code',
            hintText: 'e.g. GOLDEN',
            prefixIcon: Icon(Icons.meeting_room),
          ),
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _checkIn(),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _isSubmitting ? null : _checkIn,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.login),
          label: const Text('Check In'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('QR scanner coming in a future update')),
            );
          },
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scan QR Code'),
        ),
        if (_lastResult != null) ...[
          const SizedBox(height: 24),
          _CheckInResultCard(result: _lastResult!),
        ],
      ],
    );
  }
}

class _CheckInResultCard extends StatelessWidget {
  final CheckInResult result;
  const _CheckInResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: result.success
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  result.success ? Icons.check_circle : Icons.error,
                  color: result.success
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  result.success ? 'Checked In!' : 'Check In Failed',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: result.success
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context).colorScheme.onErrorContainer,
                      ),
                ),
              ],
            ),
            if (result.message != null) ...[
              const SizedBox(height: 8),
              Text(
                result.message!,
                style: TextStyle(
                  color: result.success
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ],
            if (result.success && result.queuePosition != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.go(RoutePaths.home),
                child: const Text('Go to Home'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
