import 'package:flutter/material.dart';
import 'package:block_flutter/block_flutter.dart';
import 'package:provider/provider.dart';
import '../models/block_item.dart';
import '../core/platform_helper.dart';
import '../providers/draft_provider.dart';
import '../providers/trace_provider.dart';
import '../services/image_service.dart';
import '../widgets/trace_image.dart';
import 'edit_screen.dart';

const _detailBgTop = Color(0xFFF7FAFF);
const _detailBgBottom = Color(0xFFE7F0FF);
const _detailInk = Color(0xFF152033);
const _detailBody = Color(0xFF46516A);
const _detailMuted = Color(0xFF7C889E);
const _detailAccent = Color(0xFF4A6CF7);
const _detailAccentSoft = Color(0xFFDDE6FF);
const _detailSurface = Color(0xFFE6EEFF);
const _detailSurfaceTint = Color(0xFFD8E5FF);
const _detailBorder = Color(0xFFB8C9EC);
const _detailShadow = Color(0x1E0C1A3A);
const _detailPanel = Color(0xFFDCE7FB);
const _detailPanelSoft = Color(0xFFCFDCF5);

class _DetailPalette {
  final Color bg;
  final List<Color> backgroundGradient;
  final Color ink;
  final Color body;
  final Color muted;
  final Color accent;
  final Color accentSoft;
  final Color surface;
  final Color surfaceTint;
  final Color border;
  final Color shadow;
  final Color panel;
  final Color panelSoft;
  final Color heroStart;
  final Color heroEnd;
  final Color glowA;
  final Color glowB;
  final bool dark;

  const _DetailPalette({
    required this.bg,
    required this.backgroundGradient,
    required this.ink,
    required this.body,
    required this.muted,
    required this.accent,
    required this.accentSoft,
    required this.surface,
    required this.surfaceTint,
    required this.border,
    required this.shadow,
    required this.panel,
    required this.panelSoft,
    required this.heroStart,
    required this.heroEnd,
    required this.glowA,
    required this.glowB,
    required this.dark,
  });

