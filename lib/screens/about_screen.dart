import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/platform_helper.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _version = '1.0.0';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isMacOS = PlatformHelper.isMacOS;
    final bgColor = isMacOS ? const Color(0xFF1A1A2E) : const Color(0xFFF5F6FA);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: bgColor,
        elevation: 0,
        title: Text(
          '关于',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: isMacOS ? const Color(0xFFF2F6FF) : null,
          ),
        ),
      ),
      body: Column(
        children: [
          // Logo + 信息
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4A6CF7), Color(0xFF6A3DE8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4A6CF7).withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.timeline_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Block Trace',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: isMacOS ? Color(0xFFF2F6FF) : Color(0xFF1A1A2E),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'v$_version',
                  style: TextStyle(
                    fontSize: 13,
                    color: isMacOS ? const Color(0xFF95A0BD) : cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '作者: Derek X',
                  style: TextStyle(
                    fontSize: 13,
                    color: isMacOS ? const Color(0xFF95A0BD) : cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Block Trace 是一款基于 Block 去中心化网络的痕迹记录应用，记录你的 GPS 位置、图片与文字，数据安全存储在链上。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isMacOS ? const Color(0xFF95A0BD) : cs.onSurfaceVariant,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 信息列表
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _LinkTile(
                  icon: Icons.code_rounded,
                  iconColor: const Color(0xFF1A1A2E),
                  label: 'GitHub',
                  url: 'https://github.com/derek44554/block_trace',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _LinkTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String url;

  const _LinkTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    final isMacOS = PlatformHelper.isMacOS;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isMacOS
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white,
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
        onTap: () => launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isMacOS
                            ? const Color(0xFFF2F6FF)
                            : const Color(0xFF1A1A2E))),
              ),
              Icon(
                Icons.open_in_new_rounded,
                size: 16,
                color: isMacOS ? const Color(0xFF95A0BD) : const Color(0xFF9E9E9E),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
