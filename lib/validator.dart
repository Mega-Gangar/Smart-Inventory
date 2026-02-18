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
  static String? validateGSTIN(String? value){
    if (value == null || value.isEmpty) return null;
    if (value?.length != 15) {
      return "GSTIN must be exactly 15 characters";
    }
    final gstinRegExp = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$').hasMatch(value.toUpperCase());
    if (!gstinRegExp) {
      return "Invalid GSTIN format \n(e.g. 22AAAAA0000A1Z5)";
    }
    return null;
  }
  static String? validateCompanyName(String? value){
    if (value == null || value.trim().isEmpty) return "Company Name cannot be empty!";
    return null;
  }
}