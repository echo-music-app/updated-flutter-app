import 'package:flutter/material.dart';
import 'package:mobile/ui/core/themes/app_spacing.dart';
import 'package:mobile/ui/login/password_policy.dart';

class PasswordPolicySection extends StatelessWidget {
  const PasswordPolicySection({
    super.key,
    required this.password,
    this.textColor = const Color(0xFF9BA7BA),
  });

  final String password;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final policy = evaluatePassword(password);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: policy.score / 5,
          minHeight: 6,
          borderRadius: BorderRadius.circular(12),
        ),
        SizedBox(height: AppSpacing.xs),
        Text('Strength: ${policy.label}', style: TextStyle(color: textColor)),
        SizedBox(height: AppSpacing.xs),
        Text(
          'Policy: 8+ chars, upper, lower, number, special',
          style: TextStyle(color: textColor),
        ),
      ],
    );
  }
}
