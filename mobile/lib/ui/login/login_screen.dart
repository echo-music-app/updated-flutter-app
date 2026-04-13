import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/generated/l10n/app_localizations.dart';
import 'package:mobile/routing/routes.dart';
import 'package:mobile/ui/core/themes/app_spacing.dart';
import 'package:mobile/ui/core/themes/theme_mode_controller.dart';
import 'package:mobile/ui/core/widgets/app_sidebar_drawer.dart';
import 'package:mobile/ui/login/login_view_model.dart';
import 'package:mobile/ui/login/password_policy.dart';
import 'package:mobile/ui/login/password_policy_section.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.viewModel});

  final LoginViewModel viewModel;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
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
  final _confirmPasswordController = TextEditingController();
  final _verificationCodeController = TextEditingController();
  final _mfaCodeController = TextEditingController();

  late final AnimationController _entryController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideIn;

  String? _lastPendingEmail;
  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLightMode = false;

  Color get _bgTopColor => _isLightMode ? const Color(0xFFF7F9FC) : _bgTop;
  Color get _bgBottomColor => _isLightMode ? const Color(0xFFEFF3FA) : _bgBottom;
  Color get _cardBgColor => _isLightMode ? Colors.white : _cardBg;
  Color get _cardBorderColor => _isLightMode ? const Color(0xFFDCE4F0) : _cardBorder;
  Color get _fieldBgColor => _isLightMode ? const Color(0xFFF5F7FB) : _fieldBg;
  Color get _fieldBorderColor => _isLightMode ? const Color(0xFFD8E0EC) : _fieldBorder;
  Color get _textPrimaryColor => _isLightMode ? const Color(0xFF111827) : Colors.white;
  Color get _textMutedColor => _isLightMode ? const Color(0xFF5B6678) : _textMuted;
  Color get _themeChipBg => _isLightMode ? const Color(0xFFF3F6FC) : const Color(0xAA0D1118);
  Color get _themeChipBorder => _isLightMode ? const Color(0xFFD7DFEB) : const Color(0xFF2D3A52);

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _fadeIn = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    );
    _slideIn = Tween<Offset>(
      begin: const Offset(0, 0.07),
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
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _verificationCodeController.dispose();
    _mfaCodeController.dispose();
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
        mfaCode: _mfaCodeController.text.trim().isEmpty
            ? null
            : _mfaCodeController.text.trim(),
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
    _isLightMode = Theme.of(context).brightness == Brightness.light;
    final themeController = context.watch<ThemeModeController>();
    final isDarkMode = themeController.isDarkMode;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_bgTopColor, _bgBottomColor],
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
                      icon: Icon(Icons.menu_rounded, color: _textPrimaryColor),
                      tooltip: 'Open menu',
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: -90,
              right: -35,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.84, end: 1),
                duration: const Duration(milliseconds: 1300),
                curve: Curves.easeOutCubic,
                builder: (_, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Container(
                  width: 230,
                  height: 230,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _purpleStart.withValues(alpha: _isLightMode ? 0.10 : 0.16),
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
                          color: _cardBgColor,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _cardBorderColor),
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
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 260),
                                child: Column(
                                  key: ValueKey(
                                    '$_isLogin-${pending != null}-${widget.viewModel.mfaRequired}',
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
                                            color: _textPrimaryColor,
                                          ),
                                          tooltip: isDarkMode
                                              ? 'Switch to light mode'
                                              : 'Switch to dark mode',
                                          onPressed: () => themeController.toggle(),
                                        ),
                                      ),
                                    ),
                                    _buildHeader(_isLogin),
                                    SizedBox(height: AppSpacing.lg),
                                    if (pending != null) ...[
                                      _buildPendingCard(pending.message, pending.debugCode),
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
                                      _buildErrorCard(widget.viewModel.error!),
                                      SizedBox(height: AppSpacing.md),
                                    ],
                                    _label(l10n.email),
                                    _emailField(),
                                    SizedBox(height: AppSpacing.md),
                                    AnimatedCrossFade(
                                      duration: const Duration(milliseconds: 220),
                                      crossFadeState: _isLogin
                                          ? CrossFadeState.showFirst
                                          : CrossFadeState.showSecond,
                                      firstChild: const SizedBox.shrink(),
                                      secondChild: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          _label(l10n.username),
                                          _usernameField(),
                                          SizedBox(height: AppSpacing.md),
                                        ],
                                      ),
                                    ),
                                    _label(l10n.password),
                                    _passwordField(),
                                    AnimatedCrossFade(
                                      duration: const Duration(milliseconds: 220),
                                      crossFadeState: _isLogin
                                          ? CrossFadeState.showFirst
                                          : CrossFadeState.showSecond,
                                      firstChild: const SizedBox.shrink(),
                                      secondChild: Column(
                                        children: [
                                          SizedBox(height: AppSpacing.sm),
                                          PasswordPolicySection(
                                            password: _passwordController.text,
                                            textColor: _textMuted,
                                          ),
                                        ],
                                      ),
                                    ),
                                    AnimatedCrossFade(
                                      duration: const Duration(milliseconds: 220),
                                      crossFadeState: _isLogin
                                          ? CrossFadeState.showFirst
                                          : CrossFadeState.showSecond,
                                      firstChild: const SizedBox.shrink(),
                                      secondChild: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          SizedBox(height: AppSpacing.md),
                                          _label('Confirm Password'),
                                          _confirmPasswordField(),
                                          SizedBox(height: AppSpacing.xs),
                                          _confirmPasswordFeedback(),
                                        ],
                                      ),
                                    ),
                                    if (_isLogin && pending == null && widget.viewModel.mfaRequired) ...[
                                      SizedBox(height: AppSpacing.md),
                                      _label('2FA Code'),
                                      _mfaField(),
                                    ],
                                    if (pending != null) ...[
                                      SizedBox(height: AppSpacing.md),
                                      _label('Verification Code'),
                                      TextFormField(
                                        controller: _verificationCodeController,
                                        keyboardType: TextInputType.number,
                                        enabled: !widget.viewModel.isLoading,
                                        style: TextStyle(color: _textPrimaryColor),
                                        decoration: _fieldDecoration(hintText: '123456'),
                                      ),
                                    ],
                                    SizedBox(height: AppSpacing.lg),
                                    _submitButton(l10n, pending != null),
                                    if (pending == null) ...[
                                      SizedBox(height: AppSpacing.sm),
                                      _googleButton(),
                                    ],
                                    if (pending != null) ...[
                                      SizedBox(height: AppSpacing.xs),
                                      TextButton(
                                        onPressed: widget.viewModel.isLoading
                                            ? null
                                            : () => widget.viewModel.resendVerificationCode(
                                                  _emailController.text.trim(),
                                                ),
                                        child: const Text('Resend code'),
                                      ),
                                    ],
                                    SizedBox(height: AppSpacing.md),
                                    if (pending == null) _switchModeButton(),
                                    SizedBox(height: AppSpacing.sm),
                                    _buildTfaStatus(),
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

  Widget _buildHeader(bool isLogin) {
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.92, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutBack,
          builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
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
            child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 34),
          ),
        ),
        SizedBox(height: AppSpacing.md),
        Text(
          'Echo',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w700,
            color: _textPrimaryColor,
          ),
        ),
        SizedBox(height: AppSpacing.xs),
        Text(
          isLogin ? 'Sign in to your account' : 'Create your account',
          textAlign: TextAlign.center,
          style: TextStyle(color: _textMutedColor, fontSize: 22),
        ),
      ],
    );
  }

  Widget _buildPendingCard(String message, String? debugCode) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _isLightMode ? const Color(0xFFF3F7FF) : const Color(0xFF131C2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isLightMode ? const Color(0xFFD5E1F2) : Colors.transparent,
        ),
      ),
      child: Text(
        debugCode == null ? message : '$message (debug code: $debugCode)',
        style: TextStyle(color: _textPrimaryColor),
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF34161A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF5B222B)),
      ),
      child: Text(message, style: const TextStyle(color: Color(0xFFFFCDD2))),
    );
  }

  Widget _emailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      enabled: !widget.viewModel.isLoading,
      style: TextStyle(color: _textPrimaryColor),
      decoration: _fieldDecoration(hintText: 'you@example.com'),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return 'Email is required';
        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _usernameField() {
    return TextFormField(
      controller: _usernameController,
      enabled: !widget.viewModel.isLoading,
      style: TextStyle(color: _textPrimaryColor),
      decoration: _fieldDecoration(hintText: 'your_username'),
      validator: (value) {
        if (_isLogin) return null;
        if (value == null || value.trim().isEmpty) return 'Username is required';
        if (value.trim().length < 3 || value.trim().length > 50) {
          return 'Username must be 3-50 characters';
        }
        if (!RegExp(r'^[a-zA-Z0-9_.\-]+$').hasMatch(value.trim())) {
          return 'Username can only contain letters, numbers, _, . and -';
        }
        return null;
      },
    );
  }

  Widget _passwordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      onChanged: (_) => setState(() {}),
      enabled: !widget.viewModel.isLoading,
      style: TextStyle(color: _textPrimaryColor),
      decoration: _fieldDecoration(
        hintText: '********',
        suffixIcon: IconButton(
          onPressed: widget.viewModel.isLoading
              ? null
              : () => setState(() => _obscurePassword = !_obscurePassword),
          icon: Icon(
            _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            color: _obscurePassword
                ? const Color(0xFF9BA7BA)
                : const Color(0xFF7C3AED),
          ),
          tooltip: _obscurePassword ? 'Show password' : 'Hide password',
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Password is required';
        if (!_isLogin) {
          final check = evaluatePassword(value);
          if (!check.isValid) {
            return 'Password must include upper, lower, number and special character';
          }
        }
        return null;
      },
    );
  }

  Widget _mfaField() {
    return TextFormField(
      controller: _mfaCodeController,
      keyboardType: TextInputType.number,
      enabled: !widget.viewModel.isLoading,
      style: TextStyle(color: _textPrimaryColor),
      decoration: _fieldDecoration(hintText: '123456'),
      validator: (value) {
        if (!widget.viewModel.mfaRequired) return null;
        final code = value?.trim() ?? '';
        if (!RegExp(r'^\d{6}$').hasMatch(code)) {
          return 'Enter a valid 6-digit 2FA code';
        }
        return null;
      },
    );
  }

  Widget _confirmPasswordField() {
    return TextFormField(
      controller: _confirmPasswordController,
      obscureText: _obscureConfirmPassword,
      onChanged: (_) => setState(() {}),
      enabled: !widget.viewModel.isLoading,
      style: TextStyle(color: _textPrimaryColor),
      decoration: _fieldDecoration(
        hintText: '********',
        suffixIcon: IconButton(
          onPressed: widget.viewModel.isLoading
              ? null
              : () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  ),
          icon: Icon(
            _obscureConfirmPassword
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            color: _obscureConfirmPassword
                ? const Color(0xFF9BA7BA)
                : const Color(0xFF7C3AED),
          ),
          tooltip: _obscureConfirmPassword
              ? 'Show confirm password'
              : 'Hide confirm password',
        ),
      ),
      validator: (value) {
        if (_isLogin) return null;
        if (value == null || value.isEmpty) {
          return 'Confirm password is required';
        }
        if (value != _passwordController.text) {
          return 'Passwords do not match';
        }
        return null;
      },
    );
  }

  Widget _confirmPasswordFeedback() {
    if (_isLogin) return const SizedBox.shrink();
    final confirm = _confirmPasswordController.text;
    final password = _passwordController.text;
    if (confirm.isEmpty) {
      return Text(
        'Re-enter your password to confirm.',
        style: TextStyle(color: _textMutedColor, fontSize: 13),
      );
    }
    final isMatch = confirm == password;
    return Text(
      isMatch ? 'Passwords match' : 'Passwords do not match',
      style: TextStyle(
        color: isMatch ? const Color(0xFF4ADE80) : const Color(0xFFFCA5A5),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _submitButton(AppLocalizations l10n, bool hasPending) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: widget.viewModel.isLoading ? null : (hasPending ? _verifyEmail : _submit),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF111827),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
        ),
        child: widget.viewModel.isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(hasPending ? 'Verify Email' : (_isLogin ? 'Sign In' : l10n.register)),
      ),
    );
  }

  Widget _googleButton() {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: widget.viewModel.isLoading ? null : widget.viewModel.loginWithGoogle,
        icon: const Icon(Icons.g_mobiledata_rounded),
        label: Text(_isLogin ? 'Sign in with Google' : 'Sign up with Google'),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: _isLightMode
                ? const Color(0xFFCCD8EA)
                : const Color(0xFF2D3A52),
          ),
          foregroundColor: _textPrimaryColor,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _switchModeButton() {
    return TextButton(
      onPressed: widget.viewModel.isLoading ? null : _toggleMode,
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: _textMutedColor, fontSize: 16),
          children: [
            TextSpan(
              text: _isLogin ? 'Don\'t have an account? ' : 'Already have an account? ',
            ),
            TextSpan(
              text: _isLogin ? 'Sign up' : 'Sign in',
              style: TextStyle(
                color: _textPrimaryColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTfaStatus() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _isLightMode ? const Color(0xFFF3F7FF) : const Color(0xFF131C2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isLightMode ? const Color(0xFFD5E1F2) : const Color(0xFF22314A),
        ),
      ),
      child: Text(
        widget.viewModel.supportsTfa
            ? 'Two-factor authentication (TFA) is enabled for this server.'
            : 'Two-factor authentication (TFA) is not enabled on this server yet.',
        style: TextStyle(color: _textMutedColor),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: _textPrimaryColor,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hintText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: _isLightMode ? const Color(0xFF7C889C) : const Color(0xFF7A8496),
      ),
      filled: true,
      fillColor: _fieldBgColor,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _fieldBorderColor),
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
