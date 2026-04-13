import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/routing/routes.dart';
import 'package:mobile/ui/core/themes/app_spacing.dart';
import 'package:mobile/ui/core/themes/theme_mode_controller.dart';
import 'package:mobile/ui/core/widgets/app_sidebar_drawer.dart';
import 'package:mobile/ui/login/login_view_model.dart';
import 'package:provider/provider.dart';

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

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with SingleTickerProviderStateMixin {
  static const _bgTopDark = Color(0xFF0B1222);
  static const _bgBottomDark = Color(0xFF050912);
  static const _cardBgDark = Color(0xFF05070B);
  static const _cardBorderDark = Color(0xFF1E2A44);
  static const _fieldBgDark = Color(0xFF0D1118);
  static const _fieldBorderDark = Color(0xFF222A36);
  static const _textMutedDark = Color(0xFF9BA7BA);
  static const _purpleStart = Color(0xFF7C3AED);
  static const _purpleEnd = Color(0xFF3B82F6);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final _codeController = TextEditingController();

  late final AnimationController _entryController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideIn;

  bool _isLightMode = false;

  Color get _bgTop => _isLightMode ? const Color(0xFFF7F9FC) : _bgTopDark;
  Color get _bgBottom => _isLightMode ? const Color(0xFFEFF3FA) : _bgBottomDark;
  Color get _cardBg => _isLightMode ? Colors.white : _cardBgDark;
  Color get _cardBorder => _isLightMode ? const Color(0xFFDCE4F0) : _cardBorderDark;
  Color get _fieldBg => _isLightMode ? const Color(0xFFF5F7FB) : _fieldBgDark;
  Color get _fieldBorder => _isLightMode ? const Color(0xFFD8E0EC) : _fieldBorderDark;
  Color get _textPrimary => _isLightMode ? const Color(0xFF111827) : Colors.white;
  Color get _textMuted => _isLightMode ? const Color(0xFF5B6678) : _textMutedDark;
  Color get _themeChipBg => _isLightMode ? const Color(0xFFF3F6FC) : const Color(0xAA0D1118);
  Color get _themeChipBorder => _isLightMode ? const Color(0xFFD7DFEB) : const Color(0xFF2D3A52);

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 820),
    );
    _fadeIn = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    );
    _slideIn = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
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
    _isLightMode = Theme.of(context).brightness == Brightness.light;
    final themeController = context.watch<ThemeModeController>();
    final isDarkMode = themeController.isDarkMode;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_bgTop, _bgBottom],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 14,
              left: 14,
              child: SafeArea(
                child: Builder(
                  builder: (context) => DecoratedBox(
                    decoration: BoxDecoration(
                      color: _themeChipBg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _themeChipBorder),
                    ),
                    child: IconButton(
                      onPressed: () => showAppSidebar(context),
                      icon: Icon(Icons.menu_rounded, color: _textPrimary),
                      tooltip: 'Open menu',
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: -90,
              left: -30,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.84, end: 1),
                duration: const Duration(milliseconds: 1300),
                curve: Curves.easeOutCubic,
                builder: (_, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _purpleEnd.withValues(alpha: _isLightMode ? 0.10 : 0.14),
                  ),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: FadeTransition(
                    opacity: _fadeIn,
                    child: SlideTransition(
                      position: _slideIn,
                      child: Container(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: _cardBg,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _cardBorder),
                          boxShadow: [
                            BoxShadow(
                              color: _isLightMode
                                  ? const Color(0x220C1628)
                                  : const Color(0x44000000),
                              blurRadius: _isLightMode ? 18 : 30,
                              offset: const Offset(0, 16),
                            ),
                          ],
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
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 260),
                                child: Column(
                                  key: ValueKey(
                                    '${widget.viewModel.isLoading}-${widget.viewModel.error}-${pending?.debugCode}',
                                  ),
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: _themeChipBg,
                                          borderRadius: BorderRadius.circular(999),
                                          border: Border.all(color: _themeChipBorder),
                                        ),
                                        child: IconButton(
                                          icon: Icon(
                                            isDarkMode
                                                ? Icons.light_mode_rounded
                                                : Icons.dark_mode_rounded,
                                            color: _textPrimary,
                                          ),
                                          tooltip: isDarkMode
                                              ? 'Switch to light mode'
                                              : 'Switch to dark mode',
                                          onPressed: () => themeController.toggle(),
                                        ),
                                      ),
                                    ),
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
                                    Text(
                                      'Verify Email',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 42,
                                        fontWeight: FontWeight.w700,
                                        color: _textPrimary,
                                      ),
                                    ),
                                    SizedBox(height: AppSpacing.xs),
                                    Text(
                                      'Enter the 6-digit code sent to your inbox',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: _textMuted, fontSize: 18),
                                    ),
                                    SizedBox(height: AppSpacing.lg),
                                    if (pending != null) ...[
                                      Container(
                                        padding: EdgeInsets.all(AppSpacing.md),
                                        decoration: BoxDecoration(
                                          color: _isLightMode
                                              ? const Color(0xFFF3F7FF)
                                              : const Color(0xFF101A2A),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: _isLightMode
                                                ? const Color(0xFFD5E1F2)
                                                : const Color(0xFF22314A),
                                          ),
                                        ),
                                        child: Text(
                                          pending.debugCode == null
                                              ? pending.message
                                              : '${pending.message} (debug code: ${pending.debugCode})',
                                          style: TextStyle(color: _textPrimary),
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
                                    _label('Email'),
                                    TextFormField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      style: TextStyle(color: _textPrimary),
                                      decoration: _fieldDecoration(
                                        hintText: 'you@example.com',
                                        prefixIcon: Icon(
                                          Icons.alternate_email_rounded,
                                          color: _textMuted,
                                        ),
                                      ),
                                      validator: (value) {
                                        final email = value?.trim() ?? '';
                                        if (email.isEmpty) {
                                          return 'Email is required';
                                        }
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
                                      maxLength: 6,
                                      style: TextStyle(color: _textPrimary),
                                      decoration: _fieldDecoration(
                                        hintText: '123456',
                                        prefixIcon: Icon(
                                          Icons.pin_outlined,
                                          color: _textMuted,
                                        ),
                                      ),
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
                                          textStyle: const TextStyle(
                                            fontSize: 18,
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
                                            : const Text('Verify Email'),
                                      ),
                                    ),
                                    SizedBox(height: AppSpacing.xs),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextButton(
                                            onPressed: widget.viewModel.isLoading
                                                ? null
                                                : _resend,
                                            child: const Text('Resend code'),
                                          ),
                                        ),
                                        Expanded(
                                          child: TextButton(
                                            onPressed: widget.viewModel.isLoading
                                                ? null
                                                : () => context.go(Routes.login),
                                            child: const Text('Back to login'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: _textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hintText,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: _isLightMode ? const Color(0xFF7C889C) : const Color(0xFF7A8496),
      ),
      filled: true,
      fillColor: _fieldBg,
      prefixIcon: prefixIcon,
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _fieldBorder),
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
