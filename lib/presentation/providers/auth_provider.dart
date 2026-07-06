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
  final String? accountId;
  final String? accountToken;
  final String? activeVenueId;
  final String? activeSingerId;
  final String? activeSingerToken;
  const Authenticated({
    this.accountId,
    this.accountToken,
    this.activeVenueId,
    this.activeSingerId,
    this.activeSingerToken,
  });
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
      final accountToken = storage.getAccountToken();
      final accountId = storage.getAccountId();
      final activeVenueId = storage.getActiveVenueId();
      String? activeSingerId;
      String? activeSingerToken;

      if (accountToken == null || accountToken.isEmpty) {
        state = const Unauthenticated();
        return;
      }

      final repo = ref.read(accountAuthRepositoryProvider);
      final validatedAccountId = await repo.validateToken(accountToken);
      if (validatedAccountId == null) {
        await storage.clearAccountToken();
        await storage.clearAccountId();
        state = const Unauthenticated();
        return;
      }

      if (activeVenueId != null) {
        activeSingerToken = storage.getToken(activeVenueId);
        activeSingerId = storage.getSingerId(activeVenueId);
        if (activeSingerToken == null || activeSingerToken.isEmpty) {
          // Account is valid but not joined this venue — route to venue selector
          state = Authenticated(
            accountId: accountId,
            accountToken: accountToken,
          );
          return;
        }
      }

      state = Authenticated(
        accountId: accountId,
        accountToken: accountToken,
        activeVenueId: activeVenueId,
        activeSingerId: activeSingerId,
        activeSingerToken: activeSingerToken,
      );
    } catch (e) {
      state = const Unauthenticated();
    }
  }

  /// Real login with email/password.
  Future<bool> login(String email, String password) async {
    final repo = ref.read(accountAuthRepositoryProvider);
    final result = await repo.login(email, password);

    if (result == null) {
      return false;
    }

    final storage = await VenueStorage.create();
    await storage.setAccountToken(result.accessToken);
    await storage.setAccountRefreshToken(result.refreshToken);
    await storage.setAccountId(result.accountId);

    // If a venue is already active, join it and get a singer token
    final activeVenueId = storage.getActiveVenueId();
    String? singerId;
    String? singerToken;
    if (activeVenueId != null) {
      final venueResult = await repo.joinVenue(
        venueId: activeVenueId,
        accountToken: result.accessToken,
      );
      singerId = venueResult.singerId;
      singerToken = venueResult.accessToken;
      await storage.setToken(activeVenueId, singerToken);
      await storage.setRefreshToken(activeVenueId, venueResult.refreshToken);
      await storage.setSingerId(activeVenueId, singerId);
    }

    state = Authenticated(
      accountId: result.accountId,
      accountToken: result.accessToken,
      activeVenueId: activeVenueId,
      activeSingerId: singerId,
      activeSingerToken: singerToken,
    );
    return true;
  }

  /// Switch active venue and obtain/refresh the singer token.
  Future<bool> switchVenue(String venueId) async {
    final storage = await VenueStorage.create();
    final accountToken = storage.getAccountToken();
    if (accountToken == null || accountToken.isEmpty) {
      return false;
    }

    await storage.setActiveVenue(venueId);
    final repo = ref.read(accountAuthRepositoryProvider);

    // Reuse existing singer token if present and valid
    var singerToken = storage.getToken(venueId);
    var singerId = storage.getSingerId(venueId);
    final valid = singerToken != null &&
        await ref.read(authRepositoryProvider).validateToken(singerToken) != null;
    if (!valid) {
      final venueResult = await repo.joinVenue(
        venueId: venueId,
        accountToken: accountToken,
      );
      singerToken = venueResult.accessToken;
      singerId = venueResult.singerId;
      await storage.setToken(venueId, singerToken);
      await storage.setRefreshToken(venueId, venueResult.refreshToken);
      await storage.setSingerId(venueId, singerId);
    }

    state = Authenticated(
      accountId: storage.getAccountId(),
      accountToken: accountToken,
      activeVenueId: venueId,
      activeSingerId: singerId,
      activeSingerToken: singerToken,
    );
    return true;
  }

  /// Log out — clear all stored tokens.
  Future<void> logout() async {
    final storage = await VenueStorage.create();
    await storage.clearAll();
    state = const Unauthenticated();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

/// Convenience provider to read the current user ID when authenticated.
final currentUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authProvider);
  return switch (authState) {
    Authenticated(:final activeSingerId) => activeSingerId,
    _ => null,
  };
});

/// Provider that exposes the current venue-scoped auth token for API calls.
final authTokenProvider = Provider<String?>((ref) {
  final authState = ref.watch(authProvider);
  return switch (authState) {
    Authenticated(:final activeSingerToken) => activeSingerToken,
    _ => null,
  };
});

/// Provider that exposes the active venue ID.
final activeVenueIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authProvider);
  return switch (authState) {
    Authenticated(:final activeVenueId) => activeVenueId,
    _ => null,
  };
});
