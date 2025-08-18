import 'package:intl/intl.dart';

class CurrencyUtils {
  /// Formats a number as Indian currency with ₹ symbol
  static String formatIndianCurrency(num amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0, // Change to 2 if you want paise
    );
    return formatter.format(amount);
  }

  /// Formats a number as Indian currency with ₹ symbol
  static String formatIndianCurrencyWithoutSign(num amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '', // 👈 removes INR symbol
      decimalDigits: 0, // Change to 2 if you want paise
    );
    return formatter.format(amount);
  }

}
