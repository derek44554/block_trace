enum BlockType { gps, image, rich }

class ImageMeta {
  final String cid;
  final String? encryptionKey;
  final String? bid; // 图片 block 的原始 bid
  const ImageMeta({required this.cid, this.encryptionKey, this.bid});
}

class BlockItem {
  final BlockType type;
  final String? title;
  final String? content;
  final List<String> tags;
  final List<String> imageUrls;       // 远程 URL（旧）
  final List<ImageMeta> imageMetas;   // IPFS 图片元数据（新）
  final double? lat;
  final double? lng;
  final String? locationName;
  final DateTime createdAt;

  const BlockItem({
    required this.type,
    required this.createdAt,
    this.title,
    this.content,
    this.tags = const [],
    this.imageUrls = const [],
    this.imageMetas = const [],
    this.lat,
    this.lng,
    this.locationName,
  });
}
