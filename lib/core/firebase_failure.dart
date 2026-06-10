import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'failures.dart';

/// The single mapping from raw thrown errors to typed [Failure]s, used by every
/// repository and by `AppErrors`.
Failure mapFirebase(Object e) {
  if (e is Failure) return e;
  return switch (e) {
    FirebaseFunctionsException(:final code) when code == 'resource-exhausted' =>
      const RateLimitFailure(),
    FirebaseFunctionsException() => AiFailure(e.toString()),
    FirebaseAuthException(:final code) => AuthFailure(_authMessage(code)),
    FirebaseException(:final code) when code == 'permission-denied' =>
      const PermissionFailure(),
    FirebaseException(:final code) when code == 'not-found' =>
      const NotFoundFailure(),
    FirebaseException(:final code)
        when code == 'unavailable' || code == 'deadline-exceeded' =>
      const NetworkFailure(),
    _ => UnknownFailure(e),
  };
}

String? _authMessage(String code) => switch (code) {
  'invalid-email' => 'Email 格式不正確',
  'user-disabled' => '此帳號已被停用',
  'user-not-found' || 'wrong-password' || 'invalid-credential' => '帳號或密碼錯誤',
  'email-already-in-use' => '此 Email 已被註冊',
  'weak-password' => '密碼強度不足（至少 6 碼）',
  'requires-recent-login' => '請重新登入後再試一次',
  'network-request-failed' => '網路連線異常，請稍後再試',
  _ => null,
};
