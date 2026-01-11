class AppConstants {

  // Base API URL
  // static const String baseApiUrl = "https://kite-pay-api-v1.onrender.com/api";
  // static const String baseApiUrl = "http://192.168.1.14:3000/api";
  static const String baseApiUrl = "http://127.0.0.1:3000/api";

  // static const String baseApiUrl = "http://46.202.164.198:3000/api";
  // https://kite-pay-api-v1.onrender.com

  // Auth Endpoints
  static const String loginEndpoint = "$baseApiUrl/auth/login";
  static const String registerEndpoint = "$baseApiUrl/auth/register";

  // User Endpoints
  static const String getUsers = "$baseApiUrl/admin/users";
  static const String createUser = "$baseApiUrl/admin/users/create";

  // Export Transactions
  static const String exportTransactions = "$baseApiUrl/admin/user/transactions/export";

  // Transactions
  static const String getTransactions = "$baseApiUrl/transactions";

  // FEATURE LABELS
  static const String viewAllUsers = "all_users";

  static const String viewAllQrCodes = "all_qr";

  static const String viewAllTransactions = "all_transactions";
  static const String editTransactions = "edit_transactions";
  static const String manualTransactions = "manual_transactions";

  static const String viewAllWithdrawals = "all_withdrawals";
  static const String manageAllWithdrawals = "edit_withdrawals";

  // Add more endpoints as needed...
}



