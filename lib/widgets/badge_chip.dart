import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

enum BadgeType {
  paid,
  partial,
  unpaid,
  overdue,
  challan,
  bill,
  invoice,
  customer,
  supplier,
  both,
  wholesaler,
  retailer,
  manufacturer,
  material,
  income,
  expense,
  transfer
}

class BadgeChip extends StatelessWidget {
  final String label;
  final BadgeType type;

  const BadgeChip({
    super.key,
    required this.label,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;

    switch (type) {
      case BadgeType.paid:
      case BadgeType.customer:
      case BadgeType.income:
        bg = const Color(0xFFDCFCE7);
        text = const Color(0xFF15803D);
        break;
      case BadgeType.partial:
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFFB45309);
        break;
      case BadgeType.unpaid:
      case BadgeType.overdue:
      case BadgeType.expense:
        bg = const Color(0xFFFEE2E2);
        text = const Color(0xFFB91C1C);
        break;
      case BadgeType.challan:
      case BadgeType.supplier:
      case BadgeType.transfer:
        bg = const Color(0xFFE0F2FE);
        text = const Color(0xFF0369A1);
        break;
      case BadgeType.bill:
      case BadgeType.invoice:
      case BadgeType.both:
        bg = AppColors.goldLight.withValues(alpha: 0.5);
        text = AppColors.goldDark;
        break;
      case BadgeType.wholesaler:
        bg = const Color(0xFFF3E8FF); // Royal light violet
        text = const Color(0xFF7E22CE); // Deep purple
        break;
      case BadgeType.retailer:
        bg = const Color(0xFFE0E7FF); // Indigo soft
        text = const Color(0xFF4338CA); // Indigo
        break;
      case BadgeType.manufacturer:
        bg = const Color(0xFFFEF3C7); // Warm Amber
        text = const Color(0xFFB45309); // Amber-brown
        break;
      case BadgeType.material:
        bg = const Color(0xFFCCFBF1); // Mint Teal
        text = const Color(0xFF0F766E); // Deep Teal
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: text.withValues(alpha: 0.25), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: text,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}
