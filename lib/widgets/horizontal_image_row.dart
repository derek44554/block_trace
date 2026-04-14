import 'package:flutter/material.dart';
import '../models/block_item.dart';
import '../services/image_service.dart';
import 'trace_image.dart';

class HorizontalImageRow extends StatelessWidget {
  final List<String> imageUrls;
  final List<ImageMeta> imageMetas;
  final TraceImageService? imageService;
  final double height;
  final double tileWidth;

  const HorizontalImageRow({
    super.key,
    this.imageUrls = const [],
    this.imageMetas = const [],
    this.imageService,
    this.height = 124,
    this.tileWidth = 150,
  });

  int get _count =>
      imageMetas.isNotEmpty ? imageMetas.length : imageUrls.length;

  Widget _imageAt(int index) {
    if (imageMetas.isNotEmpty && imageService != null) {
      final meta = imageMetas[index];
      return TraceImage(
        cid: meta.cid,
        encryptionKey: meta.encryptionKey,
        imageService: imageService!,
      );
    }
    if (index < imageUrls.length) {
      return Image.network(
        imageUrls[index],
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  @override
  Widget build(BuildContext context) {
    if (_count == 0) return _placeholder();

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _count,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: tileWidth,
              height: height,
              child: _imageAt(index),
            ),
          );
        },
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFF0F0F5),
      child: const Center(
        child: Icon(Icons.image_outlined, size: 34, color: Color(0xFFCCCCCC)),
      ),
    );
  }
}
