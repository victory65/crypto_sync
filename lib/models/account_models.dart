import 'trade_models.dart';

enum AccountSyncStatus { active, delayed, paused }

class MasterAccount {
  final String id;
  final String exchangeName;
  final String exchangeLogo;
  final double balance;
  final TradeType tradeType;
  final AccountSyncStatus syncStatus;

  const MasterAccount({
    required this.id,
    required this.exchangeName,
    required this.exchangeLogo,
    required this.balance,
    required this.tradeType,
    required this.syncStatus,
  });
}

class InvestorAccount {
  final String id;
  final String exchangeName;
  final String exchangeLogo;
  final double balance;
  final double defaultLotSize;
  final LotSizeMode lotSizeMode;
  final TradeType tradeType;
  final bool syncEnabled;
  final AccountSyncStatus syncStatus;
  final String? attentionReason;

  const InvestorAccount({
    required this.id,
    required this.exchangeName,
    required this.exchangeLogo,
    required this.balance,
    required this.defaultLotSize,
    required this.lotSizeMode,
    required this.tradeType,
    required this.syncEnabled,
    required this.syncStatus,
    this.attentionReason,
  });

  InvestorAccount copyWith({
    bool? syncEnabled,
    double? defaultLotSize,
    LotSizeMode? lotSizeMode,
    AccountSyncStatus? syncStatus,
  }) {
    return InvestorAccount(
      id: id,
      exchangeName: exchangeName,
      exchangeLogo: exchangeLogo,
      balance: balance,
      defaultLotSize: defaultLotSize ?? this.defaultLotSize,
      lotSizeMode: lotSizeMode ?? this.lotSizeMode,
      tradeType: tradeType,
      syncEnabled: syncEnabled ?? this.syncEnabled,
      syncStatus: syncStatus ?? this.syncStatus,
      attentionReason: attentionReason,
    );
  }
}

