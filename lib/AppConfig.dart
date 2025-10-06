class AppConfig {
  static final AppConfig _instance = AppConfig._internal();

  factory AppConfig() => _instance;

  AppConfig._internal();

  bool isLoaded = false;
  int defaultMaxWithdrawalRequests = 2;
  int defaultOverheadBalanceRequired = 0;

  double defaultMinCommission = 1.0;
  double defaultMaxCommission = 2.0;

  late int maxWithdrawalAmount;
  late int minWithdrawalAmount;
  late int maxWithdrawalRequests;
  late double transactionFeePercent;
  late int overheadBalanceRequired;

  late double minCommission;
  late double maxCommission;

  void loadFromJson(Map<String, dynamic> json) {
    maxWithdrawalAmount = json['max_withdrawal_amount'] ?? 0;
    minWithdrawalAmount = json['min_withdrawal_amount'] ?? 0;
    transactionFeePercent = (json['transaction_fee_percent'] ?? 0).toDouble();
    maxWithdrawalRequests = json['max_withdrawal_requests'] ?? defaultMaxWithdrawalRequests;
    overheadBalanceRequired = json['overhead_balance_required'] ?? defaultOverheadBalanceRequired;

    minCommission = (json['min_commission'] ?? 0).toDouble() ?? defaultMinCommission;
    maxCommission = (json['max_commission'] ?? 0).toDouble() ?? defaultMaxCommission;

    print("min_commission $minCommission");
    print("max_commission $maxCommission");

    // print("max_withdrawal_amount: $maxWithdrawalAmount");
    // print("min_withdrawal_amount: $minWithdrawalAmount");
    // print("transaction_fee_percent: $transactionFeePercent");
    // print("max_withdrawal_requests: $maxWithdrawalrequests");
    // print("overhead_balance_required: $overheadBalanceRequired");

  }

}
