import 'package:flutter/material.dart';
import '../models/block_item.dart';
import '../services/image_service.dart';
import 'multi_image_grid.dart';

class RichCard extends StatelessWidget {
  final BlockItem item;
  final TraceImageService imageService;

  const RichCard({super.key, required this.item, required this.imageService});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.imageMetas.isNotEmpty)
            MultiImageGrid(
              imageMetas: item.imageMetas,
              imageService: imageService,
              singleAspectRatio: 16 / 9,
            )
          else if (item.imageUrls.isNotEmpty)
            MultiImageGrid(
              imageUrls: item.imageUrls,
              singleAspectRatio: 16 / 9,
            ),

          // 内容区
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题
                if (item.title != null) ...[
                  Text(
                    item.title!,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                ],
                // 正文
                if (item.content != null) ...[
                  Text(
                    item.content!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF666680),
                      height: 1.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                ],
                // 标签 + 时间
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: item.tags
                            .map((tag) => _TagChip(label: tag))
                            .toList(),
                      ),
                    ),
                    Text(
                      _formatDate(item.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9E9E9E),
                      ),
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

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _TagChip extends StatelessWidget {
  final String label;

  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '# $label',
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF4A6CF7),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
