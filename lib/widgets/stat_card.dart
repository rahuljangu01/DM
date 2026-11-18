import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String amount;
  final IconData icon;
  final Color iconColor;
  final Color? cardColor;
  final VoidCallback? onTap;
  final String? secondaryInfo;
  final bool isNegativeAlert;

  const StatCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.amount,
    required this.icon,
    this.iconColor = AppColors.primaryNavy,
    this.cardColor,
    this.onTap,
    this.secondaryInfo,
    this.isNegativeAlert = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: cardColor ?? AppColors.surfaceWhite,
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isNegativeAlert ? AppColors.payableRed.withValues(alpha: 0.3) : AppColors.borderLight,
          width: isNegativeAlert ? 1.2 : 0.8,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  amount,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: isNegativeAlert ? AppColors.payableRed : AppColors.textPrimary,
                  ),
                ),
              ),
              if (secondaryInfo != null) ...[
                const SizedBox(height: 4),
                Text(
                  secondaryInfo!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isNegativeAlert ? AppColors.payableRed : AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
