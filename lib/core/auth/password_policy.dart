/// Keep in sync with the backend password defaults.
class PasswordPolicy {
  static const requirements =
      'Use 8–128 characters with uppercase and lowercase letters, a number, and a symbol.';

  static String? validate(String? value) {
    final password = value ?? '';
    if (password.length < 8 || password.length > 128) {
      return 'Use 8–128 characters.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password) ||
        !RegExp(r'[a-z]').hasMatch(password)) {
      return 'Include uppercase and lowercase letters.';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Include at least one number.';
    }
    if (!RegExp(r'[^\w\s]|_').hasMatch(password)) {
      return 'Include at least one symbol.';
    }
    return null;
  }
}
