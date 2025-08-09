class QrCode {
  final String qrId;
  final String fileId;
  final String imageUrl;
  final String? assignedUserId;
  final bool isActive;
  final String? createdAt;

  QrCode({
    required this.qrId,
    required this.fileId,
    required this.imageUrl,
    this.assignedUserId,
    required this.isActive,
    this.createdAt,
  });

  factory QrCode.fromJson(Map<String, dynamic> json) {
    return QrCode(
      qrId: json['qrId'] as String? ?? '',
      fileId: json['fileId'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      assignedUserId: json['assignedUserId'] as String?,
      createdAt: json['createdAt'] as String?,
      isActive: json['isActive'] ?? true,
    );
  }
}