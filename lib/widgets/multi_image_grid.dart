import 'package:flutter/material.dart';
import '../models/block_item.dart';
import '../services/image_service.dart';
import 'trace_image.dart';

class MultiImageGrid extends StatelessWidget {
  final List<String> imageUrls;
  final List<ImageMeta> imageMetas;
  final TraceImageService? imageService;
  final double singleAspectRatio;

  const MultiImageGrid({
    super.key,
    this.imageUrls = const [],
    this.imageMetas = const [],
    this.imageService,
    this.singleAspectRatio = 4 / 3,
  });

  int get _count => imageMetas.isNotEmpty ? imageMetas.length : imageUrls.length;

  Widget _img(int index) {
    if (imageMetas.isNotEmpty && imageService != null) {
      final meta = imageMetas[index];
      return TraceImage(
        cid: meta.cid,
        encryptionKey: meta.encryptionKey,
        imageService: imageService!,
      );
    }
    if (index < imageUrls.length) {
      return Image.network(imageUrls[index], fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder());
    }
    return _placeholder();
  }

  @override
  Widget build(BuildContext context) {
    final count = _count;
    if (count == 0) return _placeholder(height: 160);

    if (count == 1) {
      return AspectRatio(
        aspectRatio: singleAspectRatio,
        child: _img(0),
      );
    }

    if (count == 2) {
      return AspectRatio(
        aspectRatio: 2,
        child: Row(
          children: [
            Expanded(child: _img(0)),
            const SizedBox(width: 2),
            Expanded(child: _img(1)),
          ],
        ),
      );
    }

    if (count == 3) {
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 2, child: SizedBox.expand(child: _img(0))),
            const SizedBox(width: 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: SizedBox.expand(child: _img(1))),
                  const SizedBox(height: 2),
                  Expanded(child: SizedBox.expand(child: _img(2))),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 4张及以上
    final displayCount = count > 4 ? 4 : count;
    return AspectRatio(
      aspectRatio: 1,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        itemCount: displayCount,
        itemBuilder: (context, index) {
          final isLast = index == 3 && count > 4;
          return Stack(
            fit: StackFit.expand,
            children: [
              _img(index),
              if (isLast)
                Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: Center(
                    child: Text('+${count - 3}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _placeholder({double? height}) {
    return Container(
      height: height,
      color: const Color(0xFFF0F0F5),
      child: const Center(
        child: Icon(Icons.image_outlined, size: 40, color: Color(0xFFCCCCCC)),
      ),
    );
  }
}
