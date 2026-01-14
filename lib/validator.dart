class AppValidators {
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Please enter a password';

    final passwordRegExp = RegExp(
        r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$'
    );

    if (!passwordRegExp.hasMatch(value)) {
      return 'Must include Uppercase, Number & Symbol';
    }
    return null;
  }
}