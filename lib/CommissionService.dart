import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'AppConstants.dart';
import 'models/Commission.dart';

class CommissionService {
  static final String _baseUrl = AppConstants.baseApiUrl;

  static String _formatDate(DateTime d) {
    // YYYY-MM-DD
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  // GET /admin/commissions
  static Future<PaginatedCommissions> fetchCommissions({
    String? userId,
    String? earningType,           // 'admin' | 'subadmin'
    String? sourceWithdrawalId,
    int? minAmount,                // paise
    int? maxAmount,                // paise
    DateTime? from,                // IST day string sent as YYYY-MM-DD, server maps to IST range
    DateTime? to,
    String? cursor,
    int limit = 25,
    String? searchField,           // 'userId' | 'sourceWithdrawalId'
    String? searchValue,
    required String jwtToken,
  }) async {
    try {
      String url = '$_baseUrl/admin/commissions';
      final qp = <String, String>{ 'limit': limit.toString() };

      if (userId != null) qp['userId'] = userId;
      if (earningType != null) qp['earningType'] = earningType; // 'admin'/'subadmin'
      if (sourceWithdrawalId != null) qp['sourceWithdrawalId'] = sourceWithdrawalId;

      if (minAmount != null) qp['minAmount'] = minAmount.toString();
      if (maxAmount != null) qp['maxAmount'] = maxAmount.toString();

      if (from != null) qp['from'] = _formatDate(from);
      if (to != null) qp['to'] = _formatDate(to);

      if (cursor != null) qp['cursor'] = cursor;

      if (searchField != null && searchValue != null) {
        qp['searchField'] = searchField;
        qp['searchValue'] = searchValue;
      }

      url += '?' + Uri(queryParameters: qp).query;

      final resp = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        final List list = (body['commissions'] as List? ?? []);
        final nextCursor = body['nextCursor'] as String?;

        return PaginatedCommissions(
          commissions: list.map((e) => Commission.fromJson(e as Map<String, dynamic>)).toList(),
          nextCursor: nextCursor,
        );
      } else {
        throw Exception('Failed to load commissions: ${resp.body}');
      }
    } on TimeoutException {
      throw Exception('Request timed out. Please check connection.');
    } catch (e) {
      print('Error fetching commissions: $e');
      return PaginatedCommissions(commissions: [], nextCursor: null);
    }
  }

  static Future<CommissionSummaryResult> fetchCommissionSummary({
    required String userId,
    String mode = 'today',           // today | date | range | last
    DateTime? date,                  // for mode=date
    DateTime? start,                 // for mode=range
    DateTime? end,                   // for mode=range
    int days = 7,                    // for mode=last
    required String jwtToken,
  }) async {
    try {
      final qp = <String, String>{
        'userId': userId,
        'mode': mode,
      };

      switch (mode) {
        case 'today':
          break;
        case 'date':
          if (date == null) throw Exception('date is required for mode=date');
          qp['date'] = date.ymd;
          break;
        case 'range':
          if (start == null || end == null) {
            throw Exception('start and end are required for mode=range');
          }
          qp['start'] = start.ymd;
          qp['end'] = end.ymd;
          break;
        case 'last':
          qp['days'] = days.toString();
          break;
        default:
          throw Exception('Invalid mode');
      }

      final url = '$_baseUrl/admin/commissions/summary?${Uri(queryParameters: qp).query}';

      final resp = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 6));

      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        if ((body['success'] as bool?) != true) {
          throw Exception(body['message']?.toString() ?? 'Unknown API error');
        }
        return CommissionSummaryResult.fromJson(body);
      } else {
        throw Exception('Failed: ${resp.statusCode} ${resp.body}');
      }
    } on TimeoutException {
      throw Exception('Request timed out. Please check connection.');
    } catch (e) {
      rethrow;
    }
  }

// CommissionService.dart
  static Future<AllSummaryResult> fetchCommissionSummaryAll({
    required String mode,        // 'today' | 'date' | 'range' | 'last'
    DateTime? date,              // for 'date'
    DateTime? start,             // for 'range'
    DateTime? end,               // for 'range'
    int days = 7,                // for 'last'
    required String jwtToken,
  }) async {
    final qp = <String, String>{ 'mode': mode, 'includeUsers': 'true' };
    // add date/start/end/days as before, then call URL with qp

    String _ymd(DateTime d) {
      final m = d.month.toString().padLeft(2, '0');
      final day = d.day.toString().padLeft(2, '0');
      return '${d.year}-$m-$day';
    }

    switch (mode) {
      case 'today':
        break;
      case 'date':
        if (date == null) { throw Exception('date is required for mode=date'); }
        qp['date'] = _ymd(date);
        break;
      case 'range':
        if (start == null || end == null) { throw Exception('start/end required for mode=range'); }
        qp['start'] = _ymd(start);
        qp['end'] = _ymd(end);
        break;
      case 'last':
        qp['days'] = days.toString();
        break;
      default:
        throw Exception('Invalid mode');
    }

    final url = '$_baseUrl/admin/commissions/summary-all?${Uri(queryParameters: qp).query}';
    final resp = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $jwtToken',
        'Content-Type': 'application/json',
      },
    ).timeout(const Duration(seconds: 6));

    if (resp.statusCode == 200) {
      // print('ALL resp: ${resp.body}');
      final body = json.decode(resp.body) as Map<String, dynamic>;
      if ((body['success'] as bool?) != true) {
        throw Exception(body['message']?.toString() ?? 'Unknown API error');
      }
      return AllSummaryResult.fromJson(body);
    }
    throw Exception('Failed: ${resp.statusCode} ${resp.body}');
  }

  static Future<TodayPerUser> fetchTodayPerUserCommissions({
    required String jwtToken,
  }) async {
    final qp = {
      'mode': 'today',
      'includeUsers': 'true',
    };
    final url = '$_baseUrl/admin/commissions/summary-all?${Uri(queryParameters: qp).query}';
    final resp = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $jwtToken',
        'Content-Type': 'application/json',
      },
    ).timeout(const Duration(seconds: 6));

    if (resp.statusCode != 200) {
      throw Exception('Failed: ${resp.statusCode} ${resp.body}');
    }
    final body = json.decode(resp.body) as Map<String, dynamic>;
    if ((body['success'] as bool?) != true) {
      throw Exception(body['message']?.toString() ?? 'Unknown API error');
    }

    final range = (body['range'] as Map<String, dynamic>? ?? const {});
    final date = (range['start'] ?? '') as String;
    final perUser = (body['perUser'] as Map<String, dynamic>? ?? const {});
    final map = <String, int>{};
    perUser.forEach((uid, v) {
      final total = ((v as Map<String, dynamic>)['totalPaise'] as num?)?.toInt() ?? 0;
      map[uid] = total;
    });
    return TodayPerUser(date: date, paiseByUser: map);
  }

}

