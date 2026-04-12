import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/ui/login/password_policy.dart';

void main() {
  group('evaluatePassword', () {
    test('marks strong password as valid', () {
      final result = evaluatePassword('String@123');

      expect(result.isValid, isTrue);
      expect(result.score, 5);
      expect(result.label, 'Strong');
    });

    test('marks weak password as invalid', () {
      final result = evaluatePassword('abc');

      expect(result.isValid, isFalse);
      expect(result.score, lessThan(3));
      expect(result.label, 'Weak');
    });
  });
}