  factory _DetailPalette.forPlatform({required bool isMacOS}) {
    if (isMacOS) {
      return const _DetailPalette(
        bg: Color(0xFF1A1A2E),
        backgroundGradient: [
          Color(0xFF1A1A2E),
          Color(0xFF1A1A2E),
          Color(0xFF17192A),
        ],
        ink: Color(0xFFF2F6FF),
        body: Color(0xFFBAC5DE),
        muted: Color(0xFF7F8AA7),
        accent: Color(0xFF6E8CFF),
        accentSoft: Color(0x2231446F),
        surface: Color(0x001A1A2E),
        surfaceTint: Color(0x001A1A2E),
        border: Color(0x2AFFFFFF),
        shadow: Color(0x00000000),
        panel: Color(0x001A1A2E),
        panelSoft: Color(0x001A1A2E),
        heroStart: Color(0xFF6E8CFF),
        heroEnd: Color(0xFF4564D6),
        glowA: Color(0x126E8CFF),
        glowB: Color(0x0D4C6FE6),
        dark: true,
      );
    }

    return const _DetailPalette(
      bg: _detailBgTop,
      backgroundGradient: [Color(0xFFF8FBFF), _detailBgTop, _detailBgBottom],
      ink: _detailInk,
      body: _detailBody,
      muted: _detailMuted,
      accent: _detailAccent,
      accentSoft: _detailAccentSoft,
      surface: _detailSurface,
      surfaceTint: _detailSurfaceTint,
      border: _detailBorder,
      shadow: _detailShadow,
      panel: _detailPanel,
      panelSoft: _detailPanelSoft,
      heroStart: _detailAccent,
      heroEnd: Color(0xFF7B9CFF),
      glowA: Color(0x2E4A6CF7),
      glowB: Color(0x248FB4FF),
      dark: false,
    );
  }
}

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
    final palette = _DetailPalette.forPlatform(isMacOS: PlatformHelper.isMacOS);

    return Scaffold(
      backgroundColor: palette.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: palette.surface.withValues(
                alpha: palette.dark ? 0.82 : 0.92,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: palette.border, width: 0.8),
              boxShadow: [
                BoxShadow(
                  color: palette.shadow,
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(Icons.arrow_back_rounded, size: 18, color: palette.ink),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: FilledButton(
              onPressed: () {
                final draftProvider = context.read<DraftProvider>();
                final draft = draftProvider.findLatestByExistingBid(
                  d.bid.isNotEmpty ? d.bid : null,
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditScreen(
                      draftId: draft?.id,
                      initialTitle: draft != null ? draft.title : d.title,
                      initialContent: draft != null ? draft.content : d.content,
                      initialTags: draft?.tags ?? d.tags,
                      initialLocalImagePaths: draft?.localImagePaths ?? const [],
                      initialImageMetas: draft?.existingImageMetas ?? d.imageMetas,
                      initialAddTime: draft?.initialAddTime ?? d.createdAt,
                      existingBid: d.bid.isNotEmpty ? d.bid : null,
                      initialLat: draft?.lat ?? d.lat,
                      initialLng: draft?.lng ?? d.lng,
                    ),
                  ),
                ).then((_) => _loadLatest()); // 编辑后刷新
              },
              style: FilledButton.styleFrom(
                backgroundColor: palette.accent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 0,
                ),
                minimumSize: const Size(0, 34),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: const Text(
                '编辑',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: palette.backgroundGradient,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 40),
          child: Stack(
            children: [
              Positioned(
                right: -55,
                top: 0,
                child: _Glow(color: palette.glowA, size: 220),
              ),
              Positioned(
                left: -70,
                top: 240,
                child: _Glow(color: palette.glowB, size: 260),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (d.imageMetas.isNotEmpty) ...[
                    _HorizontalImageRow(
                      imageMetas: d.imageMetas,
                      imageService: widget.imageService,
                      palette: palette,
                    ),
                    const SizedBox(height: 20),
                  ],
                  _InfoPanel(
                    palette: palette,
                    title: d.title,
                    content: d.content,
                    tags: d.tags,
                    bid: d.bid,
                    createdAt: d.createdAt,
                  ),
                  const SizedBox(height: 20),
                  if (d.lat != null && d.lng != null) ...[
                    _GpsBlock(lat: d.lat!, lng: d.lng!, palette: palette),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
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
  final _DetailPalette palette;
  const _GpsBlock({
    required this.lat,
    required this.lng,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: palette.dark ? Colors.transparent : palette.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: palette.dark
              ? Colors.white.withValues(alpha: 0.08)
              : palette.border,
          width: 0.9,
        ),
        boxShadow: palette.dark
            ? const []
            : [
                BoxShadow(
                  color: palette.shadow,
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          CustomPaint(
            size: const Size(double.infinity, 140),
            painter: _GridPainter(palette: palette),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: palette.accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: palette.accent.withValues(alpha: 0.30),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: palette.accent.withValues(alpha: 0.24),
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
                color: palette.dark
                    ? Colors.white.withValues(alpha: 0.03)
                    : palette.surface.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: palette.dark
                      ? Colors.white.withValues(alpha: 0.08)
                      : palette.border,
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.my_location_rounded,
                    size: 12,
                    color: palette.accent,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${lat.toStringAsFixed(6)},  ${lng.toStringAsFixed(6)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: palette.accent,
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
  final _DetailPalette palette;
  const _GridPainter({required this.palette});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = palette.dark
          ? Colors.white.withValues(alpha: 0.07)
          : const Color(0xFFC9D7F5)
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

class _HorizontalImageRow extends StatelessWidget {
  final List<ImageMeta> imageMetas;
  final TraceImageService imageService;
  final _DetailPalette palette;

  const _HorizontalImageRow({
    required this.imageMetas,
    required this.imageService,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 124,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: imageMetas.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final meta = imageMetas[index];
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 150,
              height: 124,
              color: palette.dark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.transparent,
              child: meta.cid.isNotEmpty
                  ? TraceImage(
                      cid: meta.cid,
                      encryptionKey: meta.encryptionKey,
                      imageService: imageService,
                    )
                  : Container(
                      color: palette.dark
                          ? Colors.white.withValues(alpha: 0.03)
                          : const Color(0xFFF0F0F5),
                      child: const Center(
                        child: Icon(
                          Icons.image_outlined,
                          size: 34,
                          color: Color(0xFFCCCCCC),
                        ),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;
  final double size;
  const _Glow({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final _DetailPalette palette;
  final String? title;
  final String? content;
  final List<String> tags;
  final String bid;
  final DateTime createdAt;

  const _InfoPanel({
    required this.palette,
    required this.title,
    required this.content,
    required this.tags,
    required this.bid,
    required this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.dark ? Colors.transparent : palette.panel,
        borderRadius: BorderRadius.circular(20),
        boxShadow: palette.dark
            ? const []
            : [
                BoxShadow(
                  color: palette.shadow,
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tags.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags
                  .map(
                    (t) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: palette.dark
                            ? Colors.white.withValues(alpha: 0.03)
                            : palette.accentSoft,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: palette.dark
                              ? Colors.white.withValues(alpha: 0.08)
                              : palette.border,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        '# $t',
                        style: TextStyle(
                          fontSize: 13,
                          color: palette.dark
                              ? const Color(0xFFDDE6FF)
                              : palette.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],
          if (title != null && title!.isNotEmpty) ...[
            Text(
              title!,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: palette.ink,
                height: 1.25,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 3,
              width: 42,
              decoration: BoxDecoration(
                color: palette.accent,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (content != null && content!.isNotEmpty) ...[
            Text(
              content!,
              style: TextStyle(fontSize: 16, color: palette.body, height: 1.8),
            ),
            const SizedBox(height: 16),
          ],
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.dark ? Colors.transparent : palette.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: palette.dark
                    ? Colors.white.withValues(alpha: 0.08)
                    : palette.border,
                width: 0.9,
              ),
              boxShadow: palette.dark
                  ? const []
                  : [
                      BoxShadow(
                        color: palette.shadow,
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: Column(
              children: [
                _MetaRow(
                  palette: palette,
                  icon: Icons.access_time_rounded,
                  label: '时间',
                  value: _fmtStatic(createdAt),
                ),
                if (bid.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _MetaRow(
                    palette: palette,
                    icon: Icons.fingerprint_rounded,
                    label: 'BID',
                    value: bid,
                    mono: true,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final _DetailPalette palette;
  final IconData icon;
  final String label;
  final String value;
  final bool mono;

  const _MetaRow({
    required this.palette,
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
        Icon(icon, size: 14, color: palette.muted),
        const SizedBox(width: 8),
        Text('$label  ', style: TextStyle(fontSize: 12, color: palette.muted)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: palette.ink,
              fontFamily: mono ? 'monospace' : null,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

String _fmtStatic(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
