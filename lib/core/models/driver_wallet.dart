import 'package:hudhud_delivery_driver/core/utils/json_parse.dart';
import 'package:hudhud_delivery_driver/core/models/finance_data_source.dart';

class DriverWallet {
  const DriverWallet({
    this.id,
    this.type,
    this.isActive,
    this.balance,
    this.currency = 'ETB',
    this.totalIncome,
    this.totalExpenses,
    this.heldCollateral,
    this.availableBalance,
    this.source = FinanceDataSource.primary,
    this.sourceMessage,
    this.withdrawalsOnHold = false,
  });

  final int? id;
  final String? type;
  final bool? isActive;
  final double? balance;
  final String currency;
  final double? totalIncome;
  final double? totalExpenses;
  final double? heldCollateral;
  final double? availableBalance;
  final FinanceDataSource source;
  final String? sourceMessage;

  /// Optional `withdrawals_on_hold` flag on GET /wallet (requested from the
  /// API). When absent the app learns about a hold from 423
  /// WITHDRAWALS_ON_HOLD on the cash-out call.
  final bool withdrawalsOnHold;

  static double? _readAmount(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = JsonParse.toDouble(map[key]);
      if (value != null) return value;
    }
    return null;
  }

  static String? _readCurrency(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static DriverWallet? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final data = map['data'] is Map
        ? Map<String, dynamic>.from(map['data'] as Map)
        : map;
    final wallet = data['wallet'] is Map
        ? Map<String, dynamic>.from(data['wallet'] as Map)
        : <String, dynamic>{};

    final balance = _readAmount(wallet, const [
          'balance',
          'current_balance',
          'wallet_balance',
        ]) ??
        _readAmount(data, const [
          'balance',
          'current_balance',
          'wallet_balance',
        ]) ??
        _readAmount(map, const [
          'balance',
          'current_balance',
          'wallet_balance',
        ]);

    final heldCollateral = _readAmount(wallet, const [
          'held_collateral',
          'collateral_held',
        ]) ??
        _readAmount(data, const [
          'held_collateral',
          'collateral_held',
        ]);

    final availableBalance = _readAmount(wallet, const [
          'available_balance',
          'available',
        ]) ??
        _readAmount(data, const [
          'available_balance',
          'available',
        ]);

    final currency = _readCurrency(wallet, const ['currency']) ??
        _readCurrency(data, const ['currency', 'wallet_currency']) ??
        _readCurrency(map, const ['currency', 'wallet_currency']) ??
        'ETB';

    final totalIncome = _readAmount(data, const ['total_income']) ??
        _readAmount(map, const ['total_income']);
    final totalExpenses = _readAmount(data, const ['total_expenses']) ??
        _readAmount(map, const ['total_expenses']);

    return DriverWallet(
      id: JsonParse.toInt(wallet['id']),
      type: wallet['type']?.toString(),
      isActive: wallet.containsKey('is_active')
          ? JsonParse.toBool(wallet['is_active'])
          : null,
      balance: balance,
      currency: currency,
      totalIncome: totalIncome,
      totalExpenses: totalExpenses,
      heldCollateral: heldCollateral,
      availableBalance: availableBalance,
      source: FinanceDataSource.primary,
      withdrawalsOnHold: JsonParse.toBool(
        wallet['withdrawals_on_hold'] ??
            data['withdrawals_on_hold'] ??
            map['withdrawals_on_hold'],
      ),
    );
  }

  DriverWallet copyWith({
    int? id,
    String? type,
    bool? isActive,
    double? balance,
    String? currency,
    double? totalIncome,
    double? totalExpenses,
    double? heldCollateral,
    double? availableBalance,
    FinanceDataSource? source,
    String? sourceMessage,
    bool? withdrawalsOnHold,
  }) {
    return DriverWallet(
      id: id ?? this.id,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      totalIncome: totalIncome ?? this.totalIncome,
      totalExpenses: totalExpenses ?? this.totalExpenses,
      heldCollateral: heldCollateral ?? this.heldCollateral,
      availableBalance: availableBalance ?? this.availableBalance,
      source: source ?? this.source,
      sourceMessage: sourceMessage ?? this.sourceMessage,
      withdrawalsOnHold: withdrawalsOnHold ?? this.withdrawalsOnHold,
    );
  }
}

