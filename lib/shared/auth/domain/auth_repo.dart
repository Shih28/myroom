import '../../../core/result.dart';
import 'app_user.dart';

/// Owns the session + `userId`. Every other repo is scoped to
/// `/users/{userId}/...`. Provided in the root provider tier.
abstract class AuthRepo {
  /// Drives the go_router redirect. Emits `null` when signed out.
  Stream<AppUser?> get authState;

  /// Synchronous guard check — `null` when signed out.
  String? get currentUserId;

  Future<Result<void>> signIn(String email, String password);
  Future<Result<void>> signUp(String email, String password);
  Future<Result<void>> signInWithGoogle();
  Future<Result<void>> signInWithApple();
  Future<Result<void>> sendPasswordReset(String email);
  Future<Result<void>> signOut();

  /// Re-authenticates (provider-specific) before deleting the Auth user. The
  /// `deleteUserData` Auth `onDelete` trigger then wipes Firestore + Storage.
  /// [password] is required only for email/password accounts.
  Future<Result<void>> deleteAccount({String? password});
}
