import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/venue_storage.dart';
import '../../data/repositories/auth_repository.dart';

/// Auth state for the app.
sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class Authenticated extends AuthState {
  final String userId;
  final String venueId;
  final String token;
  const Authenticated(this.userId, this.venueId, this.token);
}

class Unauthenticated extends AuthState {
  const Unauthenticated();
}

/// Auth provider that loads saved tokens on startup and handles real login/logout.
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Async init: we return initial state, then _tryAutoLogin updates it.
    _tryAutoLogin();
    return const AuthInitial();
  }

  /// Attempt to restore a saved session.
  Future<void> _tryAutoLogin() async {
    try {
      final storage = await VenueStorage.create();
      final venueId = storage.getActiveVenueId();
      if (venueId == null) {
        state = const Unauthenticated();
        return;
      }

      final token = storage.getToken(venueId);
      if (token == null || token.isEmpty) {
        state = const Unauthenticated();
        return;
      }

      final repo = ref.read(authRepositoryProvider);
      final singerId = await repo.validateToken(token);
      if (singerId != null) {
        state = Authenticated(singerId, venueId, token);
      } else {
        // Token expired or invalid — clear it
        await storage.clearToken(venueId);
        state = const Unauthenticated();
      }
    } catch (e) {
      state = const Unauthenticated();
    }
  }

  /// Real login with email/password.
  Future<bool> login(String email, String password) async {
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.login(email, password);

    if (result == null) {
      return false;
    }

    final storage = await VenueStorage.create();
    // Save token against the venue the singer belongs to
    await storage.setToken(result.venueId, result.accessToken);
    // Also save the refresh token for later
    await storage.setRefreshToken(result.venueId, result.refreshToken);
    state = Authenticated(result.singerId, result.venueId, result.accessToken);
    return true;
  }

  /// Log out — clear stored token for the current venue.
  Future<void> logout() async {
    final current = state;
    if (current is Authenticated) {
      final storage = await VenueStorage.create();
      await storage.clearToken(current.venueId);
      await storage.clearRefreshToken(current.venueId);
    }
    state = const Unauthenticated();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

/// Convenience provider to read the current user ID when authenticated.
final currentUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authProvider);
  return switch (authState) {
    Authenticated(:final userId) => userId,
    _ => null,
  };
});

/// Provider that exposes the current auth token for API calls.
final authTokenProvider = Provider<String?>((ref) {
  final authState = ref.watch(authProvider);
  return switch (authState) {
    Authenticated(:final token) => token,
    _ => null,
  };
});
