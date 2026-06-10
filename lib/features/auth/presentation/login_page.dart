import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/auth/domain/auth_repo.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _isSignUp = false;
  bool _busy = false;

  bool get _appleAvailable =>
      kIsWeb || defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  AuthRepo get _auth => context.read<AuthRepo>();

  Future<void> _run(Future<Result<void>> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    await action();
    if (mounted) setState(() => _busy = false);
    // On success the GoRouter redirect (driven by authState) navigates away.
  }

  void _submitEmail() {
    final email = _emailCtrl.text.trim();
    final pw = _pwCtrl.text;
    if (email.isEmpty || pw.isEmpty) return;
    _run(() => _isSignUp ? _auth.signUp(email, pw) : _auth.signIn(email, pw));
  }

  void _resetPassword() {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請先輸入 Email')));
      return;
    }
    _run(() => _auth.sendPasswordReset(email)).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('重設密碼信件已寄出')));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.dark,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        LucideIcons.house,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'myroom',
                      style: AppText.display(
                        size: 34,
                        italic: true,
                        weight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      _isSignUp ? '建立你的個人空間' : '歡迎回來',
                      style: AppText.caption(size: 12),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _field(
                    controller: _emailCtrl,
                    hint: 'Email',
                    icon: LucideIcons.mail,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    controller: _pwCtrl,
                    hint: '密碼',
                    icon: LucideIcons.lock,
                    obscure: true,
                    onSubmitted: (_) => _submitEmail(),
                  ),
                  const SizedBox(height: 8),
                  if (!_isSignUp)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _busy ? null : _resetPassword,
                        child: Text(
                          '忘記密碼？',
                          style: AppText.caption(
                            size: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  _primaryButton(
                    label: _isSignUp ? '註冊' : '登入',
                    onTap: _submitEmail,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(child: Divider(color: AppColors.border)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('或', style: AppText.caption(size: 11)),
                      ),
                      const Expanded(child: Divider(color: AppColors.border)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _oauthButton(
                    label: '使用 Google 登入',
                    icon: LucideIcons.globe,
                    onTap: () => _run(_auth.signInWithGoogle),
                  ),
                  if (_appleAvailable) ...[
                    const SizedBox(height: 10),
                    _oauthButton(
                      label: '使用 Apple 登入',
                      icon: LucideIcons.apple,
                      onTap: () => _run(_auth.signInWithApple),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Center(
                    child: GestureDetector(
                      onTap: _busy
                          ? null
                          : () => setState(() => _isSignUp = !_isSignUp),
                      child: Text.rich(
                        TextSpan(
                          text: _isSignUp ? '已經有帳號了？ ' : '還沒有帳號？ ',
                          style: AppText.caption(size: 12),
                          children: [
                            TextSpan(
                              text: _isSignUp ? '登入' : '註冊',
                              style: AppText.caption(
                                size: 12,
                                weight: FontWeight.w700,
                                color: AppColors.dark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 20),
                    const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.dark,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
    ValueChanged<String>? onSubmitted,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboardType,
              onSubmitted: onSubmitted,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppText.body(size: 14, color: AppColors.muted),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
              style: AppText.body(size: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: _busy ? null : onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.dark,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            label,
            style: AppText.body(
              size: 15,
              weight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _oauthButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _busy ? null : onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppColors.dark),
            const SizedBox(width: 10),
            Text(label, style: AppText.body(size: 14, weight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