/// How a wallet row should be presented to the driver.
enum WalletTransactionKind {
  /// COD order: debit of the vendor + platform share of the cash the driver
  /// collected ("Cash collected for order #… (vendor + platform share)").
  /// The driver keeps their own earnings in cash, so this is owed to HudHud.
  codCashCollected,

  /// Prepaid order credit ("Delivery earnings for Order #…") or a COD
  /// subsidy top-up ("Delivery earnings top-up for order #… (COD)").
  deliveryEarnings,

  reward,
  other,
}

class WalletTransaction {
  const WalletTransaction({
    this.id,
    this.amount,
    this.description,
    this.date,
    this.status,
    this.type,
    this.currency = 'ETB',
  });

  final String? id;
  final double? amount;
  final String? description;
  final DateTime? date;
  final String? status;
  final String? type;
  final String currency;

  bool get isDriverWalletReward {
    final combined = '${type ?? ''} ${description ?? ''}'.toLowerCase();
    return combined.contains('driver_wallet_reward') ||
        combined.contains('driver reward') ||
        combined.contains('wallet_reward');
  }

  static final RegExp _orderNumberPattern =
      RegExp(r'#\s*([A-Za-z0-9][A-Za-z0-9_\-]*)');

  /// Ledger direction from the API `type` (`credit` | `debit`).
  bool get isDebit => type?.trim().toLowerCase() == 'debit';

  bool get isCredit => type?.trim().toLowerCase() == 'credit';

  WalletTransactionKind get kind {
    if (isDriverWalletReward) return WalletTransactionKind.reward;
    final text = description?.toLowerCase() ?? '';
    if (text.contains('cash collected for order')) {
      return WalletTransactionKind.codCashCollected;
    }
    if (text.contains('delivery earnings')) {
      return WalletTransactionKind.deliveryEarnings;
    }
    return WalletTransactionKind.other;
  }

  /// Order number referenced in the description (`#ORD-123`), if any.
  String? get orderNumber {
    final value = description;
    if (value == null) return null;
    return _orderNumberPattern.firstMatch(value)?.group(1);
  }

  factory WalletTransaction.fromMap(Map<String, dynamic> map) {
    return WalletTransaction(
      id: map['id']?.toString(),
      amount: JsonParse.toDouble(map['amount']),
      description: map['description']?.toString(),
      date: JsonParse.toDateTime(map['date'] ?? map['created_at']),
      status: map['status']?.toString(),
      type: map['type']?.toString(),
      currency: map['currency']?.toString() ?? 'ETB',
    );
  }

  static List<WalletTransaction> listFromJson(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => WalletTransaction.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (raw is! Map) return const [];
    final map = Map<String, dynamic>.from(raw);

    final data = map['data'];
    if (data is Map) {
      final paginated = Map<String, dynamic>.from(data);
      final nested = paginated['data'];
      if (nested is List) {
        return nested
            .whereType<Map>()
            .map(
              (e) => WalletTransaction.fromMap(Map<String, dynamic>.from(e)),
            )
            .toList();
      }
    }

    for (final key in ['data', 'transactions']) {
      final list = map[key];
      if (list is List) {
        return list
            .whereType<Map>()
            .map(
              (e) => WalletTransaction.fromMap(Map<String, dynamic>.from(e)),
            )
            .toList();
      }
    }
    return const [];
  }
}

class WalletTransactionsPage {
  const WalletTransactionsPage({
    this.transactions = const [],
    this.currentPage = 1,
    this.lastPage = 1,
    this.total = 0,
    this.perPage = 20,
  });

  final List<WalletTransaction> transactions;
  final int currentPage;
  final int lastPage;
  final int total;
  final int perPage;

  static WalletTransactionsPage fromJson(dynamic raw) {
    if (raw is! Map) {
      return WalletTransactionsPage(
        transactions: WalletTransaction.listFromJson(raw),
      );
    }
    final map = Map<String, dynamic>.from(raw);
    final data = map['data'];
    if (data is Map) {
      final paginated = Map<String, dynamic>.from(data);
      return WalletTransactionsPage(
        transactions: WalletTransaction.listFromJson(map),
        currentPage: JsonParse.toInt(paginated['current_page']) ?? 1,
        lastPage: JsonParse.toInt(paginated['last_page']) ?? 1,
        total: JsonParse.toInt(paginated['total']) ?? 0,
        perPage: JsonParse.toInt(paginated['per_page']) ?? 20,
      );
    }
    return WalletTransactionsPage(
      transactions: WalletTransaction.listFromJson(raw),
    );
  }
}
