import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/image_service.dart';

class TraceImage extends StatefulWidget {
  final String cid;
  final String? encryptionKey;
  final TraceImageService imageService;
  final BoxFit fit;
  final double? width;
  final double? height;

  const TraceImage({
    super.key,
    required this.cid,
    required this.imageService,
    this.encryptionKey,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  @override
  State<TraceImage> createState() => _TraceImageState();
}

class _TraceImageState extends State<TraceImage>
    with SingleTickerProviderStateMixin {
  Uint8List? _bytes;
  bool _loading = true;
  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _load();
  }

  @override
  void didUpdateWidget(TraceImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cid != widget.cid) {
      setState(() { _bytes = null; _loading = true; });
      _load();
    }
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final bytes = await widget.imageService.loadByCid(
      cid: widget.cid,
      encryptionKey: widget.encryptionKey,
    );
    if (mounted) setState(() { _bytes = bytes; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    // 始终占满父容器，不等加载完再撑开
    return SizedBox.expand(
      child: _loading
          ? AnimatedBuilder(
              animation: _shimmerCtrl,
              builder: (_, __) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-1.5 + _shimmerCtrl.value * 3, 0),
                    end: Alignment(-0.5 + _shimmerCtrl.value * 3, 0),
                    colors: const [
                      Color(0xFFEEEEEE),
                      Color(0xFFF8F8F8),
                      Color(0xFFEEEEEE),
                    ],
                  ),
                ),
              ),
            )
          : _bytes != null
              ? Image.memory(
                  _bytes!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                )
              : Container(
                  color: const Color(0xFFF0F0F5),
                  child: const Center(
                    child: Icon(Icons.broken_image_outlined,
                        size: 32, color: Color(0xFFCCCCCC)),
                  ),
                ),
    );
  }
}
