import 'package:flutter/material.dart';
import '../models/block_item.dart';
import '../services/image_service.dart';
import 'horizontal_image_row.dart';
import 'timeline_card_theme.dart';

class RichCard extends StatelessWidget {
  final BlockItem item;
  final TraceImageService imageService;

  const RichCard({super.key, required this.item, required this.imageService});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: TimelineCardTheme.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.imageMetas.isNotEmpty || item.imageUrls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: HorizontalImageRow(
                imageMetas: item.imageMetas,
                imageUrls: item.imageUrls,
                imageService: imageService,
                height: 122,
                tileWidth: 152,
              ),
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
                      color: TimelineCardTheme.title,
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
                      color: TimelineCardTheme.body,
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
                        color: TimelineCardTheme.muted,
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
