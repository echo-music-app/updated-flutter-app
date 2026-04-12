import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/routing/routes.dart';
import 'package:mobile/ui/core/themes/app_spacing.dart';
import 'package:mobile/ui/login/login_view_model.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({
    super.key,
    required this.viewModel,
    required this.initialEmail,
  });

  final LoginViewModel viewModel;
  final String initialEmail;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
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
  late final TextEditingController _emailController;
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    await widget.viewModel.verifyEmail(
      _emailController.text.trim(),
      _codeController.text.trim(),
    );
  }

  Future<void> _resend() async {
    if (_emailController.text.trim().isEmpty) return;
    await widget.viewModel.resendVerificationCode(_emailController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
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
                    if (widget.viewModel.isAuthenticated) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) context.go(Routes.home);
                      });
                    }

                    final pending = widget.viewModel.pendingVerification;

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
                                Icons.mark_email_unread_outlined,
                                color: Colors.white,
                                size: 34,
                              ),
                            ),
                          ),
                          SizedBox(height: AppSpacing.md),
                          const Text(
                            'Verify Email',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: AppSpacing.xs),
                          const Text(
                            'Enter the 6-digit code sent to your inbox',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _textMuted, fontSize: 18),
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
                                style: const TextStyle(color: Color(0xFFFFCDD2)),
                              ),
                            ),
                            SizedBox(height: AppSpacing.md),
                          ],
                          _label('Email'),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Colors.white),
                            decoration: _fieldDecoration(
                              hintText: 'you@example.com',
                            ),
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (email.isEmpty) return 'Email is required';
                              if (!RegExp(
                                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                              ).hasMatch(email)) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: AppSpacing.md),
                          _label('Verification Code'),
                          TextFormField(
                            controller: _codeController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: _fieldDecoration(hintText: '123456'),
                            validator: (value) {
                              final code = value?.trim() ?? '';
                              if (!RegExp(r'^\d{6}$').hasMatch(code)) {
                                return 'Code must be 6 digits';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: AppSpacing.lg),
                          SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              onPressed: widget.viewModel.isLoading
                                  ? null
                                  : _verify,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF111827),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
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
                                  : const Text('Verify Email'),
                            ),
                          ),
                          SizedBox(height: AppSpacing.xs),
                          TextButton(
                            onPressed: widget.viewModel.isLoading ? null : _resend,
                            child: const Text('Resend code'),
                          ),
                          TextButton(
                            onPressed: widget.viewModel.isLoading
                                ? null
                                : () => context.go(Routes.login),
                            child: const Text('Back to login'),
                          ),
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
          fontSize: 16,
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

