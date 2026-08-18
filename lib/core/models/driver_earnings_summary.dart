import 'package:hudhud_delivery_driver/core/utils/json_parse.dart';

class DriverEarningsSummary {
  const DriverEarningsSummary({
    this.totalEarnings,
    this.ridesEarnings,
    this.deliveriesEarnings,
    this.totalServices,
    this.averageEarningsPerService,
    this.platformCommission,
    this.netDriverEarnings,
    this.weeklyEarnings,
    this.currentBalance,
    this.currency = 'ETB',
  });

  final double? totalEarnings;
  final double? ridesEarnings;
  final double? deliveriesEarnings;
  final int? totalServices;
  final double? averageEarningsPerService;
  final double? platformCommission;
  final double? netDriverEarnings;
  final double? weeklyEarnings;
  final double? currentBalance;
  final String currency;

  static DriverEarningsSummary? fromStatsJson(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final data = map['data'] is Map
        ? Map<String, dynamic>.from(map['data'] as Map)
        : map;

    return DriverEarningsSummary(
      totalEarnings: JsonParse.toDouble(
        data['total_earnings'] ?? data['total'],
      ),
      ridesEarnings: JsonParse.toDouble(data['rides_earnings']),
      deliveriesEarnings: JsonParse.toDouble(data['deliveries_earnings']),
      totalServices: JsonParse.toInt(data['total_services']),
      averageEarningsPerService:
          JsonParse.toDouble(data['average_earnings_per_service']),
      platformCommission: JsonParse.toDouble(data['platform_commission']),
      netDriverEarnings: JsonParse.toDouble(data['net_driver_earnings']),
      weeklyEarnings: JsonParse.toDouble(data['weekly_earnings']),
      currentBalance: JsonParse.toDouble(data['current_balance']),
      currency: data['currency']?.toString() ?? 'ETB',
    );
  }

  static DriverEarningsSummary? fromLegacyJson(Map<String, dynamic> data) {
    return DriverEarningsSummary(
      totalEarnings: JsonParse.toDouble(data['total_earnings']),
      weeklyEarnings: JsonParse.toDouble(data['weekly_earnings']),
      currentBalance: JsonParse.toDouble(data['current_balance']),
      currency: data['currency']?.toString() ?? 'ETB',
    );
  }
}

class WeeklyEarningsSummary {
  const WeeklyEarningsSummary({
    this.weekStart,
    this.weekEnd,
    this.totalEarnings,
    this.deliveriesEarnings,
    this.ridesEarnings,
    this.deliveryCount,
    this.rideCount,
    this.platformCommission,
    this.netEarnings,
    this.currency = 'ETB',
    this.dailyBreakdown = const [],
  });

  final DateTime? weekStart;
  final DateTime? weekEnd;
  final double? totalEarnings;
  final double? deliveriesEarnings;
  final double? ridesEarnings;
  final int? deliveryCount;
  final int? rideCount;
  final double? platformCommission;
  final double? netEarnings;
  final String currency;
  final List<DailyEarningsEntry> dailyBreakdown;

  static WeeklyEarningsSummary? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final data = map['data'] is Map
        ? Map<String, dynamic>.from(map['data'] as Map)
        : map;

    final daily = data['daily_breakdown'] ?? data['days'];
    final dailyList = daily is List
        ? daily
            .whereType<Map>()
            .map(
              (e) => DailyEarningsEntry.fromMap(
                Map<String, dynamic>.from(e),
              ),
            )
            .toList()
        : <DailyEarningsEntry>[];

    return WeeklyEarningsSummary(
      weekStart: JsonParse.toDateTime(data['week_start'] ?? data['from']),
      weekEnd: JsonParse.toDateTime(data['week_end'] ?? data['to']),
      totalEarnings: JsonParse.toDouble(data['total_earnings'] ?? data['total']),
      deliveriesEarnings: JsonParse.toDouble(data['deliveries_earnings']),
      ridesEarnings: JsonParse.toDouble(data['rides_earnings']),
      deliveryCount: JsonParse.toInt(data['delivery_count']),
      rideCount: JsonParse.toInt(data['ride_count']),
      platformCommission: JsonParse.toDouble(data['platform_commission']),
      netEarnings: JsonParse.toDouble(data['net_earnings']),
      currency: data['currency']?.toString() ?? 'ETB',
      dailyBreakdown: dailyList,
    );
  }
}

class DailyEarningsEntry {
  const DailyEarningsEntry({
    this.date,
    this.earnings,
    this.deliveryCount,
    this.rideCount,
  });

  final DateTime? date;
  final double? earnings;
  final int? deliveryCount;
  final int? rideCount;

  factory DailyEarningsEntry.fromMap(Map<String, dynamic> map) {
    return DailyEarningsEntry(
      date: JsonParse.toDateTime(map['date']),
      earnings: JsonParse.toDouble(map['earnings'] ?? map['total']),
      deliveryCount: JsonParse.toInt(map['delivery_count']),
      rideCount: JsonParse.toInt(map['ride_count']),
    );
  }
}

class DeliveryEarningBreakdown {
  const DeliveryEarningBreakdown({
    this.customerTotal,
    this.platformCommission,
    this.driverGrossEarning,
    this.adjustments,
    this.driverNetEarning,
    this.currency = 'ETB',
  });

  final double? customerTotal;
  final double? platformCommission;
  final double? driverGrossEarning;
  final double? adjustments;
  final double? driverNetEarning;
  final String currency;

  static DeliveryEarningBreakdown? fromDelivery(Map<String, dynamic> delivery) {
    final raw = delivery['earning_breakdown'] ??
        delivery['driver_earning'] ??
        delivery['financial'];
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    return DeliveryEarningBreakdown(
      customerTotal: JsonParse.toDouble(
        map['customer_total'] ?? map['customer_amount'],
      ),
      platformCommission: JsonParse.toDouble(map['platform_commission']),
      driverGrossEarning: JsonParse.toDouble(
        map['driver_gross_earning'] ?? map['gross_earning'],
      ),
      adjustments: JsonParse.toDouble(map['adjustments']),
      driverNetEarning: JsonParse.toDouble(
        map['driver_net_earning'] ?? map['net_earning'],
      ),
      currency: map['currency']?.toString() ?? 'ETB',
    );
  }
}
