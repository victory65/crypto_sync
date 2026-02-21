import 'package:flutter/material.dart';

enum SyncStatus { active, delayed, paused }

enum ExecutionStatus { filled, partial, rejected, apiError, disabled, pending }

enum LotSizeMode { fixed, percentage }

enum TradeType { spot, futures }

enum OrderType { market, limit }

enum TradeSide { buy, sell }

enum SubscriptionPlan { free, basic, pro }

class MasterAccount {
  final String id;
  final String exchangeName;
  final String exchangeLogo;
  final double balance;
  final TradeType tradeType;
  final SyncStatus syncStatus;

  const MasterAccount({
    required this.id,
    required this.exchangeName,
    required this.exchangeLogo,
    required this.balance,
    required this.tradeType,
    required this.syncStatus,
  });
}

class SlaveAccount {
  final String id;
  final String exchangeName;
  final String exchangeLogo;
  final double balance;
  final double defaultLotSize;
  final LotSizeMode lotSizeMode;
  final TradeType tradeType;
  final bool syncEnabled;
  final SyncStatus syncStatus;
  final String? attentionReason;

  const SlaveAccount({
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

  SlaveAccount copyWith({
    bool? syncEnabled,
    double? defaultLotSize,
    LotSizeMode? lotSizeMode,
    SyncStatus? syncStatus,
  }) {
    return SlaveAccount(
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

class Position {
  final String id;
  final String assetPair;
  final double masterSize;
  final double entryPrice;
  final double currentPrice;
  final TradeSide side;
  final int totalSlaves;
  final int syncedSlaves;
  final int failedSlaves;
  final List<SlavePosition> slavePositions;

  const Position({
    required this.id,
    required this.assetPair,
    required this.masterSize,
    required this.entryPrice,
    required this.currentPrice,
    required this.side,
    required this.totalSlaves,
    required this.syncedSlaves,
    required this.failedSlaves,
    required this.slavePositions,
  });

  double get pnl =>
      (currentPrice - entryPrice) * masterSize * (side == TradeSide.buy ? 1 : -1);

  double get pnlPercent => (pnl / (entryPrice * masterSize)) * 100;
}

class SlavePosition {
  final String slaveId;
  final String exchangeName;
  final double lotSizeUsed;
  final ExecutionStatus status;
  final String? errorReason;

  const SlavePosition({
    required this.slaveId,
    required this.exchangeName,
    required this.lotSizeUsed,
    required this.status,
    this.errorReason,
  });
}

class TradeAlert {
  final String message;
  final Color color;
  final IconData icon;

  const TradeAlert({
    required this.message,
    required this.color,
    required this.icon,
  });
}

class MockData {
  static final MasterAccount masterAccount = MasterAccount(
    id: 'master_1',
    exchangeName: 'Binance',
    exchangeLogo: '₿',
    balance: 120000.00,
    tradeType: TradeType.futures,
    syncStatus: SyncStatus.active,
  );

  static final List<SlaveAccount> slaveAccounts = [
    const SlaveAccount(
      id: 'slave_1',
      exchangeName: 'Bybit',
      exchangeLogo: 'B',
      balance: 18500.00,
      defaultLotSize: 0.05,
      lotSizeMode: LotSizeMode.fixed,
      tradeType: TradeType.futures,
      syncEnabled: true,
      syncStatus: SyncStatus.active,
    ),
    const SlaveAccount(
      id: 'slave_2',
      exchangeName: 'OKX',
      exchangeLogo: 'O',
      balance: 24300.00,
      defaultLotSize: 15.0,
      lotSizeMode: LotSizeMode.percentage,
      tradeType: TradeType.futures,
      syncEnabled: true,
      syncStatus: SyncStatus.active,
    ),
    const SlaveAccount(
      id: 'slave_3',
      exchangeName: 'Kraken',
      exchangeLogo: 'K',
      balance: 8900.00,
      defaultLotSize: 0.02,
      lotSizeMode: LotSizeMode.fixed,
      tradeType: TradeType.spot,
      syncEnabled: true,
      syncStatus: SyncStatus.delayed,
      attentionReason: 'API rate limit reached',
    ),
    const SlaveAccount(
      id: 'slave_4',
      exchangeName: 'Coinbase',
      exchangeLogo: 'C',
      balance: 5200.00,
      defaultLotSize: 0.01,
      lotSizeMode: LotSizeMode.fixed,
      tradeType: TradeType.spot,
      syncEnabled: false,
      syncStatus: SyncStatus.paused,
    ),
    const SlaveAccount(
      id: 'slave_5',
      exchangeName: 'KuCoin',
      exchangeLogo: 'K',
      balance: 12430.00,
      defaultLotSize: 10.0,
      lotSizeMode: LotSizeMode.percentage,
      tradeType: TradeType.futures,
      syncEnabled: true,
      syncStatus: SyncStatus.active,
    ),
  ];

  static final List<Position> positions = [
    Position(
      id: 'pos_1',
      assetPair: 'BTC/USDT',
      masterSize: 0.5,
      entryPrice: 42100.00,
      currentPrice: 43850.00,
      side: TradeSide.buy,
      totalSlaves: 5,
      syncedSlaves: 4,
      failedSlaves: 1,
      slavePositions: [
        const SlavePosition(
          slaveId: 'slave_1',
          exchangeName: 'Bybit',
          lotSizeUsed: 0.05,
          status: ExecutionStatus.filled,
        ),
        const SlavePosition(
          slaveId: 'slave_2',
          exchangeName: 'OKX',
          lotSizeUsed: 0.037,
          status: ExecutionStatus.filled,
        ),
        const SlavePosition(
          slaveId: 'slave_3',
          exchangeName: 'Kraken',
          lotSizeUsed: 0.02,
          status: ExecutionStatus.partial,
          errorReason: 'Partial fill - insufficient liquidity',
        ),
        const SlavePosition(
          slaveId: 'slave_4',
          exchangeName: 'Coinbase',
          lotSizeUsed: 0.0,
          status: ExecutionStatus.disabled,
          errorReason: 'Sync disabled by user',
        ),
        const SlavePosition(
          slaveId: 'slave_5',
          exchangeName: 'KuCoin',
          lotSizeUsed: 0.015,
          status: ExecutionStatus.filled,
        ),
      ],
    ),
    Position(
      id: 'pos_2',
      assetPair: 'ETH/USDT',
      masterSize: 2.0,
      entryPrice: 2240.00,
      currentPrice: 2190.00,
      side: TradeSide.buy,
      totalSlaves: 5,
      syncedSlaves: 3,
      failedSlaves: 2,
      slavePositions: [
        const SlavePosition(
          slaveId: 'slave_1',
          exchangeName: 'Bybit',
          lotSizeUsed: 0.1,
          status: ExecutionStatus.filled,
        ),
        const SlavePosition(
          slaveId: 'slave_2',
          exchangeName: 'OKX',
          lotSizeUsed: 0.075,
          status: ExecutionStatus.filled,
        ),
        const SlavePosition(
          slaveId: 'slave_3',
          exchangeName: 'Kraken',
          lotSizeUsed: 0.0,
          status: ExecutionStatus.rejected,
          errorReason: 'Insufficient balance',
        ),
        const SlavePosition(
          slaveId: 'slave_4',
          exchangeName: 'Coinbase',
          lotSizeUsed: 0.0,
          status: ExecutionStatus.disabled,
        ),
        const SlavePosition(
          slaveId: 'slave_5',
          exchangeName: 'KuCoin',
          lotSizeUsed: 0.05,
          status: ExecutionStatus.filled,
        ),
      ],
    ),
    Position(
      id: 'pos_3',
      assetPair: 'SOL/USDT',
      masterSize: 10.0,
      entryPrice: 98.50,
      currentPrice: 105.20,
      side: TradeSide.buy,
      totalSlaves: 5,
      syncedSlaves: 5,
      failedSlaves: 0,
      slavePositions: [
        const SlavePosition(
          slaveId: 'slave_1',
          exchangeName: 'Bybit',
          lotSizeUsed: 1.0,
          status: ExecutionStatus.filled,
        ),
        const SlavePosition(
          slaveId: 'slave_2',
          exchangeName: 'OKX',
          lotSizeUsed: 0.8,
          status: ExecutionStatus.filled,
        ),
        const SlavePosition(
          slaveId: 'slave_3',
          exchangeName: 'Kraken',
          lotSizeUsed: 0.5,
          status: ExecutionStatus.filled,
        ),
        const SlavePosition(
          slaveId: 'slave_4',
          exchangeName: 'Coinbase',
          lotSizeUsed: 0.0,
          status: ExecutionStatus.disabled,
        ),
        const SlavePosition(
          slaveId: 'slave_5',
          exchangeName: 'KuCoin',
          lotSizeUsed: 0.6,
          status: ExecutionStatus.filled,
        ),
      ],
    ),
  ];

  static final List<Map<String, double>> chartData7d = [
    {'x': 0, 'y': 238000},
    {'x': 1, 'y': 241500},
    {'x': 2, 'y': 239200},
    {'x': 3, 'y': 244100},
    {'x': 4, 'y': 246800},
    {'x': 5, 'y': 243900},
    {'x': 6, 'y': 248430},
  ];

  static final List<Map<String, double>> chartData24h = [
    {'x': 0, 'y': 245100},
    {'x': 1, 'y': 246200},
    {'x': 2, 'y': 244800},
    {'x': 3, 'y': 247300},
    {'x': 4, 'y': 246900},
    {'x': 5, 'y': 248100},
    {'x': 6, 'y': 248430},
  ];

  static final List<Map<String, double>> chartData30d = [
    {'x': 0, 'y': 220000},
    {'x': 5, 'y': 225000},
    {'x': 10, 'y': 218000},
    {'x': 15, 'y': 232000},
    {'x': 20, 'y': 238000},
    {'x': 25, 'y': 245000},
    {'x': 30, 'y': 248430},
  ];

  static const double totalCombinedBalance = 248430.21;
  static const double masterBalance = 120000.00;
  static const double slavesBalance = 128430.21;
  static const double portfolioChange24h = 2.3;
  static const SyncStatus globalSyncStatus = SyncStatus.active;

  static const List<String> exchanges = [
    'Binance',
    'Bybit',
    'OKX',
    'Kraken',
    'Coinbase',
    'KuCoin',
    'Bitget',
    'MEXC',
    'Gate.io',
  ];

  static const List<String> assetPairs = [
    'BTC/USDT',
    'ETH/USDT',
    'SOL/USDT',
    'BNB/USDT',
    'XRP/USDT',
    'DOGE/USDT',
    'ADA/USDT',
    'AVAX/USDT',
    'MATIC/USDT',
    'DOT/USDT',
  ];
}
