/// Typed errors surfaced to the UI. `userMessage` is the zh-TW string shown in
/// the global top banner (see `AppErrors`).
sealed class Failure {
  final String userMessage;
  const Failure(this.userMessage);
}

class NetworkFailure extends Failure {
  const NetworkFailure() : super('網路連線異常，請稍後再試');
}

class PermissionFailure extends Failure {
  const PermissionFailure() : super('沒有權限執行此操作');
}

class NotFoundFailure extends Failure {
  const NotFoundFailure() : super('找不到資料');
}

class AuthFailure extends Failure {
  const AuthFailure([String? message]) : super(message ?? '登入失敗，請檢查帳號密碼');
}

class AiFailure extends Failure {
  const AiFailure([String? message]) : super('AI 服務暫時無法使用');
}

class RateLimitFailure extends Failure {
  const RateLimitFailure() : super('AI 使用次數已達上限，請稍後再試');
}

class UnknownFailure extends Failure {
  final Object cause;
  const UnknownFailure(this.cause) : super('發生未知錯誤');
}
