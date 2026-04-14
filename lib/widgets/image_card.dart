import 'package:flutter/material.dart';
import '../models/block_item.dart';
import '../services/image_service.dart';
import 'trace_image.dart';

class ImageCard extends StatelessWidget {
  final BlockItem item;
  final TraceImageService imageService;

  const ImageCard({super.key, required this.item, required this.imageService});

  @override
  Widget build(BuildContext context) {
    final meta = item.imageMetas.isNotEmpty ? item.imageMetas.first : null;
    final hasUrl = item.imageUrls.isNotEmpty;

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
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: meta != null
                ? TraceImage(
                    cid: meta.cid,
                    encryptionKey: meta.encryptionKey,
                    imageService: imageService,
                  )
                : hasUrl
                    ? Image.network(item.imageUrls.first, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder())
                    : _placeholder(),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  if (item.tags.isNotEmpty)
                    Expanded(
                      child: Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: item.tags
                            .map((t) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.4),
                                        width: 0.5),
                                  ),
                                  child: Text('# $t',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500)),
                                ))
                            .toList(),
                      ),
                    )
                  else
                    const Icon(Icons.image_outlined,
                        color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  Text(_formatTime(item.createdAt),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFF0F0F5),
      child: const Center(
        child: Icon(Icons.image_outlined, size: 48, color: Color(0xFFCCCCCC)),
      ),
    );
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
