import 'package:flutter/material.dart';

enum TradeType { spot, futures, both }
enum OrderType { market, limit }
enum TradeSide { buy, sell }
enum LotSizeMode { fixed, percentage }
enum ExecutionStatus { filled, partial, rejected, apiError, disabled, pending }

class Position {
  final String id;
  final String assetPair;
  final double masterSize;
  final double entryPrice;
  final double currentPrice;
  final TradeSide side;
  final int totalInvestors;
  final int syncedInvestors;
  final int failedInvestors;
  final List<InvestorPosition> investorPositions;

  const Position({
    required this.id,
    required this.assetPair,
    required this.masterSize,
    required this.entryPrice,
    required this.currentPrice,
    required this.side,
    required this.totalInvestors,
    required this.syncedInvestors,
    required this.failedInvestors,
    required this.investorPositions,
  });

  double get pnl =>
      (currentPrice - entryPrice) * masterSize * (side == TradeSide.buy ? 1 : -1);

  double get pnlPercent => (pnl / (entryPrice * masterSize)) * 100;
}

class InvestorPosition {
  final String investorId;
  final String exchangeName;
  final double lotSizeUsed;
  final ExecutionStatus status;
  final String? errorReason;

  const InvestorPosition({
    required this.investorId,
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

