import 'dart:ui';
import 'package:flutter/material.dart';

class FirebaseSnackbar {
  static void success(BuildContext context, String message) {
    _show(context, message, Colors.green, Icons.check_circle);
  }

  static void error(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _show(
      context,
      message,
      Colors.red,
      Icons.error_outline,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void warning(BuildContext context, String message) {
    _show(context, message, Colors.orange, Icons.warning_amber);
  }

  static void info(BuildContext context, String message) {
    _show(context, message, Colors.blue, Icons.info_outline);
  }

  static void _show(
    BuildContext context,
    String message,
    Color color,
    IconData icon, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final overlay = Overlay.of(context);

    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) {
        return _AnimatedSnackbar(
          message: message,
          color: color,
          icon: icon,
          actionLabel: actionLabel,
          onAction: onAction,
          onDismiss: () {
            overlayEntry.remove();
          },
        );
      },
    );

    overlay.insert(overlayEntry);
  }
}

class _AnimatedSnackbar extends StatefulWidget {
  final String message;
  final Color color;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;

  const _AnimatedSnackbar({
    required this.message,
    required this.color,
    required this.icon,
    required this.onDismiss,
    this.actionLabel,
    this.onAction,
  });

  @override
  State<_AnimatedSnackbar> createState() => _AnimatedSnackbarState();
}

class _AnimatedSnackbarState extends State<_AnimatedSnackbar>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late Animation<Offset> slideAnimation;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));

    controller.forward();

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        controller.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: width < 600 ? 16 : width * 0.3,
      right: width < 600 ? 16 : width * 0.3,
      child: SlideTransition(
        position: slideAnimation,
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: widget.color.withOpacity(0.4)),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(widget.icon, color: widget.color),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    /// 🔥 RETRY BUTTON
                    if (widget.actionLabel != null)
                      GestureDetector(
                        onTap: () {
                          widget.onAction?.call();
                          controller.reverse().then((_) => widget.onDismiss());
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Text(
                            widget.actionLabel!,
                            style: TextStyle(
                              color: widget.color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                    GestureDetector(
                      onTap: () {
                        controller.reverse().then((_) => widget.onDismiss());
                      },
                      child: const Icon(
                        Icons.close,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
