import 'package:flutter/material.dart';
import '../core/platform_helper.dart';
import 'about_screen.dart';
import 'setup_screen.dart';

class SettingsScreen extends StatelessWidget {
  final bool isEmbedded;
  const SettingsScreen({super.key, this.isEmbedded = false});

  @override
  Widget build(BuildContext context) {
    final isMacOS = PlatformHelper.isMacOS;
    final bgColor = isMacOS ? const Color(0xFF1A1A2E) : const Color(0xFFF5F6FA);

    final content = ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        _SectionLabel(label: '连接'),
        _SettingsTile(
          icon: Icons.dns_rounded,
          iconColor: const Color(0xFF4A6CF7),
          label: '节点设置',
          subtitle: '管理 Block 节点与 IPFS 连接',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SetupScreen()),
          ),
        ),
        const SizedBox(height: 20),
        _SectionLabel(label: '其他'),
        _SettingsTile(
          icon: Icons.info_outline_rounded,
          iconColor: const Color(0xFF6A3DE8),
          label: '关于',
          subtitle: 'Block Trace · Derek X',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AboutScreen()),
          ),
        ),
      ],
    );

    if (isEmbedded) {
      return content;
    }
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: bgColor,
        elevation: 0,
        title: Text(
          '设置',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: isMacOS ? const Color(0xFFF2F6FF) : null,
          ),
        ),
      ),
      body: content,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final isMacOS = PlatformHelper.isMacOS;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isMacOS ? const Color(0xFF87A1FF) : const Color(0xFF4A6CF7),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isMacOS = PlatformHelper.isMacOS;
    return Container(
      decoration: BoxDecoration(
        color: isMacOS ? Colors.white.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isMacOS
            ? Border.all(color: Colors.white.withValues(alpha: 0.14))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isMacOS ? 0.18 : 0.04),
            blurRadius: isMacOS ? 14 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w500,
                            color: isMacOS
                                ? const Color(0xFFF2F6FF)
                                : const Color(0xFF1A1A2E))),
                    if (subtitle != null)
                      Text(subtitle!,
                          style: TextStyle(
                              fontSize: 12,
                              color: isMacOS
                                  ? const Color(0xFF95A0BD)
                                  : const Color(0xFF9E9E9E))),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: isMacOS ? const Color(0xFF95A0BD) : const Color(0xFF9E9E9E),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
