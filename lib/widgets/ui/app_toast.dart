
import 'package:flutter/material.dart';
import 'package:strakataturistikaandroidapp/config/app_colors.dart';

class AppToast {
  static void show(BuildContext context, String message, {bool isError = false, bool isInfo = false, Duration? duration, String? actionLabel, VoidCallback? onAction}) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    // Clear existing snackbars to prevent stacking
    scaffoldMessenger.clearSnackBars();
    
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: _ToastContent(message: message, isError: isError, isInfo: isInfo, actionLabel: actionLabel, onAction: onAction),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: duration ?? const Duration(seconds: 4),
        dismissDirection: DismissDirection.horizontal,
        margin: const EdgeInsets.all(16),
        padding: EdgeInsets.zero,
      ),
    );
  }

  static void showError(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) => 
      show(context, message, isError: true, actionLabel: actionLabel, onAction: onAction);
      
  static void showSuccess(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) => 
      show(context, message, actionLabel: actionLabel, onAction: onAction);
      
  static void showInfo(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) => 
      show(context, message, isInfo: true, actionLabel: actionLabel, onAction: onAction);
}

class _ToastContent extends StatelessWidget {
  final String message;
  final bool isError;
  final bool isInfo;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _ToastContent({
    required this.message,
    this.isError = false,
    this.isInfo = false,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    Color typeColor = AppColors.success;
    IconData icon = Icons.check_circle_rounded;
    
    if (isError) {
      typeColor = AppColors.error;
      icon = Icons.error_rounded;
    } else if (isInfo) {
      typeColor = AppColors.primary;
      icon = Icons.info_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: typeColor.withValues(alpha: 0.15),
            blurRadius: 0,
            spreadRadius: 0,
            offset: const Offset(0, 0),
          ),
        ],
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: typeColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 12),
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  actionLabel!,
                  style: TextStyle(
                    color: typeColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
