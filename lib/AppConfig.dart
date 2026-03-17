class AppConfig {
  static final AppConfig _instance = AppConfig._internal();

  factory AppConfig() => _instance;

  AppConfig._internal();

  bool isLoaded = false;

  int maxWithdrawalAmount = 0;
  int minWithdrawalAmount = 0;
  int maxWithdrawalRequests = 2;
  double transactionFeePercent = 0;
  int overheadBalanceRequired = 0;

  double minCommission = 1.0;
  double maxCommission = 2.0;

  double qrLimitTodayPayIn = 30000000.0;

  int maxWithdrawalAccounts = 5;

  bool userCanEditWithdrawalAccounts = false;

  bool txnImageSupport = false;

  bool manualTxnPageEnabled = false;

  void loadFromJson(Map<String, dynamic> json) {
    maxWithdrawalAmount = json['max_withdrawal_amount'] ?? maxWithdrawalAmount;
    minWithdrawalAmount = json['min_withdrawal_amount'] ?? minWithdrawalAmount;
    transactionFeePercent = (json['transaction_fee_percent'] ?? transactionFeePercent).toDouble();
    maxWithdrawalRequests = json['max_withdrawal_requests'] ?? maxWithdrawalRequests;
    overheadBalanceRequired = json['overhead_balance_required'] ?? overheadBalanceRequired;

    minCommission = (json['min_commission'] ?? minCommission).toDouble();
    maxCommission = (json['max_commission'] ?? maxCommission).toDouble();

    qrLimitTodayPayIn = (json['qr_limit_today_pay_in'] ?? qrLimitTodayPayIn).toDouble();

    maxWithdrawalAccounts = json['max_withdrawal_accounts'] ?? maxWithdrawalAccounts;
    userCanEditWithdrawalAccounts = json['user_can_edit_withdrawal_accounts'] ?? userCanEditWithdrawalAccounts;
    txnImageSupport = json['txn_image_support'] ?? txnImageSupport;
    manualTxnPageEnabled = json['manual_txn_page_enabled'] ?? manualTxnPageEnabled;

    isLoaded = true;
  }

}
