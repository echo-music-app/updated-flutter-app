class PasswordPolicyResult {
  const PasswordPolicyResult({
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasNumber,
    required this.hasSpecial,
  });

  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasNumber;
  final bool hasSpecial;

  bool get isValid =>
      hasMinLength &&
      hasUppercase &&
      hasLowercase &&
      hasNumber &&
      hasSpecial;

  int get score {
    var value = 0;
    if (hasMinLength) value++;
    if (hasUppercase) value++;
    if (hasLowercase) value++;
    if (hasNumber) value++;
    if (hasSpecial) value++;
    return value;
  }

  String get label {
    if (score <= 2) return 'Weak';
    if (score == 3 || score == 4) return 'Medium';
    return 'Strong';
  }
}

PasswordPolicyResult evaluatePassword(String input) {
  final value = input.trim();
  return PasswordPolicyResult(
    hasMinLength: value.length >= 8,
    hasUppercase: RegExp(r'[A-Z]').hasMatch(value),
    hasLowercase: RegExp(r'[a-z]').hasMatch(value),
    hasNumber: RegExp(r'\d').hasMatch(value),
    hasSpecial: RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=/\\\[\]~`]').hasMatch(value),
  );
}
