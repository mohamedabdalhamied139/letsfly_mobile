import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Highly accessible button with minimum 48x48dp touch target,
/// semantic role declaration, and high contrast styling.
class AccessibleButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final String? semanticHint;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool isPrimary;
  final bool isDestructive;
  final double? minHeight;

  const AccessibleButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.semanticHint,
    this.backgroundColor,
    this.foregroundColor,
    this.isPrimary = true,
    this.isDestructive = false,
    this.minHeight = 52.0,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBg = backgroundColor ??
        (isDestructive
            ? AppColors.error
            : (isPrimary ? AppColors.primary : AppColors.surfaceVariant));
    final effectiveFg = foregroundColor ??
        (isPrimary || isDestructive ? Colors.white : AppColors.textPrimary);

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      hint: semanticHint,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight ?? 52.0, minWidth: 64.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: effectiveBg,
            foregroundColor: effectiveFg,
            disabledBackgroundColor: AppColors.surfaceVariant.withOpacity(0.4),
            disabledForegroundColor: AppColors.textDisabled,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            elevation: 2,
          ),
          onPressed: onPressed,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 22, color: effectiveFg),
                const SizedBox(width: 8.0),
              ],
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                    color: effectiveFg,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Accessible Section Header announcing structure to screen readers.
class AccessibleHeader extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const AccessibleHeader(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: text,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Text(
          text,
          style: style ??
              const TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
                color: AppColors.accent,
              ),
        ),
      ),
    );
  }
}
