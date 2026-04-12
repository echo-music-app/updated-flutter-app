import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/routing/routes.dart';
import 'package:mobile/ui/login/login_view_model.dart';
import 'package:mobile/ui/login/password_policy.dart';
import 'package:mobile/ui/login/password_policy_section.dart';
import 'package:mobile/generated/l10n/app_localizations.dart';
import 'package:mobile/ui/core/themes/app_spacing.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.viewModel});

  final LoginViewModel viewModel;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _bgTop = Color(0xFF0B1222);
  static const _bgBottom = Color(0xFF050912);
  static const _cardBg = Color(0xFF05070B);
  static const _cardBorder = Color(0xFF1E2A44);
  static const _fieldBg = Color(0xFF0D1118);
  static const _fieldBorder = Color(0xFF222A36);
  static const _textMuted = Color(0xFF9BA7BA);
  static const _purpleStart = Color(0xFF7C3AED);
  static const _purpleEnd = Color(0xFF3B82F6);

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _verificationCodeController = TextEditingController();
  String? _lastPendingEmail;
  bool _isLogin = true;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _verificationCodeController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isLogin) {
      await widget.viewModel.loginWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } else {
      await widget.viewModel.register(
        _emailController.text.trim(),
        _usernameController.text.trim(),
        _passwordController.text,
      );
    }
  }

  Future<void> _verifyEmail() async {
    await widget.viewModel.verifyEmail(
      _emailController.text.trim(),
      _verificationCodeController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_bgTop, _bgBottom],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                padding: EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _cardBorder),
                ),
                child: ListenableBuilder(
                  listenable: widget.viewModel,
                  builder: (context, _) {
                    final pending = widget.viewModel.pendingVerification;
                    if (pending == null) {
                      _lastPendingEmail = null;
                    } else if (_lastPendingEmail != pending.email) {
                      _lastPendingEmail = pending.email;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        context.go(
                          '${Routes.verifyEmail}?email=${Uri.encodeComponent(pending.email)}',
                        );
                      });
                    }

                    return Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Align(
                            child: Container(
                              height: 76,
                              width: 76,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [_purpleStart, _purpleEnd],
                                ),
                              ),
                              child: const Icon(
                                Icons.music_note_rounded,
                                color: Colors.white,
                                size: 34,
                              ),
                            ),
                          ),
                          SizedBox(height: AppSpacing.md),
                          const Text(
                            'Echo',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: AppSpacing.xs),
                          Text(
                            _isLogin
                                ? 'Sign in to your account'
                                : 'Create your account',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _textMuted,
                              fontSize: 22,
                            ),
                          ),
                          SizedBox(height: AppSpacing.lg),
                          if (pending != null) ...[
                            Container(
                              padding: EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: const Color(0xFF131C2A),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                pending.debugCode == null
                                    ? pending.message
                                    : '${pending.message} (debug code: ${pending.debugCode})',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            SizedBox(height: AppSpacing.md),
                            SizedBox(
                              height: 48,
                              child: OutlinedButton(
                                onPressed: widget.viewModel.isLoading
                                    ? null
                                    : () => context.go(
                                        '${Routes.verifyEmail}?email=${Uri.encodeComponent(pending.email)}',
                                      ),
                                child: const Text('Open verification screen'),
                              ),
                            ),
                            SizedBox(height: AppSpacing.md),
                          ],
                          if (widget.viewModel.error != null) ...[
                            Container(
                              padding: EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: const Color(0xFF34161A),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF5B222B),
                                ),
                              ),
                              child: Text(
                                widget.viewModel.error!,
                                style: const TextStyle(
                                  color: Color(0xFFFFCDD2),
                                ),
                              ),
                            ),
                            SizedBox(height: AppSpacing.md),
                          ],
                          _label(l10n.email),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            enabled: !widget.viewModel.isLoading,
                            style: const TextStyle(color: Colors.white),
                            decoration: _fieldDecoration(
                              hintText: 'you@example.com',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Email is required';
                              }
                              if (!RegExp(
                                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                              ).hasMatch(value.trim())) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: AppSpacing.md),
                          if (!_isLogin) ...[
                            _label(l10n.username),
                            TextFormField(
                              controller: _usernameController,
                              enabled: !widget.viewModel.isLoading,
                              style: const TextStyle(color: Colors.white),
                              decoration: _fieldDecoration(
                                hintText: 'your_username',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Username is required';
                                }
                                if (value.trim().length < 3 ||
                                    value.trim().length > 50) {
                                  return 'Username must be 3-50 characters';
                                }
                                if (!RegExp(
                                  r'^[a-zA-Z0-9_.\-]+$',
                                ).hasMatch(value.trim())) {
                                  return 'Username can only contain letters, numbers, _, . and -';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: AppSpacing.md),
                          ],
                          _label(l10n.password),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            onChanged: (_) => setState(() {}),
                            enabled: !widget.viewModel.isLoading,
                            style: const TextStyle(color: Colors.white),
                            decoration: _fieldDecoration(hintText: '********'),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Password is required';
                              }
                              if (!_isLogin) {
                                final check = evaluatePassword(value);
                                if (!check.isValid) {
                                  return 'Password must include upper, lower, number and special character';
                                }
                              }
                              return null;
                            },
                          ),
                          if (!_isLogin) ...[
                            SizedBox(height: AppSpacing.sm),
                            PasswordPolicySection(
                              password: _passwordController.text,
                              textColor: _textMuted,
                            ),
                          ],
                          if (pending != null) ...[
                            SizedBox(height: AppSpacing.md),
                            _label('Verification Code'),
                            TextFormField(
                              controller: _verificationCodeController,
                              keyboardType: TextInputType.number,
                              enabled: !widget.viewModel.isLoading,
                              style: const TextStyle(color: Colors.white),
                              decoration: _fieldDecoration(hintText: '123456'),
                            ),
                          ],
                          SizedBox(height: AppSpacing.lg),
                          SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              onPressed: widget.viewModel.isLoading
                                  ? null
                                  : (pending != null ? _verifyEmail : _submit),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF111827),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: widget.viewModel.isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      pending != null
                                          ? 'Verify Email'
                                          : (_isLogin
                                                ? 'Sign In'
                                                : l10n.register),
                                    ),
                            ),
                          ),
                          if (pending != null) ...[
                            SizedBox(height: AppSpacing.xs),
                            TextButton(
                              onPressed: widget.viewModel.isLoading
                                  ? null
                                  : () =>
                                        widget.viewModel.resendVerificationCode(
                                          _emailController.text.trim(),
                                        ),
                              child: const Text('Resend code'),
                            ),
                          ],
                          SizedBox(height: AppSpacing.md),
                          if (pending == null)
                            TextButton(
                              onPressed: widget.viewModel.isLoading
                                  ? null
                                  : _toggleMode,
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    color: _textMuted,
                                    fontSize: 16,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: _isLogin
                                          ? 'Don\'t have an account? '
                                          : 'Already have an account? ',
                                    ),
                                    TextSpan(
                                      text: _isLogin ? 'Sign up' : 'Sign in',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          SizedBox(height: AppSpacing.sm),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: const Color(0xFF131C2A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF22314A),
                              ),
                            ),
                            child: Text(
                              widget.viewModel.supportsTfa
                                  ? 'Two-factor authentication (TFA) is enabled for this server.'
                                  : 'Two-factor authentication (TFA) is not enabled on this server yet.',
                              style: const TextStyle(color: _textMuted),
                            ),
                          ),
                          if (_isLogin && pending == null) ...[
                            SizedBox(height: AppSpacing.sm),
                            Container(
                              padding: EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E2128),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Demo accounts:',
                                    style: TextStyle(
                                      color: Color(0xFFCFD6E4),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'music@echo.com\nbeats@echo.com',
                                    style: TextStyle(color: Color(0xFFCFD6E4)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF7A8496)),
      filled: true,
      fillColor: _fieldBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _purpleStart, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE57373)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE57373), width: 1.4),
      ),
    );
  }
}
