import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/generated/l10n/app_localizations.dart';
import 'package:mobile/routing/routes.dart';
import 'package:mobile/ui/core/themes/app_spacing.dart';
import 'package:mobile/ui/core/themes/login_style_controller.dart';
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
  LoginStyleVariant _activeStyle = LoginStyleVariant.modernLight;
  static const _rememberEmailKey = 'remember_me_email';
  static const _rememberPasswordKey = 'remember_me_password';
  static const _bgTop = Color(0xFFF2F3F8);
  static const _bgBottom = Color(0xFFEFF1F7);
  static const _bgTopDark = Color(0xFF0E1230);
  static const _bgBottomDark = Color(0xFF090D24);
  static const _accentStart = Color(0xFF7454FF);
  static const _accentEnd = Color(0xFF5F46FF);
  static const _fieldBg = Color(0xFF0D1118);
  static const _fieldBorder = Color(0xFF222A36);
  static const _textMuted = Color(0xFF9BA7BA);
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
  bool get _isMinimal => _activeStyle == LoginStyleVariant.minimalClean;
  bool get _showDecorativeShapes =>
      _activeStyle != LoginStyleVariant.minimalClean;

  List<Color> get _backgroundGradientColors => switch (_activeStyle) {
    LoginStyleVariant.modernLight => const [_bgTop, _bgBottom],
    LoginStyleVariant.darkMode => const [_bgTopDark, _bgBottomDark],
    LoginStyleVariant.gradientVibe => const [
      Color(0xFF6C4BFF),
      Color(0xFFF26A70),
    ],
    LoginStyleVariant.glassmorphism => const [
      Color(0xFFDCD4F5),
      Color(0xFFC8BEEB),
    ],
    LoginStyleVariant.minimalClean => const [
      Color(0xFFF8F8FA),
      Color(0xFFF4F4F7),
    ],
  };
  Color get _accentStartColor => switch (_activeStyle) {
    LoginStyleVariant.modernLight => _accentStart,
    LoginStyleVariant.darkMode => _accentStart,
    LoginStyleVariant.gradientVibe => const Color(0xFF7C5CFF),
    LoginStyleVariant.glassmorphism => const Color(0xFF7A5BFF),
    LoginStyleVariant.minimalClean => const Color(0xFF7E57FF),
  };
  Color get _accentEndColor => switch (_activeStyle) {
    LoginStyleVariant.modernLight => _accentEnd,
    LoginStyleVariant.darkMode => _accentEnd,
    LoginStyleVariant.gradientVibe => const Color(0xFF6D4BFF),
    LoginStyleVariant.glassmorphism => const Color(0xFF6A4BFF),
    LoginStyleVariant.minimalClean => const Color(0xFF111111),
  };
  List<Color> get _socialTileGradientColors => switch (_activeStyle) {
    LoginStyleVariant.modernLight => const [
      Color(0x00FFFFFF),
      Color(0x00FFFFFF),
    ],
    LoginStyleVariant.darkMode => const [Color(0x00FFFFFF), Color(0x00FFFFFF)],
    LoginStyleVariant.gradientVibe => const [
      Color(0x00FFFFFF),
      Color(0x00FFFFFF),
    ],
    LoginStyleVariant.glassmorphism => const [
      Color(0x40FFFFFF),
      Color(0x35FFFFFF),
    ],
    LoginStyleVariant.minimalClean => const [
      Color(0x00FFFFFF),
      Color(0x00FFFFFF),
    ],
  };
  Color get _fieldBgColor => switch (_activeStyle) {
    LoginStyleVariant.modernLight => const Color(0xFFF5F7FB),
    LoginStyleVariant.darkMode => _fieldBg,
    LoginStyleVariant.gradientVibe => Colors.white.withValues(alpha: 0.08),
    LoginStyleVariant.glassmorphism => Colors.white.withValues(alpha: 0.34),
    LoginStyleVariant.minimalClean => const Color(0xFFF7F8FB),
  };
  Color get _fieldBorderColor => switch (_activeStyle) {
    LoginStyleVariant.modernLight => const Color(0xFFD8E0EC),
    LoginStyleVariant.darkMode => _fieldBorder,
    LoginStyleVariant.gradientVibe => Colors.white.withValues(alpha: 0.35),
    LoginStyleVariant.glassmorphism => Colors.white.withValues(alpha: 0.48),
    LoginStyleVariant.minimalClean => const Color(0xFFD5D9E2),
  };
  Color get _textPrimaryColor => switch (_activeStyle) {
    LoginStyleVariant.modernLight => const Color(0xFF111827),
    LoginStyleVariant.darkMode => Colors.white,
    LoginStyleVariant.gradientVibe => Colors.white,
    LoginStyleVariant.glassmorphism => Colors.white,
    LoginStyleVariant.minimalClean => const Color(0xFF111827),
  };
  Color get _textMutedColor => switch (_activeStyle) {
    LoginStyleVariant.modernLight => const Color(0xFF5B6678),
    LoginStyleVariant.darkMode => _textMuted,
    LoginStyleVariant.gradientVibe => Colors.white.withValues(alpha: 0.74),
    LoginStyleVariant.glassmorphism => Colors.white.withValues(alpha: 0.74),
    LoginStyleVariant.minimalClean => const Color(0xFF6B7280),
  };
  Color get _themeChipBorder => switch (_activeStyle) {
    LoginStyleVariant.modernLight => const Color(0xFFD7DFEB),
    LoginStyleVariant.darkMode => const Color(0xFF2D3A52),
    LoginStyleVariant.gradientVibe => Colors.white.withValues(alpha: 0.28),
    LoginStyleVariant.glassmorphism => Colors.white.withValues(alpha: 0.46),
    LoginStyleVariant.minimalClean => const Color(0xFFD7DFEB),
  };
  Color get _primaryButtonBackground => switch (_activeStyle) {
    LoginStyleVariant.modernLight => _accentEndColor,
    LoginStyleVariant.darkMode => _accentEndColor,
    LoginStyleVariant.gradientVibe => Colors.white,
    LoginStyleVariant.glassmorphism => _accentEndColor,
    LoginStyleVariant.minimalClean => const Color(0xFF090909),
  };
  Color get _primaryButtonForeground => switch (_activeStyle) {
    LoginStyleVariant.gradientVibe => const Color(0xFF6A4CFF),
    _ => Colors.white,
  };
  EdgeInsets get _formContentPadding => EdgeInsets.all(AppSpacing.lg);
  double get _headerBodyGap => AppSpacing.lg;
  double get _topControlInset => 14;
  Color get _socialTileBorderColor => switch (_activeStyle) {
    LoginStyleVariant.gradientVibe => Colors.white.withValues(alpha: 0.24),
    LoginStyleVariant.glassmorphism => Colors.white.withValues(alpha: 0.32),
    _ => Colors.transparent,
  };
  List<BoxShadow> get _socialTileShadows => switch (_activeStyle) {
    LoginStyleVariant.gradientVibe => const [],
    LoginStyleVariant.minimalClean => const [],
    _ => [
      BoxShadow(
        color: Colors.black.withValues(alpha: _isLightMode ? 0.06 : 0.22),
        blurRadius: 14,
        offset: const Offset(0, 8),
      ),
    ],
  };
  Color get _pendingCardBg => switch (_activeStyle) {
    LoginStyleVariant.modernLight => const Color(0xFFF3F7FF),
    LoginStyleVariant.darkMode => const Color(0xFF131C2A),
    LoginStyleVariant.gradientVibe => Colors.white.withValues(alpha: 0.10),
    LoginStyleVariant.glassmorphism => Colors.white.withValues(alpha: 0.16),
    LoginStyleVariant.minimalClean => const Color(0xFFF6F8FC),
  };
  Color get _pendingCardBorder => switch (_activeStyle) {
    LoginStyleVariant.modernLight => const Color(0xFFD5E1F2),
    LoginStyleVariant.darkMode => const Color(0xFF22314A),
    LoginStyleVariant.gradientVibe => Colors.white.withValues(alpha: 0.28),
    LoginStyleVariant.glassmorphism => Colors.white.withValues(alpha: 0.36),
    LoginStyleVariant.minimalClean => const Color(0xFFD5DFEF),
  };
  Color get _errorCardBg => switch (_activeStyle) {
    LoginStyleVariant.modernLight => const Color(0xFF34161A),
    LoginStyleVariant.darkMode => const Color(0xFF34161A),
    LoginStyleVariant.gradientVibe => const Color(0x66B91C1C),
    LoginStyleVariant.glassmorphism => const Color(0x55B91C1C),
    LoginStyleVariant.minimalClean => const Color(0xFFFEECEC),
  };
  Color get _errorCardBorder => switch (_activeStyle) {
    LoginStyleVariant.modernLight => const Color(0xFF5B222B),
    LoginStyleVariant.darkMode => const Color(0xFF5B222B),
    LoginStyleVariant.gradientVibe => const Color(0x99FCA5A5),
    LoginStyleVariant.glassmorphism => const Color(0x99FCA5A5),
    LoginStyleVariant.minimalClean => const Color(0xFFFCA5A5),
  };
  Color get _errorTextColor => switch (_activeStyle) {
    LoginStyleVariant.minimalClean => const Color(0xFF991B1B),
    _ => const Color(0xFFFFCDD2),
  };
  Color get _successTextColor => switch (_activeStyle) {
    LoginStyleVariant.gradientVibe => const Color(0xFFE7FFE9),
    LoginStyleVariant.glassmorphism => const Color(0xFFE9FFEF),
    _ => const Color(0xFF4ADE80),
  };
  Color get _dangerTextColor => switch (_activeStyle) {
    LoginStyleVariant.gradientVibe => const Color(0xFFFFE2E2),
    LoginStyleVariant.glassmorphism => const Color(0xFFFFE2E2),
    _ => const Color(0xFFFCA5A5),
  };
  Color get _mutedControlColor => switch (_activeStyle) {
    LoginStyleVariant.modernLight => const Color(0xFF9BA7BA),
    LoginStyleVariant.darkMode => const Color(0xFF9BA7BA),
    LoginStyleVariant.gradientVibe => Colors.white.withValues(alpha: 0.72),
    LoginStyleVariant.glassmorphism => Colors.white.withValues(alpha: 0.74),
    LoginStyleVariant.minimalClean => const Color(0xFF9BA7BA),
  };
  Color get _shellBgColor => switch (_activeStyle) {
    LoginStyleVariant.modernLight => Colors.white.withValues(alpha: 0.82),
    LoginStyleVariant.darkMode => const Color(0xCC0E1428),
    LoginStyleVariant.gradientVibe => Colors.white.withValues(alpha: 0.10),
    LoginStyleVariant.glassmorphism => Colors.white.withValues(alpha: 0.22),
    LoginStyleVariant.minimalClean => Colors.transparent,
  };
  Color get _shellBorderColor => switch (_activeStyle) {
    LoginStyleVariant.modernLight => const Color(0xDDE1E8F5),
    LoginStyleVariant.darkMode => const Color(0xFF2C3550),
    LoginStyleVariant.gradientVibe => Colors.white.withValues(alpha: 0.30),
    LoginStyleVariant.glassmorphism => Colors.white.withValues(alpha: 0.38),
    LoginStyleVariant.minimalClean => Colors.transparent,
  };
  List<BoxShadow> get _shellShadows => switch (_activeStyle) {
    LoginStyleVariant.minimalClean => const [],
    LoginStyleVariant.gradientVibe => const [],
    _ => [
      BoxShadow(
        color: Colors.black.withValues(alpha: _isLightMode ? 0.10 : 0.32),
        blurRadius: 30,
        offset: const Offset(0, 14),
      ),
    ],
  };

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
    _activeStyle = context.watch<LoginStyleController>().style;
    _isLightMode = switch (_activeStyle) {
      LoginStyleVariant.darkMode => false,
      LoginStyleVariant.gradientVibe => false,
      _ => true,
    };
    final themeController = context.watch<ThemeModeController>();
    final isDarkMode = themeController.isDarkMode;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _backgroundGradientColors,
          ),
        ),
        child: Stack(
          children: [
            if (_showDecorativeShapes)
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
                      color: _accentStartColor.withValues(
                        alpha: _isLightMode ? 0.10 : 0.16,
                      ),
                    ),
                  ),
                ),
              ),
            if (_showDecorativeShapes)
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
                      color: _accentEndColor.withValues(
                        alpha: _isLightMode ? 0.12 : 0.14,
                      ),
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
                      child: _formShell(
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
                                      SizedBox(height: AppSpacing.md),
                                      if (pending == null) ...[
                                        _modeSwitchTabs(),
                                        SizedBox(height: _headerBodyGap),
                                      ] else
                                        SizedBox(height: AppSpacing.sm),
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
                                        if (_isMinimal)
                                          Row(
                                            children: [
                                              Expanded(
                                                child: CheckboxListTile(
                                                  dense: true,
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                  controlAffinity:
                                                      ListTileControlAffinity
                                                          .leading,
                                                  activeColor:
                                                      _accentStartColor,
                                                  value: _rememberMe,
                                                  onChanged:
                                                      widget.viewModel.isLoading
                                                      ? null
                                                      : (value) async {
                                                          final next =
                                                              value ?? false;
                                                          setState(
                                                            () => _rememberMe =
                                                                next,
                                                          );
                                                          if (!next) {
                                                            await _syncRememberedCredentials();
                                                          }
                                                        },
                                                  title: Text(
                                                    'Remember me',
                                                    style: TextStyle(
                                                      color: _textPrimaryColor,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed:
                                                    widget.viewModel.isLoading
                                                    ? null
                                                    : () {},
                                                child: Text(
                                                  'Forgot password?',
                                                  style: TextStyle(
                                                    color: _accentStartColor,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          )
                                        else
                                          CheckboxListTile(
                                            dense: true,
                                            contentPadding: EdgeInsets.zero,
                                            controlAffinity:
                                                ListTileControlAffinity.leading,
                                            activeColor: _accentStartColor,
                                            value: _rememberMe,
                                            onChanged:
                                                widget.viewModel.isLoading
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
                                      SizedBox(height: _headerBodyGap),
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
                                      if (pending == null && _isMinimal)
                                        _switchModeButton(),
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
              top: _topControlInset,
              left: _topControlInset,
              child: SafeArea(
                child: Builder(
                  builder: (context) => Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        if (_isMinimal && Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                          return;
                        }
                        showAppSidebar(context);
                      },
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: _isMinimal
                              ? Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: _textPrimaryColor,
                                  size: 20,
                                )
                              : _sidebarMenuIcon(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: _topControlInset,
              right: _topControlInset,
              child: _isMinimal
                  ? const SizedBox.shrink()
                  : SafeArea(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
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
                                size: 24,
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

  Widget _formShell({required Widget child}) {
    if (_activeStyle == LoginStyleVariant.minimalClean) {
      return Padding(padding: _formContentPadding, child: child);
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: _shellBgColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _shellBorderColor),
        boxShadow: _shellShadows,
      ),
      child: Padding(padding: _formContentPadding, child: child),
    );
  }

  Widget _modeSwitchTabs() {
    Widget tab({
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: selected
                ? LinearGradient(colors: [_accentStartColor, _accentEndColor])
                : null,
            color: selected ? null : Colors.transparent,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: widget.viewModel.isLoading ? null : onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? Colors.white : _textMutedColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _fieldBgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _fieldBorderColor),
      ),
      child: Row(
        children: [
          tab(
            label: 'Sign In',
            selected: _isLogin,
            onTap: () {
              if (_isLogin) return;
              _toggleMode();
            },
          ),
          const SizedBox(width: 4),
          tab(
            label: 'Sign Up',
            selected: !_isLogin,
            onTap: () {
              if (!_isLogin) return;
              _toggleMode();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isLogin) {
    final width = MediaQuery.of(context).size.width;
    final logoSize = width < 380 ? 64.0 : 76.0;
    final subtitleSize = width < 380 ? 15.0 : 16.0;
    final headlineSize = switch (_activeStyle) {
      LoginStyleVariant.gradientVibe => 32.0,
      LoginStyleVariant.minimalClean => 30.0,
      _ => 31.0,
    };
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
        if (_activeStyle != LoginStyleVariant.minimalClean)
          Container(
            width: 78,
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                colors: [_accentStartColor, _accentEndColor],
              ),
            ),
          ),
        SizedBox(
          height: _activeStyle == LoginStyleVariant.minimalClean
              ? AppSpacing.sm
              : AppSpacing.md,
        ),
        Text(
          'Welcome back',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _textPrimaryColor,
            fontSize: headlineSize,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: AppSpacing.xs),
        Text(
          isLogin ? 'Sign in to continue' : 'Create your account',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _textMutedColor,
            fontSize: subtitleSize,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPendingCard(String message, String? debugCode) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _pendingCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _pendingCardBorder),
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
        color: _errorCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _errorCardBorder),
      ),
      child: Text(message, style: TextStyle(color: _errorTextColor)),
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
            color: _obscurePassword ? _mutedControlColor : _accentStartColor,
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
                ? _mutedControlColor
                : _accentStartColor,
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
        color: isMatch ? _successTextColor : _dangerTextColor,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _submitButton(AppLocalizations l10n, bool hasPending) {
    final useGradientButton =
        _activeStyle == LoginStyleVariant.modernLight ||
        _activeStyle == LoginStyleVariant.darkMode ||
        _activeStyle == LoginStyleVariant.glassmorphism;

    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: widget.viewModel.isLoading
            ? null
            : (hasPending ? _verifyEmail : _submit),
        style: ElevatedButton.styleFrom(
          backgroundColor: useGradientButton
              ? Colors.transparent
              : _primaryButtonBackground,
          foregroundColor: _primaryButtonForeground,
          elevation: _activeStyle == LoginStyleVariant.minimalClean ? 0 : 8,
          shadowColor: _accentStartColor.withValues(alpha: 0.45),
          side: _activeStyle == LoginStyleVariant.minimalClean
              ? BorderSide(color: Colors.black.withValues(alpha: 0.9))
              : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: useGradientButton
                ? LinearGradient(colors: [_accentStartColor, _accentEndColor])
                : null,
          ),
          child: Center(
            child: widget.viewModel.isLoading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        useGradientButton
                            ? Colors.white
                            : _primaryButtonForeground,
                      ),
                    ),
                  )
                : Text(
                    hasPending
                        ? 'Verify Email'
                        : (_isLogin ? 'Sign In' : l10n.register),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _socialLoginRow() {
    final heading = _highlightHint('Or continue with', forceCenter: true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: _themeChipBorder)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: heading,
            ),
            Expanded(child: Divider(color: _themeChipBorder)),
          ],
        ),
        SizedBox(height: AppSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final spacing = AppSpacing.sm;
            final maxWidth = constraints.hasBoundedWidth
                ? constraints.maxWidth
                : MediaQuery.of(context).size.width;
            final availableWidth = (maxWidth - (spacing * 2)).clamp(
              0.0,
              double.infinity,
            );
            final itemWidth = (availableWidth / 3)
                .clamp(96.0, 220.0)
                .toDouble();
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                SizedBox(
                  width: itemWidth,
                  child: _socialTile(
                    label: 'Spotify',
                    onTap: widget.viewModel.isLoading
                        ? null
                        : widget.viewModel.connectWithSpotify,
                    child: _spotifyLogo(),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _socialTile(
                    label: 'SoundCloud',
                    onTap: widget.viewModel.isLoading
                        ? null
                        : widget.viewModel.loginWithSoundCloud,
                    child: _soundCloudLogo(),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _socialTile(
                    label: 'Apple',
                    onTap: widget.viewModel.isLoading
                        ? null
                        : widget.viewModel.loginWithApple,
                    child: _appleLogo(),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _socialTile({
    required String label,
    required Widget child,
    required VoidCallback? onTap,
  }) {
    final tileRadius = _activeStyle == LoginStyleVariant.minimalClean
        ? 14.0
        : 22.0;
    final tileHeight = switch (_activeStyle) {
      LoginStyleVariant.minimalClean => 98.0,
      LoginStyleVariant.gradientVibe => 110.0,
      _ => 124.0,
    };
    final tileHasSurface = _activeStyle == LoginStyleVariant.glassmorphism;
    return Semantics(
      button: true,
      label: _isLogin ? 'Sign in with $label' : 'Sign up with $label',
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: onTap == null ? 0.6 : 1,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(tileRadius),
          child: Ink(
            height: tileHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(tileRadius),
              border: Border.all(color: _socialTileBorderColor),
              boxShadow: _socialTileShadows,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _socialTileGradientColors,
              ),
              color: tileHasSurface
                  ? Colors.white.withValues(alpha: 0.08)
                  : null,
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
      ),
    );
  }

  Widget _spotifyLogo() {
    if (_activeStyle == LoginStyleVariant.gradientVibe ||
        _activeStyle == LoginStyleVariant.minimalClean) {
      return Container(
        width: _socialLogoSize,
        height: _socialLogoSize,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: _activeStyle == LoginStyleVariant.minimalClean
              ? Border.all(color: _themeChipBorder)
              : null,
        ),
        child: const Center(
          child: Icon(Icons.album_rounded, color: _spotifyGreen, size: 30),
        ),
      );
    }
    return Container(
      width: _socialLogoSize,
      height: _socialLogoSize,
      decoration: BoxDecoration(
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
    if (_activeStyle == LoginStyleVariant.gradientVibe ||
        _activeStyle == LoginStyleVariant.minimalClean) {
      return Container(
        width: _socialLogoSize,
        height: _socialLogoSize,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: _activeStyle == LoginStyleVariant.minimalClean
              ? Border.all(color: _themeChipBorder)
              : null,
        ),
        child: const Center(
          child: Icon(Icons.apple, size: 30, color: Colors.black),
        ),
      );
    }
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
    if (_activeStyle == LoginStyleVariant.gradientVibe ||
        _activeStyle == LoginStyleVariant.minimalClean) {
      return Container(
        width: _socialLogoSize,
        height: _socialLogoSize,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: _activeStyle == LoginStyleVariant.minimalClean
              ? Border.all(color: _themeChipBorder)
              : null,
        ),
        child: const Center(
          child: Icon(Icons.cloud_rounded, size: 30, color: _soundCloudOrange),
        ),
      );
    }
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
        color: _pendingCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _pendingCardBorder),
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
    const widths = [12.0, 16.0, 22.0];
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
        children: [line(widths[0]), line(widths[1]), line(widths[2])],
      ),
    );
  }

  Widget _highlightHint(String text, {bool forceCenter = false}) {
    final align = forceCenter ? Alignment.center : Alignment.center;
    return Align(
      alignment: align,
      child: Text(
        _activeStyle == LoginStyleVariant.minimalClean
            ? text.toLowerCase()
            : text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _textMutedColor,
          fontSize: 13,
          fontWeight: FontWeight.w600,
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
        borderSide: BorderSide(color: _accentEndColor, width: 1.6),
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