extension _DateFmt on DateTime {
  String get ymd {
    final m = month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    return '$year-$m-$d';
  }
}

class CommissionSummaryDay {
  final String date;           // YYYY-MM-DD (IST)
  final int commissionPaise;   // amount in paise

  CommissionSummaryDay({required this.date, required this.commissionPaise});

  factory CommissionSummaryDay.fromJson(Map<String, dynamic> j) =>
      CommissionSummaryDay(
        date: j['date'] as String,
        commissionPaise: (j['commissionPaise'] as num).toInt(),
    );

  @override
  String toString() {
    return 'CommissionSummaryDay{date: $date, commissionPaise: $commissionPaise}';
  }

}

class CommissionSummaryResult {
  final String userId;
  final String start;          // YYYY-MM-DD
  final String end;            // YYYY-MM-DD
  final int totalPaise;        // sum across days
  final List<CommissionSummaryDay> days;

  CommissionSummaryResult({
    required this.userId,
    required this.start,
    required this.end,
    required this.totalPaise,
    required this.days,
  });

  factory CommissionSummaryResult.fromJson(Map<String, dynamic> j) {
    final range = j['range'] as Map<String, dynamic>;
    final list = (j['days'] as List? ?? [])
        .map((e) => CommissionSummaryDay.fromJson(e as Map<String, dynamic>))
        .toList();
    return CommissionSummaryResult(
      userId: j['userId'] as String,
      start: range['start'] as String,
      end: range['end'] as String,
      totalPaise: (j['totalPaise'] as num).toInt(),
      days: list,
    );
  }

  @override
  String toString() {
    return 'CommissionSummaryResult{userId: $userId, start: $start, end: $end, totalPaise: $totalPaise, days: $days}';
  }

}

class AllDayBucket {
  final String date;
  final int totalPaise;
  AllDayBucket({required this.date, required this.totalPaise});
  factory AllDayBucket.fromJson(Map<String, dynamic> j) => AllDayBucket(
    date: (j['date'] ?? '') as String,
    totalPaise: ((j['totalPaise'] as num?)?.toInt()) ?? 0,
  );
}

class AllUserDay {
  final String date;
  final int paise;
  AllUserDay({required this.date, required this.paise});
  factory AllUserDay.fromJson(Map<String, dynamic> j) => AllUserDay(
    date: (j['date'] ?? '') as String,
    paise: ((j['paise'] as num?)?.toInt()) ?? 0,
  );
}

class AllUserSeries {
  final int totalPaise;
  final List<AllUserDay> days;
  AllUserSeries({required this.totalPaise, required this.days});
  factory AllUserSeries.fromJson(Map<String, dynamic> j) => AllUserSeries(
    totalPaise: ((j['totalPaise'] as num?)?.toInt()) ?? 0,
    days: (j['days'] as List? ?? const []).map((e) => AllUserDay.fromJson(e as Map<String, dynamic>)).toList(),
  );
}

class AllSummaryResult {
  final String start;
  final String end;
  final int totalPaise;
  final List<AllDayBucket> days;
  final Map<String, AllUserSeries> perUser;
  AllSummaryResult({
    required this.start, required this.end, required this.totalPaise,
    required this.days, required this.perUser,
  });
  factory AllSummaryResult.fromJson(Map<String, dynamic> j) {
    final r = (j['range'] as Map<String, dynamic>? ?? const {});
    final list = (j['days'] as List? ?? const []).map((e) => AllDayBucket.fromJson(e as Map<String, dynamic>)).toList();
    final puRaw = (j['perUser'] as Map<String, dynamic>?) ?? const {};
    final pu = <String, AllUserSeries>{};
    puRaw.forEach((k, v) => pu[k] = AllUserSeries.fromJson(v as Map<String, dynamic>));
    return AllSummaryResult(
      start: (r['start'] ?? '') as String,
      end: (r['end'] ?? '') as String,
      totalPaise: ((j['totalPaise'] as num?)?.toInt()) ?? 0,
      days: list,
      perUser: pu,
    );
  }
}

class TodayPerUser {
  final String date; // YYYY-MM-DD
  final Map<String, int> paiseByUser; // userId -> paise
  TodayPerUser({required this.date, required this.paiseByUser});
}


