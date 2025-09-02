class AppConfig {
  static final AppConfig _instance = AppConfig._internal();

  factory AppConfig() => _instance;

  AppConfig._internal();

  bool isLoaded = false;
  late int maxWithdrawalAmount;
  late int minWithdrawalAmount;
  late int maxWithdrawalrequests;
  late double transactionFeePercent;

  void loadFromJson(Map<String, dynamic> json) {
    maxWithdrawalAmount = json['max_withdrawal_amount'] ?? 0;
    minWithdrawalAmount = json['min_withdrawal_amount'] ?? 0;
    transactionFeePercent = (json['transaction_fee_percent'] ?? 0).toDouble();
    maxWithdrawalrequests = json['max_withdrawal_requests'] ?? 2;
    // print("max_withdrawal_amount: $maxWithdrawalAmount");
    // print("min_withdrawal_amount: $minWithdrawalAmount");
    // print("transaction_fee_percent: $transactionFeePercent");
    print("max_withdrawal_requests: $maxWithdrawalrequests");
  }
}
