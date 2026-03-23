import 'package:flutter/material.dart';

class LogoutConfirmationDialog extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final IconData icon;
  final Color primaryColor;
  final String? infoText;

  const LogoutConfirmationDialog({
    super.key,
    required this.onConfirm,
    this.onCancel,
    this.title = 'Sign Out',
    this.message = 'Are you sure you want to sign out of your account?',
    this.confirmText = 'Sign Out',
    this.cancelText = 'Cancel',
    this.icon = Icons.logout_rounded,
    this.primaryColor = Colors.red,
    this.infoText = 'You will be redirected to the login screen',
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 400;
    final isTablet = screenSize.width >= 600 && screenSize.width < 900;
    final isDesktop = screenSize.width >= 900;

    // Responsive sizing helper
    double getResponsiveValue({
      required double mobile,
      double? tablet,
      double? desktop,
    }) {
      if (isDesktop && desktop != null) return desktop;
      if (isTablet && tablet != null) return tablet;
      return mobile;
    }

    final double dialogWidth = getResponsiveValue(
      mobile: isSmallScreen ? 320 : 360,
      tablet: 400,
      desktop: 440,
    );

    final double iconSize = getResponsiveValue(
      mobile: isSmallScreen ? 40 : 48,
      tablet: 56,
      desktop: 64,
    );

    final double titleSize = getResponsiveValue(
      mobile: isSmallScreen ? 20 : 22,
      tablet: 24,
      desktop: 26,
    );

    final double messageSize = getResponsiveValue(
      mobile: isSmallScreen ? 14 : 15,
      tablet: 16,
      desktop: 17,
    );

    final double buttonHeight = getResponsiveValue(
      mobile: 44,
      tablet: 48,
      desktop: 52,
    );

    final double buttonFontSize = getResponsiveValue(
      mobile: 15,
      tablet: 16,
      desktop: 17,
    );

    final double spacing = getResponsiveValue(
      mobile: 20,
      tablet: 24,
      desktop: 28,
    );

    final double padding = getResponsiveValue(
      mobile: 24,
      tablet: 28,
      desktop: 32,
    );

    final double borderRadius = getResponsiveValue(
      mobile: 24,
      tablet: 28,
      desktop: 32,
    );

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 24,
        vertical: 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: dialogWidth,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFFDFDFD)],
          ),
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 50,
              offset: const Offset(0, 25),
              spreadRadius: -5,
            ),
            BoxShadow(
              color: primaryColor.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: -5,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated Icon with Glow Effect
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 600),
                  tween: Tween(begin: 0.0, end: 1.0),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: 0.8 + (0.2 * value),
                      child: Container(
                        width: iconSize * 1.8,
                        height: iconSize * 1.8,
                        decoration: BoxDecoration(
                          gradient: SweepGradient(
                            colors: [
                              primaryColor.withOpacity(0.1),
                              primaryColor.withOpacity(0.2),
                              primaryColor.withOpacity(0.1),
                            ],
                            transform: GradientRotation(value * 2),
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(
                                0.3 - (value * 0.1),
                              ),
                              blurRadius: 20 * value,
                              spreadRadius: 5 * value,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: iconSize * 1.2,
                            height: iconSize * 1.2,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.2),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                icon,
                                color: primaryColor,
                                size: iconSize * 0.6,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                SizedBox(height: spacing * 0.8),

                // Title with Gradient
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [primaryColor, primaryColor.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: Colors.white,
                    ),
                  ),
                ),

                SizedBox(height: spacing * 0.4),

                // Message
                Container(
                  padding: EdgeInsets.symmetric(horizontal: spacing * 0.3),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: messageSize,
                      color: Colors.grey.shade700,
                      height: 1.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),

                if (infoText != null) ...[
                  SizedBox(height: spacing * 0.6),

                  // Info Container
                  Container(
                    padding: EdgeInsets.all(spacing * 0.5),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(borderRadius * 0.5),
                      border: Border.all(color: Colors.grey.shade200, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.security_rounded,
                          size: messageSize * 1.2,
                          color: Colors.grey.shade600,
                        ),
                        SizedBox(width: spacing * 0.3),
                        Flexible(
                          child: Text(
                            infoText!,
                            style: TextStyle(
                              fontSize: messageSize * 0.9,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: spacing),

                // Buttons
                Row(
                  children: [
                    // Cancel Button
                    Expanded(
                      child: _buildDialogButton(
                        label: cancelText,
                        onPressed: () {
                          Navigator.pop(context, false);
                          onCancel?.call();
                        },
                        isPrimary: false,
                        height: buttonHeight,
                        fontSize: buttonFontSize,
                        borderRadius: borderRadius * 0.5,
                        primaryColor: primaryColor,
                      ),
                    ),

                    SizedBox(width: spacing * 0.5),

                    // Confirm Button
                    Expanded(
                      child: _buildDialogButton(
                        label: confirmText,
                        onPressed: () {
                          Navigator.pop(context, true);
                          onConfirm();
                        },
                        isPrimary: true,
                        height: buttonHeight,
                        fontSize: buttonFontSize,
                        borderRadius: borderRadius * 0.5,
                        primaryColor: primaryColor,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: spacing * 0.5),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDialogButton({
    required String label,
    required VoidCallback onPressed,
    required bool isPrimary,
    required double height,
    required double fontSize,
    required double borderRadius,
    required Color primaryColor,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: StatefulBuilder(
        builder: (context, setState) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: height,
            decoration: BoxDecoration(
              gradient: isPrimary
                  ? LinearGradient(
                      colors: [primaryColor, primaryColor.withOpacity(0.8)],
                    )
                  : null,
              color: isPrimary ? null : Colors.transparent,
              borderRadius: BorderRadius.circular(borderRadius),
              border: isPrimary
                  ? null
                  : Border.all(color: Colors.grey.shade300, width: 1.5),
              boxShadow: isPrimary
                  ? [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                onHover: (hover) {
                  setState(() as VoidCallback);
                },
                borderRadius: BorderRadius.circular(borderRadius),
                splashColor: isPrimary
                    ? Colors.white.withOpacity(0.2)
                    : primaryColor.withOpacity(0.1),
                highlightColor: Colors.transparent,
                child: Container(
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isPrimary)
                        Icon(
                          Icons.logout_rounded,
                          size: fontSize * 1.2,
                          color: Colors.white,
                        ),
                      if (isPrimary) const SizedBox(width: 8),
                      Text(
                        label,
                        style: TextStyle(
                          color: isPrimary
                              ? Colors.white
                              : Colors.grey.shade700,
                          fontSize: fontSize,
                          fontWeight: isPrimary
                              ? FontWeight.w600
                              : FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Helper function to show the dialog
Future<bool?> showLogoutConfirmationDialog(
  BuildContext context, {
  String title = 'Sign Out',
  String message = 'Are you sure you want to sign out of your account?',
  String confirmText = 'Sign Out',
  String cancelText = 'Cancel',
  IconData icon = Icons.logout_rounded,
  Color primaryColor = Colors.red,
  String? infoText = 'You will be redirected to the login screen',
  VoidCallback? onConfirm,
  VoidCallback? onCancel,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => LogoutConfirmationDialog(
      onConfirm: onConfirm ?? () {},
      onCancel: onCancel,
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      icon: icon,
      primaryColor: primaryColor,
      infoText: infoText,
    ),
  );
}
