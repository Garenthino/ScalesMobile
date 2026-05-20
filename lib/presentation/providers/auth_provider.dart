import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Auth state for the app.
sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class Authenticated extends AuthState {
  final String userId;
  const Authenticated(this.userId);
}

class Unauthenticated extends AuthState {
  const Unauthenticated();
}

/// Simple auth provider—replace with real token logic later.
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // NOTE: In tests, avoid uncontrolled async shifts.
    // Sprint 1 will hydrate from secure storage here.
    return const Unauthenticated();
  }

  void login(String userId) {
    state = Authenticated(userId);
  }

  void logout() {
    state = const Unauthenticated();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
