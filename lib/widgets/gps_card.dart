import 'package:flutter/material.dart';
import '../models/block_item.dart';
import '../services/image_service.dart';
import 'timeline_card_theme.dart';

class GpsCard extends StatelessWidget {
  final BlockItem item;
  final TraceImageService imageService;

  const GpsCard({super.key, required this.item, required this.imageService});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: TimelineCardTheme.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 地图占位区域
          Container(
            height: 130,
            color: TimelineCardTheme.mapSurface,
            child: Stack(
              children: [
                CustomPaint(
                  size: const Size(double.infinity, 130),
                  painter: _MapGridPainter(),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: TimelineCardTheme.accent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: TimelineCardTheme.accent.withValues(alpha: 0.38),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.location_on,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: TimelineCardTheme.accentSoft.withValues(alpha: 0.28),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
                // 经纬度浮层
                Positioned(
                  bottom: 8,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E1524).withValues(alpha: 0.84),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.my_location_rounded,
                            size: 11, color: TimelineCardTheme.body),
                        const SizedBox(width: 4),
                        Text(
                          '${item.lat?.toStringAsFixed(5) ?? '--'}, ${item.lng?.toStringAsFixed(5) ?? '--'}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: TimelineCardTheme.body,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 内容区
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题
                if (item.title != null) ...[
                  Text(
                    item.title!,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: TimelineCardTheme.title,
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                ],

                // 描述
                if (item.content != null) ...[
                  Text(
                    item.content!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: TimelineCardTheme.body,
                      height: 1.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                ],

                // 标签 + 时间
                Row(
                  children: [
                    if (item.tags.isNotEmpty)
                      Expanded(
                        child: Wrap(
                          spacing: 5,
                          runSpacing: 4,
                          children: item.tags
                              .map((t) => _TagChip(label: t))
                              .toList(),
                        ),
                      )
                    else
                      const Spacer(),
                    Text(
                      _formatTime(item.createdAt),
                      style: const TextStyle(
                          fontSize: 11, color: TimelineCardTheme.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _TagChip extends StatelessWidget {
  final String label;
  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: TimelineCardTheme.chipDecoration(),
      child: Text(
        '# $label',
        style: const TextStyle(
          fontSize: 11,
          color: TimelineCardTheme.chipText,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 0.8;
    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
