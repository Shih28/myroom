import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../core/app_errors.dart';
import '../../../core/failures.dart';
import '../../../core/firebase_failure.dart';
import '../../../core/result.dart';
import '../domain/app_user.dart';
import '../domain/auth_repo.dart';

class FirebaseAuthRepo implements AuthRepo {
  FirebaseAuthRepo(this._auth);

  final FirebaseAuth _auth;

  @override
  Stream<AppUser?> get authState =>
      _auth.authStateChanges().map((u) => u == null ? null : _toAppUser(u));

  @override
  String? get currentUserId => _auth.currentUser?.uid;

  AppUser _toAppUser(User u) =>
      AppUser(uid: u.uid, email: u.email ?? '', displayName: u.displayName);

  @override
  Future<Result<void>> signIn(String email, String password) => _guard(
    () => _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    ),
  );

  @override
  Future<Result<void>> signUp(String email, String password) => _guard(
    () => _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    ),
  );

  @override
  Future<Result<void>> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  @override
  Future<Result<void>> signInWithGoogle() => _guard(() async {
    if (kIsWeb) {
      await _auth.signInWithPopup(GoogleAuthProvider());
      return;
    }
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw const AuthFailure('已取消 Google 登入');
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    await _auth.signInWithCredential(credential);
  });

  @override
  Future<Result<void>> signInWithApple() => _guard(() async {
    final provider = OAuthProvider('apple.com')
      ..addScope('email')
      ..addScope('name');
    if (kIsWeb) {
      await _auth.signInWithPopup(provider);
      return;
    }
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    final oauthCredential = provider.credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );
    await _auth.signInWithCredential(oauthCredential);
  });

  @override
  Future<Result<void>> signOut() => _guard(() async {
    if (!kIsWeb) {
      try {
        await GoogleSignIn().signOut();
      } catch (_) {
        /* not signed in via Google — ignore */
      }
    }
    await _auth.signOut();
  });

  @override
  Future<Result<void>> deleteAccount({String? password}) => _guard(() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthFailure('尚未登入');
    await _reauthenticate(user, password);
    await user.delete();
  });

  /// Provider-specific re-authentication required by `user.delete()`.
  Future<void> _reauthenticate(User user, String? password) async {
    final providerIds = user.providerData.map((p) => p.providerId).toSet();

    if (providerIds.contains('google.com')) {
      if (kIsWeb) {
        await user.reauthenticateWithPopup(GoogleAuthProvider());
        return;
      }
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) throw const AuthFailure('已取消重新驗證');
      final googleAuth = await googleUser.authentication;
      await user.reauthenticateWithCredential(
        GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        ),
      );
      return;
    }

    if (providerIds.contains('apple.com')) {
      final provider = OAuthProvider('apple.com');
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
        await user.reauthenticateWithPopup(provider);
        return;
      }
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email],
      );
      await user.reauthenticateWithCredential(
        provider.credential(
          idToken: appleCredential.identityToken,
          accessToken: appleCredential.authorizationCode,
        ),
      );
      return;
    }

    // Email / password.
    if (password == null || password.isEmpty) {
      throw const AuthFailure('請輸入密碼以確認刪除帳號');
    }
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: user.email ?? '', password: password),
    );
  }

  Future<Result<void>> _guard(Future<void> Function() action) async {
    try {
      await action();
      return const Ok(null);
    } catch (e) {
      final f = mapFirebase(e);
      AppErrors.present(f);
      return Err(f);
    }
  }
}
