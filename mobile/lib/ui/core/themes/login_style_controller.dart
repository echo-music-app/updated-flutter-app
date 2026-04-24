import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/widgets.dart';

enum LoginStyleVariant {
  modernLight,
  darkMode,
  gradientVibe,
  glassmorphism,
  minimalClean,
}

class LoginStyleController extends ChangeNotifier {
  LoginStyleController({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage() {
    _load();
  }

  static const _styleKey = 'login_style_variant';

  final FlutterSecureStorage _storage;
  LoginStyleVariant _style = LoginStyleVariant.modernLight;

  LoginStyleVariant get style => _style;

  Future<void> _load() async {
    try {
      final value = await _storage.read(key: _styleKey);
      _style = _parseStyle(value);
      notifyListeners();
    } catch (_) {
      _style = LoginStyleVariant.modernLight;
    }
  }

  Future<void> setStyle(LoginStyleVariant style) async {
    if (_style == style) return;
    _style = style;
    notifyListeners();
    try {
      await _storage.write(key: _styleKey, value: style.name);
    } catch (_) {
      // Ignore persistence failures.
    }
  }

  LoginStyleVariant _parseStyle(String? value) {
    for (final style in LoginStyleVariant.values) {
      if (style.name == value) return style;
    }
    return LoginStyleVariant.modernLight;
  }
}
