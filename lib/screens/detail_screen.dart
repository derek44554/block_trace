import 'package:flutter/material.dart';
import 'package:block_flutter/block_flutter.dart';
import 'package:provider/provider.dart';
import '../models/block_item.dart';
import '../providers/trace_provider.dart';
import '../services/image_service.dart';
import '../widgets/multi_image_grid.dart';
import 'edit_screen.dart';

class DetailScreen extends StatefulWidget {
  final BlockModel block;
  final TraceImageService imageService;

  const DetailScreen({
    super.key,
    required this.block,
    required this.imageService,
  });

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late BlockModel _block;

  @override
  void initState() {
    super.initState();
    _block = widget.block;
    _loadLatest();
  }

  Future<void> _loadLatest() async {
    final bid = _block.maybeString('bid');
    if (bid == null || bid.isEmpty) return;
    final latest = await context.read<TraceProvider>().getBlock(bid);
    if (latest != null && mounted) {
      setState(() => _block = latest);
    }
  }

  // 从 BlockModel 直接解析显示数据
  _DisplayData _parse() {
    final title = _block.maybeString('title');
    final content = _block.maybeString('content');
    final tags = _block.getList<String>('tag');
    final addTime = _block.getDateTime('add_time') ?? DateTime.now();
    final gps = _block.getMap('gps');
    final imageList = _block.getList<String>('image_list');
    final bid = _block.maybeString('bid') ?? '';

    final traceProvider = context.read<TraceProvider>();
    final imageMetas = imageList.map((imageBid) {
      final info = traceProvider.getImageInfo(imageBid);
      final cid = info?['cid'] ?? imageBid;
      final key = info?['key'];
      return ImageMeta(cid: cid, encryptionKey: key, bid: imageBid);
    }).toList();

    double? lat, lng;
    if (gps.isNotEmpty) {
      lat = (gps['latitude'] as num?)?.toDouble();
      lng = (gps['longitude'] as num?)?.toDouble();
    }

    return _DisplayData(
      bid: bid,
      title: title,
      content: content,
      tags: tags,
      imageMetas: imageMetas,
      lat: lat,
      lng: lng,
      createdAt: addTime,
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _parse();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F6FA),
        surfaceTintColor: const Color(0xFFF5F6FA),
        elevation: 0,
        leading: IconButton(
          icon: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_rounded,
                size: 18, color: Color(0xFF1A1A2E)),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: FilledButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditScreen(
                      initialTitle: d.title,
                      initialContent: d.content,
                      initialTags: d.tags,
                      initialImageMetas: d.imageMetas,
                      initialAddTime: d.createdAt,
                      existingBid: d.bid.isNotEmpty ? d.bid : null,
                      initialLat: d.lat,
                      initialLng: d.lng,
                    ),
                  ),
                ).then((_) => _loadLatest()); // 编辑后刷新
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4A6CF7),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
                minimumSize: const Size(0, 34),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text('编辑',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 图片
            if (d.imageMetas.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: MultiImageGrid(
                  imageMetas: d.imageMetas,
                  imageService: widget.imageService,
                  singleAspectRatio: 4 / 3,
                ),
              ),
              const SizedBox(height: 20),
            ],

            // GPS
            if (d.lat != null && d.lng != null) ...[
              _GpsBlock(lat: d.lat!, lng: d.lng!),
              const SizedBox(height: 20),
            ],

            // 标题
            if (d.title != null && d.title!.isNotEmpty) ...[
              Text(
                d.title!,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E),
                  height: 1.3,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                height: 2,
                width: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF4A6CF7).withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 正文
            if (d.content != null && d.content!.isNotEmpty) ...[
              Text(
                d.content!,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF333344),
                  height: 1.8,
                ),
              ),
              const SizedBox(height: 20),
            ],

            // 标签
            if (d.tags.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: d.tags
                    .map((t) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F2FF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('# $t',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF4A6CF7),
                                fontWeight: FontWeight.w500,
                              )),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),
            ],

            // 时间 + BID
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _MetaRow(
                    icon: Icons.access_time_rounded,
                    label: '时间',
                    value: _fmt(d.createdAt),
                  ),
                  if (d.bid.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _MetaRow(
                      icon: Icons.fingerprint_rounded,
                      label: 'BID',
                      value: d.bid,
                      mono: true,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _DisplayData {
  final String bid;
  final String? title;
  final String? content;
  final List<String> tags;
  final List<ImageMeta> imageMetas;
  final double? lat;
  final double? lng;
  final DateTime createdAt;

  const _DisplayData({
    required this.bid,
    required this.title,
    required this.content,
    required this.tags,
    required this.imageMetas,
    required this.lat,
    required this.lng,
    required this.createdAt,
  });
}

// ── GPS 区块 ──────────────────────────────────────────────────

class _GpsBlock extends StatelessWidget {
  final double lat;
  final double lng;
  const _GpsBlock({required this.lat, required this.lng});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0FE),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          CustomPaint(
            size: const Size(double.infinity, 140),
            painter: _GridPainter(),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A6CF7),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4A6CF7).withValues(alpha: 0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.location_on,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A6CF7).withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 10,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.my_location_rounded,
                      size: 12, color: Color(0xFF4A6CF7)),
                  const SizedBox(width: 5),
                  Text(
                    '${lat.toStringAsFixed(6)},  ${lng.toStringAsFixed(6)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF4A6CF7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCDD8F6)
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

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool mono;

  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF9E9E9E)),
        const SizedBox(width: 8),
        Text('$label  ',
            style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: const Color(0xFF444455),
              fontFamily: mono ? 'monospace' : null,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
