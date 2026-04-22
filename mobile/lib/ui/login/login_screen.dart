import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  static const _rememberEmailKey = 'remember_me_email';
  static const _rememberPasswordKey = 'remember_me_password';
  static const _bgTop = Color(0xFF0B1222);
  static const _bgBottom = Color(0xFF050912);
  static const _fieldBg = Color(0xFF0D1118);
  static const _fieldBorder = Color(0xFF222A36);
  static const _textMuted = Color(0xFF9BA7BA);
  static const _purpleStart = Color(0xFF7C3AED);
  static const _purpleEnd = Color(0xFF5B5FFB);
  static const _spotifyGreen = Color(0xFF1ED760);
  static const _soundCloudOrange = Color(0xFFFF7700);
  static const _socialLogoSize = 56.0;
  static const _socialLogoCornerRadius = 18.0;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _verificationCodeController = TextEditingController();
  final _mfaCodeController = TextEditingController();
  final _secureStorage = const FlutterSecureStorage();

  late final AnimationController _entryController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideIn;

  String? _lastPendingEmail;
  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLightMode = false;
  bool _rememberMe = false;

  Color get _bgTopColor => _isLightMode ? const Color(0xFFF7F9FC) : _bgTop;
  Color get _bgBottomColor =>
      _isLightMode ? const Color(0xFFEFF3FA) : _bgBottom;
  Color get _fieldBgColor => _isLightMode ? const Color(0xFFF5F7FB) : _fieldBg;
  Color get _fieldBorderColor =>
      _isLightMode ? const Color(0xFFD8E0EC) : _fieldBorder;
  Color get _textPrimaryColor =>
      _isLightMode ? const Color(0xFF111827) : Colors.white;
  Color get _textMutedColor =>
      _isLightMode ? const Color(0xFF5B6678) : _textMuted;
  Color get _themeChipBg =>
      _isLightMode ? const Color(0xFFF3F6FC) : const Color(0xAA0D1118);
  Color get _themeChipBorder =>
      _isLightMode ? const Color(0xFFD7DFEB) : const Color(0xFF2D3A52);

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
    _slideIn = Tween<Offset>(begin: const Offset(0, 0.07), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
        );
    _entryController.forward();
    _loadRememberedCredentials();
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
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    if (_isLogin) {
      await widget.viewModel.loginWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
        mfaCode: _mfaCodeController.text.trim().isEmpty
            ? null
            : _mfaCodeController.text.trim(),
      );
      if (widget.viewModel.isAuthenticated) {
        await _syncRememberedCredentials();
      }
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

  Future<void> _loadRememberedCredentials() async {
    final savedEmail = await _secureStorage.read(key: _rememberEmailKey);
    final savedPassword = await _secureStorage.read(key: _rememberPasswordKey);
    if (!mounted) return;
    if (savedEmail == null || savedPassword == null) return;
    setState(() {
      _rememberMe = true;
      _emailController.text = savedEmail;
      _passwordController.text = savedPassword;
    });
  }

  Future<void> _syncRememberedCredentials() async {
    if (_rememberMe) {
      await _secureStorage.write(
        key: _rememberEmailKey,
        value: _emailController.text.trim(),
      );
      await _secureStorage.write(
        key: _rememberPasswordKey,
        value: _passwordController.text,
      );
      return;
    }
    await _secureStorage.delete(key: _rememberEmailKey);
    await _secureStorage.delete(key: _rememberPasswordKey);
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
                    color: _purpleStart.withValues(
                      alpha: _isLightMode ? 0.10 : 0.16,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -120,
              left: -70,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.9, end: 1),
                duration: const Duration(milliseconds: 1500),
                curve: Curves.easeOutCubic,
                builder: (_, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        (_isLightMode
                                ? const Color(0xFF4F8DFD)
                                : const Color(0xFF4B6BFF))
                            .withValues(alpha: _isLightMode ? 0.10 : 0.12),
                  ),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.all(AppSpacing.lg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: FadeTransition(
                    opacity: _fadeIn,
                    child: SlideTransition(
                      position: _slideIn,
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: ListenableBuilder(
                          listenable: widget.viewModel,
                          builder: (context, _) {
                            if (widget.viewModel.isAuthenticated) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted) return;
                                context.go(Routes.home);
                              });
                            }

                            final pending =
                                widget.viewModel.pendingVerification;
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
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 260),
                                child: AutofillGroup(
                                  child: Column(
                                    key: ValueKey(
                                      '$_isLogin-${pending != null}-${widget.viewModel.mfaRequired}',
                                    ),
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildHeader(_isLogin),
                                      SizedBox(height: AppSpacing.lg),
                                      if (pending != null) ...[
                                        _buildPendingCard(
                                          pending.message,
                                          pending.debugCode,
                                        ),
                                        SizedBox(height: AppSpacing.md),
                                        SizedBox(
                                          height: 48,
                                          child: OutlinedButton(
                                            onPressed:
                                                widget.viewModel.isLoading
                                                ? null
                                                : () => context.go(
                                                    '${Routes.verifyEmail}?email=${Uri.encodeComponent(pending.email)}',
                                                  ),
                                            child: const Text(
                                              'Open verification screen',
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: AppSpacing.md),
                                      ],
                                      if (widget.viewModel.error != null) ...[
                                        _buildErrorCard(
                                          widget.viewModel.error!,
                                        ),
                                        SizedBox(height: AppSpacing.md),
                                      ],
                                      _isLogin
                                          ? _highlightHint('Welcome back')
                                          : _sectionHint('Create your profile'),
                                      SizedBox(height: AppSpacing.sm),
                                      _label(l10n.email),
                                      _emailField(),
                                      SizedBox(height: AppSpacing.md),
                                      AnimatedCrossFade(
                                        duration: const Duration(
                                          milliseconds: 220,
                                        ),
                                        crossFadeState: _isLogin
                                            ? CrossFadeState.showFirst
                                            : CrossFadeState.showSecond,
                                        firstChild: const SizedBox.shrink(),
                                        secondChild: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
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
                                        duration: const Duration(
                                          milliseconds: 220,
                                        ),
                                        crossFadeState: _isLogin
                                            ? CrossFadeState.showFirst
                                            : CrossFadeState.showSecond,
                                        firstChild: const SizedBox.shrink(),
                                        secondChild: Column(
                                          children: [
                                            SizedBox(height: AppSpacing.sm),
                                            PasswordPolicySection(
                                              password:
                                                  _passwordController.text,
                                              textColor: _textMuted,
                                            ),
                                          ],
                                        ),
                                      ),
                                      AnimatedCrossFade(
                                        duration: const Duration(
                                          milliseconds: 220,
                                        ),
                                        crossFadeState: _isLogin
                                            ? CrossFadeState.showFirst
                                            : CrossFadeState.showSecond,
                                        firstChild: const SizedBox.shrink(),
                                        secondChild: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            SizedBox(height: AppSpacing.md),
                                            _label('Confirm Password'),
                                            _confirmPasswordField(),
                                            SizedBox(height: AppSpacing.xs),
                                            _confirmPasswordFeedback(),
                                          ],
                                        ),
                                      ),
                                      if (_isLogin &&
                                          pending == null &&
                                          widget.viewModel.mfaRequired) ...[
                                        SizedBox(height: AppSpacing.md),
                                        _label('2FA Code'),
                                        _mfaField(),
                                      ],
                                      if (_isLogin && pending == null) ...[
                                        SizedBox(height: AppSpacing.sm),
                                        CheckboxListTile(
                                          dense: true,
                                          contentPadding: EdgeInsets.zero,
                                          controlAffinity:
                                              ListTileControlAffinity.leading,
                                          activeColor: _purpleStart,
                                          value: _rememberMe,
                                          onChanged: widget.viewModel.isLoading
                                              ? null
                                              : (value) async {
                                                  final next = value ?? false;
                                                  setState(
                                                    () => _rememberMe = next,
                                                  );
                                                  if (!next) {
                                                    await _syncRememberedCredentials();
                                                  }
                                                },
                                          title: Text(
                                            'Remember me',
                                            style: TextStyle(
                                              color: _textPrimaryColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (pending != null) ...[
                                        SizedBox(height: AppSpacing.md),
                                        _label('Verification Code'),
                                        TextFormField(
                                          controller:
                                              _verificationCodeController,
                                          keyboardType: TextInputType.number,
                                          enabled: !widget.viewModel.isLoading,
                                          style: TextStyle(
                                            color: _textPrimaryColor,
                                          ),
                                          decoration: _fieldDecoration(
                                            hintText: '123456',
                                          ),
                                        ),
                                      ],
                                      SizedBox(height: AppSpacing.lg),
                                      _submitButton(l10n, pending != null),
                                      if (pending == null) ...[
                                        SizedBox(height: AppSpacing.sm),
                                        _socialLoginRow(),
                                      ],
                                      if (pending != null) ...[
                                        SizedBox(height: AppSpacing.xs),
                                        TextButton(
                                          onPressed: widget.viewModel.isLoading
                                              ? null
                                              : () => widget.viewModel
                                                    .resendVerificationCode(
                                                      _emailController.text
                                                          .trim(),
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
            Positioned(
              top: 14,
              left: 14,
              child: SafeArea(
                child: Builder(
                  builder: (context) => Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => showAppSidebar(context),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(child: _sidebarMenuIcon()),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 14,
              right: 14,
              child: SafeArea(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => themeController.toggle(),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: Icon(
                          isDarkMode
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          color: _textPrimaryColor,
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
    final width = MediaQuery.of(context).size.width;
    final logoSize = width < 380 ? 64.0 : 76.0;
    final subtitleSize = width < 380 ? 18.0 : 22.0;
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.92, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutBack,
          builder: (_, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: SizedBox(
            height: logoSize,
            width: logoSize,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                _isLightMode
                    ? 'assets/images/logo_dark.png'
                    : 'assets/images/logo_light.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        SizedBox(height: AppSpacing.md),
        Container(
          width: 78,
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(colors: [_purpleStart, _purpleEnd]),
          ),
        ),
        SizedBox(height: AppSpacing.md),
        Text(
          isLogin ? 'Sign in to your account' : 'Create your account',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _textPrimaryColor,
            fontSize: subtitleSize,
            fontWeight: FontWeight.w700,
          ),
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
      textInputAction: _isLogin ? TextInputAction.next : TextInputAction.next,
      autofillHints: const [AutofillHints.email],
      enabled: !widget.viewModel.isLoading,
      style: TextStyle(color: _textPrimaryColor),
      decoration: _fieldDecoration(
        hintText: 'you@example.com',
        prefixIcon: const Icon(Icons.alternate_email_rounded),
      ),
      onFieldSubmitted: (_) {
        FocusScope.of(context).nextFocus();
      },
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
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.username],
      enabled: !widget.viewModel.isLoading,
      style: TextStyle(color: _textPrimaryColor),
      decoration: _fieldDecoration(
        hintText: 'your_username',
        prefixIcon: const Icon(Icons.person_outline_rounded),
      ),
      onFieldSubmitted: (_) {
        FocusScope.of(context).nextFocus();
      },
      validator: (value) {
        if (_isLogin) {
          return null;
        }
        if (value == null || value.trim().isEmpty) {
          return 'Username is required';
        }
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
      textInputAction: _isLogin ? TextInputAction.done : TextInputAction.next,
      autofillHints: const [AutofillHints.password],
      enabled: !widget.viewModel.isLoading,
      style: TextStyle(color: _textPrimaryColor),
      decoration: _fieldDecoration(
        hintText: '********',
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          onPressed: widget.viewModel.isLoading
              ? null
              : () => setState(() => _obscurePassword = !_obscurePassword),
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            color: _obscurePassword
                ? const Color(0xFF9BA7BA)
                : const Color(0xFF7C3AED),
          ),
          tooltip: _obscurePassword ? 'Show password' : 'Hide password',
        ),
      ),
      onFieldSubmitted: (_) {
        if (_isLogin) {
          _submit();
          return;
        }
        FocusScope.of(context).nextFocus();
      },
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
      textInputAction: TextInputAction.done,
      enabled: !widget.viewModel.isLoading,
      style: TextStyle(color: _textPrimaryColor),
      decoration: _fieldDecoration(
        hintText: '123456',
        prefixIcon: const Icon(Icons.shield_outlined),
      ),
      onFieldSubmitted: (_) => _submit(),
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
      textInputAction: TextInputAction.done,
      enabled: !widget.viewModel.isLoading,
      style: TextStyle(color: _textPrimaryColor),
      decoration: _fieldDecoration(
        hintText: '********',
        prefixIcon: const Icon(Icons.verified_user_outlined),
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
      onFieldSubmitted: (_) => _submit(),
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
        onPressed: widget.viewModel.isLoading
            ? null
            : (hasPending ? _verifyEmail : _submit),
        style: ElevatedButton.styleFrom(
          backgroundColor: _purpleEnd,
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: _purpleStart.withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        child: widget.viewModel.isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                hasPending
                    ? 'Verify Email'
                    : (_isLogin ? 'Sign In' : l10n.register),
              ),
      ),
    );
  }

  Widget _socialLoginRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: _themeChipBorder)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _highlightHint('Or continue with'),
            ),
            Expanded(child: Divider(color: _themeChipBorder)),
          ],
        ),
        SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _socialTile(
                label: 'Spotify',
                onTap: widget.viewModel.isLoading
                    ? null
                    : widget.viewModel.connectWithSpotify,
                child: _spotifyLogo(),
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _socialTile(
                label: 'SoundCloud',
                onTap: widget.viewModel.isLoading
                    ? null
                    : widget.viewModel.loginWithSoundCloud,
                child: _soundCloudLogo(),
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _socialTile(
                label: 'Apple',
                onTap: widget.viewModel.isLoading
                    ? null
                    : widget.viewModel.loginWithApple,
                child: _appleLogo(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _socialTile({
    required String label,
    required Widget child,
    required VoidCallback? onTap,
  }) {
    return Semantics(
      button: true,
      label: _isLogin ? 'Sign in with $label' : 'Sign up with $label',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          height: 124,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _themeChipBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: _isLightMode ? 0.06 : 0.22,
                ),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _isLightMode
                  ? const [Color(0xFFF9FBFF), Color(0xFFF0F5FE)]
                  : const [Color(0xFF101722), Color(0xFF0A0F18)],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              child,
              SizedBox(height: AppSpacing.xs),
              Text(
                label,
                style: TextStyle(
                  color: _textPrimaryColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _spotifyLogo() {
    return Container(
      width: _socialLogoSize,
      height: _socialLogoSize,
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.all(
          Radius.circular(_socialLogoCornerRadius),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: _spotifyGreen,
              shape: BoxShape.circle,
            ),
          ),
          CustomPaint(
            size: const Size(26, 17),
            painter: _SpotifyGlyphPainter(),
          ),
        ],
      ),
    );
  }

  Widget _appleLogo() {
    return Container(
      width: _socialLogoSize,
      height: _socialLogoSize,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF6B85), Color(0xFFE83D57)],
        ),
        borderRadius: BorderRadius.circular(_socialLogoCornerRadius),
      ),
      child: const Center(
        child: Icon(Icons.apple, size: 28, color: Colors.white),
      ),
    );
  }

  Widget _soundCloudLogo() {
    return Container(
      width: _socialLogoSize,
      height: _socialLogoSize,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF9A1A), _soundCloudOrange],
        ),
        borderRadius: BorderRadius.circular(_socialLogoCornerRadius),
      ),
      child: const Center(
        child: Icon(Icons.cloud_rounded, size: 28, color: Colors.white),
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
              text: _isLogin
                  ? 'Don\'t have an account? '
                  : 'Already have an account? ',
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
          color: _isLightMode
              ? const Color(0xFFD5E1F2)
              : const Color(0xFF22314A),
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
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _sidebarMenuIcon() {
    final lineColor = _isLightMode ? const Color(0xFF1A2233) : Colors.white;
    Widget line(double width) => Container(
      width: width,
      height: 4,
      decoration: BoxDecoration(
        color: lineColor,
        borderRadius: BorderRadius.circular(999),
      ),
    );

    return SizedBox(
      width: 24,
      height: 18,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [line(12), line(16), line(22)],
      ),
    );
  }

  Widget _sectionHint(String text) {
    return Text(
      text,
      style: TextStyle(
        color: _textMutedColor,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _highlightHint(String text) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: _isLightMode
              ? const Color(0xFFEAF0FF)
              : const Color(0xFF1A2340),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: _isLightMode
                ? const Color(0xFFC9D6F8)
                : const Color(0xFF334A7A),
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _isLightMode
                ? const Color(0xFF243B76)
                : const Color(0xFFDCE5FF),
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hintText,
    Widget? suffixIcon,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: _isLightMode ? const Color(0xFF7C889C) : const Color(0xFF7A8496),
      ),
      filled: true,
      fillColor: _fieldBgColor,
      prefixIcon: prefixIcon,
      prefixIconColor: _isLightMode
          ? const Color(0xFF55627A)
          : const Color(0xFF95A4BD),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _fieldBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _purpleEnd, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE57373)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE57373), width: 1.4),
      ),
    );
  }
}

class _SpotifyGlyphPainter extends CustomPainter {
  const _SpotifyGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF121212)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.2;

    final arc1 = Rect.fromLTWH(-2, 0, size.width + 6, size.height + 8);
    final arc2 = Rect.fromLTWH(1, 6, size.width - 1, size.height + 2);
    final arc3 = Rect.fromLTWH(4, 12, size.width - 9, size.height - 4);

    canvas.drawArc(arc1, 3.95, 1.45, false, paint);
    canvas.drawArc(arc2, 3.95, 1.38, false, paint);
    canvas.drawArc(arc3, 3.95, 1.32, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
