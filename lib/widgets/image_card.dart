import 'package:flutter/material.dart';
import '../models/block_item.dart';
import '../services/image_service.dart';
import 'horizontal_image_row.dart';
import 'timeline_card_theme.dart';

class ImageCard extends StatelessWidget {
  final BlockItem item;
  final TraceImageService imageService;

  const ImageCard({super.key, required this.item, required this.imageService});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: TimelineCardTheme.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                if (item.tags.isNotEmpty)
                  Expanded(
                    child: Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: item.tags
                          .map(
                            (t) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: TimelineCardTheme.chipDecoration(),
                              child: Text(
                                '# $t',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: TimelineCardTheme.chipText,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  )
                else
                  const Icon(
                    Icons.image_outlined,
                    color: Colors.white70,
                    size: 16,
                  ),
                const SizedBox(width: 8),
                Text(
                  _formatTime(item.createdAt),
                  style: const TextStyle(
                    color: TimelineCardTheme.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
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
