import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/core/auth/password_policy.dart';

void main() {
  test('New passwords must contain 8 to 20 characters', () {
    expect(PasswordPolicy.validate('Short1!'), isNotNull);
    expect(PasswordPolicy.validate('Valid12!'), isNull);
    final twenty = List.filled(5, 'Aa1!').join();
    expect(PasswordPolicy.validate(twenty), isNull);
    expect(PasswordPolicy.validate('${twenty}x'), 'Use 8–20 characters.');
    expect(PasswordPolicy.validate('lowercase123!'), isNotNull);
    expect(PasswordPolicy.validate('MissingSymbols123'), isNotNull);
  });
}
