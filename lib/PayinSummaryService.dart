import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'AppConstants.dart';

class PayinSummaryService {
  static final String _baseUrl = AppConstants.baseApiUrl;

  static Future<PayinSummaryResult> fetchPayinSummary({
    DateTime? from,
    DateTime? to,
    String? userId,
    String? qrId,
    required String jwtToken,
  }) async {
    final qp = <String, String>{};

    if (from != null) qp['from'] = from.ymd;
    if (to != null) qp['to'] = to.ymd;
    if (userId != null) qp['userId'] = userId;
    if (qrId != null) qp['qrId'] = qrId;

    final uri = Uri.parse('$_baseUrl/admin/payin-summary').replace(queryParameters: qp);
    final resp = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $jwtToken',
        'Content-Type': 'application/json',
      },
    ).timeout(const Duration(seconds: 10));

    if (resp.statusCode == 200) {
      final body = json.decode(resp.body) as Map<String, dynamic>;
      return PayinSummaryResult.fromJson(body);
    }
    throw Exception('Failed to fetch payin summary: ${resp.body}');
  }
}

extension _DateFmt on DateTime {
  String get ymd {
    final m = month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    return '$year-$m-$d';
  }
}

class PayinSummaryDay {
  final String date;
  final int totalPaise;
  final double totalRs;
  final Map<String, int> qrs; // qrId -> paise

  PayinSummaryDay({
    required this.date,
    required this.totalPaise,
    required this.totalRs,
    required this.qrs,
  });

  factory PayinSummaryDay.fromJson(Map<String, dynamic> j) {
    final qrsRaw = (j['qrs'] as Map<String, dynamic>?) ?? {};
    final qrs = <String, int>{};
    qrsRaw.forEach((k, v) => qrs[k] = (v as num).toInt());

    return PayinSummaryDay(
      date: j['date'] as String,
      totalPaise: (j['totalPaise'] as num).toInt(),
      totalRs: (j['totalRs'] as num).toDouble(),
      qrs: qrs,
    );
  }
}

class PayinSummaryResult {
  final List<PayinSummaryDay> days;
  final int grandTotalPaise;
  final double grandTotalRs;
  final int todayPaise;
  final double todayRs;
  final int yesterdayPaise;
  final double yesterdayRs;

  PayinSummaryResult({
    required this.days,
    required this.grandTotalPaise,
    required this.grandTotalRs,
    required this.todayPaise,
    required this.todayRs,
    required this.yesterdayPaise,
    required this.yesterdayRs,
  });

  factory PayinSummaryResult.fromJson(Map<String, dynamic> j) {
    final daysList = (j['days'] as List? ?? [])
        .map((e) => PayinSummaryDay.fromJson(e as Map<String, dynamic>))
        .toList();

    return PayinSummaryResult(
      days: daysList,
      grandTotalPaise: (j['grandTotalPaise'] as num).toInt(),
      grandTotalRs: (j['grandTotalRs'] as num).toDouble(),
      todayPaise: (j['todayPaise'] as num).toInt(),
      todayRs: (j['todayRs'] as num).toDouble(),
      yesterdayPaise: (j['yesterdayPaise'] as num).toInt(),
      yesterdayRs: (j['yesterdayRs'] as num).toDouble(),
    );
  }
}
