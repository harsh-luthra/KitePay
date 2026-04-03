class AppConstants {

  // Base API URL
  static const String baseApiUrl = "https://kite-pay-api-v1.onrender.com/api";
  // static const String baseApiUrl = "http://127.0.0.1:3000/api";

  static const String baseApiUrlSocket = "https://kite-pay-api-v1.onrender.com";
  // static const String baseApiUrlSocket = "http://127.0.0.1:3000";

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
  static const String viewUsers = "view_users";
  static const String createSubadmin = "create_subadmin";

  static const String viewTransactions = "view_transactions";
  static const String changeTransactionStatus = "change_transaction_status";
  static const String transactionImageUpload = "transaction_image_upload";

  static const String editWithdrawalAccounts = "edit_withdrawal_accounts";

  static const String viewAQrCodes = "view_qr_codes";
  static const String assignQrCodes = "assign_qr_codes";
  static const String toggleQrStatus = "toggle_qr_status";

  static const String checkWithdrawals = "check_withdrawals";

  static const String viewDashboards = "view_dashboards";

  // 'view_users',
  // 'create_subadmin',
  // 'view_transactions',
  // 'change_transaction_status',
  // 'transaction_image_upload',
  // 'edit_withdrawal_accounts'
  // 'view_qr_codes'
  // 'assign_qr_codes'
  // 'toggle_qr_status'
  // 'check_withdrawals'

  // Appwrite
  static const String appwriteEndpoint = 'https://fra.cloud.appwrite.io/v1';
  static const String appwriteProjectId = '688c98fd002bfe3cf596';
  static const String appwriteBucketId = '688d2517002810ac532b';

  static String appwriteFileViewUrl(String bucketId, String fileId) =>
      '$appwriteEndpoint/storage/buckets/$bucketId/files/$fileId/view?project=$appwriteProjectId';
}








