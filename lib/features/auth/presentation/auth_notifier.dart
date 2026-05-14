import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
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

  String? _sessionError;
  /// Açılışta veya [ensureSupabaseAnonymousSession] sırasında oturum açılamadıysa mesaj.
  String? get sessionError => _sessionError;

  /// Kalıcı oturumu okur (uygulama açılışı).
  Future<void> hydrate() async {
    _user = await _repository.currentUser();
    notifyListeners();
  }

  /// Oturum yoksa anonim oturum açmayı dener (Supabase + panelde Anonymous açık olmalı).
  Future<void> ensureSupabaseAnonymousSession() async {
    if (_user != null) {
      _sessionError = null;
      return;
    }
    try {
      await signInAnonymously();
      _sessionError = null;
    } on AppException catch (e) {
      _sessionError = e.message;
      notifyListeners();
    } on Object catch (e) {
      _sessionError = e.toString();
      notifyListeners();
    }
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
