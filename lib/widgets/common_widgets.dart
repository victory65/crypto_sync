import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;
  final double borderRadius;
  final Border? border;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
    this.borderRadius = 16,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color ?? AppColors.card,
          borderRadius: BorderRadius.circular(borderRadius),
          border: border,
        ),
        child: child,
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool small;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 8,
        vertical: small ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: small ? 10 : 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: small ? 10 : 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class ExchangeAvatar extends StatelessWidget {
  final String exchangeName;
  final String logo;
  final double size;

  const ExchangeAvatar({
    super.key,
    required this.exchangeName,
    required this.logo,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          logo,
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class PnlText extends StatelessWidget {
  final double pnl;
  final double pnlPercent;
  final bool compact;

  const PnlText({
    super.key,
    required this.pnl,
    required this.pnlPercent,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = pnl >= 0;
    final color = isPositive ? AppColors.success : AppColors.danger;
    final sign = isPositive ? '+' : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$sign\$${pnl.abs().toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: compact ? 13 : 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          '$sign${pnlPercent.toStringAsFixed(2)}%',
          style: TextStyle(
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w500,
            color: color.withOpacity(0.8),
          ),
        ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }
}

class AppDivider extends StatelessWidget {
  const AppDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: AppColors.divider,
    );
  }
}

class LoadingOverlay extends StatelessWidget {
  final String? message;
  const LoadingOverlay({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background.withOpacity(0.9),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 2,
            ),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final Color? startColor;
  final Color? endColor;

  const GradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.startColor,
    this.endColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: onPressed == null
                ? [AppColors.textMuted, AppColors.textDisabled]
                : [
                    startColor ?? AppColors.primary,
                    endColor ?? AppColors.primaryDark,
                  ],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
