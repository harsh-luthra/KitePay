import 'package:flutter/material.dart';

class ApiMerchant {
  /// Appwrite document ID
  final String? id;

  /// Unique merchant identifier (mid_ABC123)
  final String? merchantId;

  /// Hashed API secret (bcrypt)
  final String? apiSecret;

  /// Assigned UPI VPA (midabc@razorpay)
  final String? vpa;

  /// Business name
  final String name;

  /// Account status (true=active, false=suspended)
  final bool status;

  /// Contact email
  final String email;

  /// Daily QR generation limit (0-99999)
  final int dailyLimit;

  /// Failed login attempts counter
  final int? failedAttempts;

  /// Comma-separated IP whitelist (192.168.1.1,10.0.0.1)
  final String? ipWhitelist;

  /// Appwrite creation timestamp
  final String? createdAt;

  /// Appwrite last update timestamp
  final String? updatedAt;

  ApiMerchant({
    this.id,
    this.merchantId,
    this.apiSecret,
    this.vpa,
    required this.name,
    required this.status,
    required this.email,
    required this.dailyLimit,
    this.failedAttempts,
    this.ipWhitelist,
    this.createdAt,
    this.updatedAt,
  });

  /// Create from Appwrite JSON response
  factory ApiMerchant.fromJson(Map<String, dynamic> json) => ApiMerchant(
    id: json['\$id'],
    merchantId: json['merchantId'] ?? '',
    apiSecret: json['apiSecret'] ?? '',
    vpa: json['vpa'],
    name: json['name'] ?? '',
    status: json['status'] ?? false,
    email: json['email'] ?? '',
    dailyLimit: json['dailyLimit'] ?? 0,
    failedAttempts: json['failedAttempts'],
    ipWhitelist: json['ipWhitelist'],
    createdAt: json['\$createdAt'],
    updatedAt: json['\$updatedAt'],
  );

  /// Convert to JSON for API requests (excludes secrets/system fields)
  Map<String, dynamic> toJson() => {
    'merchantId': merchantId,
    'name': name,
    'email': email,
    'vpa': vpa,
    'status': status,
    'dailyLimit': dailyLimit,
    if (failedAttempts != null) 'failed_attempts': failedAttempts,
    if (ipWhitelist != null) 'ip_whitelist': ipWhitelist,
  };

  /// Status display text
  String get statusText => status ? 'Active' : 'Suspended';

  /// Status color for UI
  Color get statusColor {
    switch (statusText.toLowerCase()) {
      case 'active': return Colors.green.shade500;
      case 'suspended': return Colors.red.shade500;
      default: return Colors.grey.shade600;
    }
  }

  /// IP list as comma-separated (formatted)
  List<String> get ipList => ipWhitelist?.split(',')?.map((s) => s.trim()).where((s) => s.isNotEmpty).toList() ?? [];

  /// Daily limit display
  String get dailyLimitDisplay => dailyLimit == 0 ? 'Unlimited' : '$dailyLimit/day';

  /// Failed attempts warning
  bool get isLockedOut => failedAttempts != null && failedAttempts! >= 5;

  /// Copy with updated values (immutable updates)
  ApiMerchant copyWith({
    String? merchantId,
    String? apiSecret,
    String? vpa,
    String? name,
    bool? status,
    String? email,
    int? dailyLimit,
    int? failedAttempts,
    String? ipWhitelist,
  }) {
    return ApiMerchant(
      id: id,
      merchantId: merchantId ?? this.merchantId,
      apiSecret: apiSecret ?? this.apiSecret,
      vpa: vpa ?? this.vpa,
      name: name ?? this.name,
      status: status ?? this.status,
      email: email ?? this.email,
      dailyLimit: dailyLimit ?? this.dailyLimit,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      ipWhitelist: ipWhitelist ?? this.ipWhitelist,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  String toString() => 'ApiMerchant(id: $id, merchantId: $merchantId, name: $name, status: $status, vpa: $vpa)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ApiMerchant && other.id == id && other.merchantId == merchantId;
  }

  @override
  int get hashCode => id.hashCode ^ merchantId.hashCode;
}
