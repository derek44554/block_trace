import 'package:flutter/material.dart';

class MacMenuButton extends StatefulWidget {
  const MacMenuButton({
    super.key,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<MacMenuButton> createState() => _MacMenuButtonState();
}

class _MacMenuButtonState extends State<MacMenuButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isActive;
    final bgOpacity = isActive ? 0.12 : _isHovering ? 0.08 : 0.03;
    final borderOpacity = isActive ? 0.24 : _isHovering ? 0.14 : 0.08;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: bgOpacity),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: borderOpacity),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                color: Colors.white.withValues(alpha: isActive ? 0.95 : 0.7),
                size: 16,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: isActive ? 0.96 : 0.78),
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 12.5,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              AnimatedOpacity(
                opacity: isActive ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}