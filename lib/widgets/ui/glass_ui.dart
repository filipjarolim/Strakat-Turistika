import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Enum for button types
enum GlassButtonType {
  primary,
  secondary,
  destructive, // Renamed from danger to match legacy usage
}

/// Compatibility layer: Maps old Glass UI to new Standard UI
class GlassScaffold extends StatelessWidget {
  final Widget? body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final Color? backgroundColor;
  final PreferredSizeWidget? appBar;

  const GlassScaffold({
    Key? key,
    this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.backgroundColor,
    this.appBar,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? const Color(0xFFF5F6F7),
      appBar: appBar,
      extendBody: true,
      body: body,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final double? borderRadius; // Added for legacy compatibility

  const GlassCard({
    Key? key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.onTap,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: width,
      height: height,
      margin: margin ?? const EdgeInsets.symmetric(vertical: 8),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius ?? 16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: card,
      );
    }
    return card;
  }
}

class GlassButton extends StatelessWidget {
  final String? text; // Made optional
  final Widget? child; // Added for legacy compatibility
  final VoidCallback? onPressed;
  final GlassButtonType type;
  final IconData? icon;
  final bool isLoading;

  const GlassButton({
    Key? key,
    this.text,
    this.child,
    required this.onPressed,
    this.type = GlassButtonType.primary,
    this.icon,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;

    switch (type) {
      case GlassButtonType.primary:
        bgColor = const Color(0xFF4CAF50);
        textColor = Colors.white;
        break;
      case GlassButtonType.secondary:
        bgColor = Colors.white;
        textColor = const Color(0xFF1A1A1A);
        break;
      case GlassButtonType.destructive:
        bgColor = const Color(0xFFE53935);
        textColor = Colors.white;
        break;
    }

    // Modern Button Style
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: textColor,
          elevation: type == GlassButtonType.secondary ? 0 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: type == GlassButtonType.secondary 
              ? BorderSide(color: Colors.grey[300]!) 
              : BorderSide.none,
          ),
        ),
        child: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: textColor,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    if (text != null || child != null) const SizedBox(width: 8),
                  ],
                  if (text != null)
                    Text(
                      text!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else if (child != null)
                     // Apply text style if child is Text, via DefaultTextStyle?
                     // Or just render child. Legacy code likely passes Text.
                     DefaultTextStyle(
                       style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                       ),
                       child: child!,
                     ),
                ],
              ),
      ),
    );
  }
}

class GlassHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool center;
  final Widget? leading;

  const GlassHeader({
    Key? key,
    required this.title,
    this.subtitle,
    this.center = false,
    this.leading,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget content = Column(
      crossAxisAlignment:
          center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF666666),
            ),
          ),
        ],
      ],
    );

    if (leading != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          leading!,
          const SizedBox(width: 16),
          Expanded(child: content),
        ],
      );
    }

    return content;
  }
}
