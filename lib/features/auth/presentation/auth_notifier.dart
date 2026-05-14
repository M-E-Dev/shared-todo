import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';

/// Oturum durumu; [Listenable] ile UI bağlanır (ek paket yok).
final class AuthNotifier extends ChangeNotifier {
  AuthNotifier(this._repository) {
    _subscription = _repository.authStateChanges().listen((_) async {
      _user = await _repository.currentUser();
      notifyListeners();
    });
  }

  final AuthRepository _repository;
  StreamSubscription<void>? _subscription;

  AuthUser? _user;
  AuthUser? get user => _user;

  /// Kalıcı oturumu okur (uygulama açılışı).
  Future<void> hydrate() async {
    _user = await _repository.currentUser();
    notifyListeners();
  }

  Future<AuthUser> signInAnonymously() async {
    final u = await _repository.signInAnonymously();
    _user = u;
    notifyListeners();
    return u;
  }

  Future<void> setDisplayName(String displayName) async {
    await _repository.setDisplayName(displayName);
    _user = await _repository.currentUser();
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
