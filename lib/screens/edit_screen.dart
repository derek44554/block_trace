import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/block_item.dart';
import '../providers/connection_provider.dart';
import '../providers/tag_provider.dart';
import '../services/image_service.dart';
import '../services/trace_service.dart';
import '../widgets/trace_image.dart';

class EditScreen extends StatefulWidget {
  final String? initialTitle;
  final String? initialContent;
  final List<String> initialTags;
  final List<ImageMeta> initialImageMetas;
  final String? existingBid;
  final DateTime? initialAddTime;
  final double? initialLat;
  final double? initialLng;

  const EditScreen({
    super.key,
    this.initialTitle,
    this.initialContent,
    this.initialTags = const [],
    this.initialImageMetas = const [],
    this.existingBid,
    this.initialAddTime,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  final _titleFocus = FocusNode();
  final _contentFocus = FocusNode();
  final List<XFile> _images = [];
  final _picker = ImagePicker();
  double _lastBottomInset = 0;
  _GpsData? _gpsPosition;
  bool _fetchingGps = false;
  late final List<String> _selectedTags;
  late final List<ImageMeta> _existingImageMetas; // 已有图片（不重新上传）
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initialTitle ?? '');
    _contentCtrl = TextEditingController(text: widget.initialContent ?? '');
    _selectedTags = List.from(widget.initialTags);
    _existingImageMetas = List.from(widget.initialImageMetas);
    // 恢复原始 GPS
    if (widget.initialLat != null && widget.initialLng != null) {
      _gpsPosition = _GpsData(widget.initialLat!, widget.initialLng!);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final inset = MediaQuery.of(context).viewInsets.bottom;
    if (_lastBottomInset > 0 && inset == 0) FocusScope.of(context).unfocus();
    _lastBottomInset = inset;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _titleFocus.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isNotEmpty) setState(() => _images.addAll(picked));
  }

  void _removeImage(int index) => setState(() => _images.removeAt(index));

  Future<void> _fetchGps() async {
    setState(() => _fetchingGps = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('位置权限被拒绝')),
          );
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) setState(() => _gpsPosition = _GpsData(pos.latitude, pos.longitude));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('获取位置失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _fetchingGps = false);
    }
  }

  void _addTag(String tag) {
    final t = tag.trim();
    if (t.isEmpty || _selectedTags.contains(t)) return;
    setState(() => _selectedTags.add(t));
  }

  void _removeTag(String tag) => setState(() => _selectedTags.remove(tag));

  void _showTagPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (ctx) => ChangeNotifierProvider.value(
        value: context.read<TagProvider>(),
        child: _TagPickerSheet(
          selectedTags: List.from(_selectedTags),
          onAdd: (tag) {
            _addTag(tag);
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  void _showInsertBidDialog() {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('插入图片 BID',
            style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '输入图片 BID',
            filled: true,
            fillColor: const Color(0xFFF5F6FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4A6CF7),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('插入'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            child: const Icon(Icons.close_rounded,
                size: 18, color: Color(0xFF1A1A2E)),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: null,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: FilledButton(
              onPressed: _saving ? null : () {
                print('=== 保存按钮被点击 ===');
                _onSave();
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4A6CF7),
                disabledBackgroundColor: const Color(0xFF4A6CF7),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 0),
                minimumSize: const Size(0, 36),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('保存',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () =>
                  FocusScope.of(context).requestFocus(_contentFocus),
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 已有图片预览（来自 image_list，只读）
                        if (_existingImageMetas.isNotEmpty) ...[
                          _ExistingImageRow(
                            metas: _existingImageMetas,
                            imageService: TraceImageService(
                                context.read<ConnectionProvider>()),
                            onRemove: (i) => setState(
                                () => _existingImageMetas.removeAt(i)),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // 新选图片预览
                        if (_images.isNotEmpty) ...[
                          _ImagePreviewRow(
                              images: _images, onRemove: _removeImage),
                          const SizedBox(height: 20),
                        ],

                        // GPS 卡片
                        if (_gpsPosition != null) ...[
                          _GpsCard(
                            position: _gpsPosition!,
                            onRemove: () =>
                                setState(() => _gpsPosition = null),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // 标签
                        if (_selectedTags.isNotEmpty) ...[
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _selectedTags
                                .map((t) => _SelectedTagChip(
                                      tag: t,
                                      onRemove: () => _removeTag(t),
                                    ))
                                .toList(),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // 标题
                        TextField(
                          controller: _titleCtrl,
                          focusNode: _titleFocus,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A2E),
                            letterSpacing: -0.3,
                          ),
                          decoration: const InputDecoration(
                            hintText: '标题',
                            hintStyle: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFD0D0D8),
                              letterSpacing: -0.3,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 0, vertical: 6),
                          ),
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => FocusScope.of(context)
                              .requestFocus(_contentFocus),
                        ),

                        const SizedBox(height: 4),
                        Container(
                          height: 2,
                          width: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A6CF7)
                                .withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 内容
                        TextField(
                          controller: _contentCtrl,
                          focusNode: _contentFocus,
                          maxLines: null,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF444455),
                            height: 1.8,
                          ),
                          decoration: const InputDecoration(
                            hintText: '写点什么...',
                            hintStyle: TextStyle(
                              fontSize: 15,
                              color: Color(0xFFD0D0D8),
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 0, vertical: 4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          _Toolbar(
            onPickImage: _pickImages,
            onInsertBid: _showInsertBidDialog,
            onGps: _fetchingGps ? null : _fetchGps,
            fetchingGps: _fetchingGps,
            onTag: _showTagPicker,
          ),
        ],
      ),
    );
  }

  Future<void> _onSave() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();

    print('=== _onSave called, title=$title, content=$content, images=${_images.length}, gps=$_gpsPosition');

    if (title.isEmpty && content.isEmpty && _images.isEmpty && _gpsPosition == null) {
      print('=== 内容为空，直接关闭 ===');
      Navigator.pop(context);
      return;
    }

    final connProvider = context.read<ConnectionProvider>();
    print('=== hasActiveConnection: ${connProvider.hasActiveConnection}');
    if (!connProvider.hasActiveConnection) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先配置节点连接')),
      );
      return;
    }

    setState(() { _saving = true; });

    try {
      final service = TraceService(connProvider);
      await service.saveTrace(
        title: title,
        content: content,
        tags: List.from(_selectedTags),
        images: _images.map((x) => File(x.path)).toList(),
        existingImageBids: _existingImageMetas
            .map((m) => m.bid ?? m.cid) // 优先用原始 bid
            .toList(),
        latitude: _gpsPosition?.latitude,
        longitude: _gpsPosition?.longitude,
        addTime: widget.initialAddTime,
        existingBid: widget.existingBid,
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      print('=== saveTrace error: $e');
      if (mounted) {
        setState(() { _saving = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败：$e'),
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: '知道了',
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }
}

// ── GPS 卡片 ──────────────────────────────────────────────────

class _GpsCard extends StatelessWidget {
  final _GpsData position;
  final VoidCallback onRemove;

  const _GpsCard({required this.position, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF4A6CF7).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF4A6CF7).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_on_rounded,
                size: 18, color: Color(0xFF4A6CF7)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('当前位置',
                    style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF4A6CF7),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4)),
                const SizedBox(height: 2),
                Text(
                  '${position.latitude.toStringAsFixed(6)},  ${position.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded,
                  size: 14, color: Color(0xFF666680)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 图片横向预览 ──────────────────────────────────────────────

class _ImagePreviewRow extends StatelessWidget {
  final List<XFile> images;
  final void Function(int) onRemove;

  const _ImagePreviewRow({required this.images, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) => Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(images[index].path),
                width: 110,
                height: 110,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              left: 0,
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: () => onRemove(index),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded,
                      size: 13, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 底部工具栏 ────────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  final VoidCallback onPickImage;
  final VoidCallback onInsertBid;
  final VoidCallback? onGps;
  final bool fetchingGps;
  final VoidCallback onTag;

  const _Toolbar({
    required this.onPickImage,
    required this.onInsertBid,
    required this.onGps,
    required this.fetchingGps,
    required this.onTag,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      color: const Color(0xFFF5F6FA),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: bottomInset > 0 ? 8 : bottomPadding + 10,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 24,
              offset: const Offset(0, -4),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          children: [
            _ToolbarBtn(
                icon: Icons.upload_rounded,
                label: '上传图片',
                onTap: onPickImage),
            _ToolbarBtn(
                icon: Icons.image_search_rounded,
                label: '插入图片',
                onTap: onInsertBid),
            _ToolbarBtn(
                icon: Icons.location_on_rounded,
                label: 'GPS',
                onTap: onGps ?? () {},
                loading: fetchingGps),
            _ToolbarBtn(
                icon: Icons.label_rounded,
                label: '标签',
                onTap: onTag),
          ],
        ),
      ),
    );
  }
}

class _ToolbarBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool loading;

  const _ToolbarBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF4A6CF7)),
                  )
                : Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F2FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon,
                        size: 20, color: const Color(0xFF4A6CF7)),
                  ),
          ),
        ),
      ),
    );
  }
}

// ── 已选标签 Chip ─────────────────────────────────────────────

class _SelectedTagChip extends StatelessWidget {
  final String tag;
  final VoidCallback onRemove;

  const _SelectedTagChip({required this.tag, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onRemove,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F2FF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '# $tag',
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF4A6CF7),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ── 标签选择 Sheet ────────────────────────────────────────────

class _TagPickerSheet extends StatefulWidget {
  final List<String> selectedTags;
  final void Function(String) onAdd;

  const _TagPickerSheet({
    required this.selectedTags,
    required this.onAdd,
  });

  @override
  State<_TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends State<_TagPickerSheet> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 直接在 build 里 watch，数据加载完自动刷新
    final allTags = context.watch<TagProvider>().tags;
    final query = _ctrl.text.trim().toLowerCase();
    final suggestions = allTags
        .where((t) =>
            !widget.selectedTags.contains(t) &&
            (query.isEmpty || t.toLowerCase().contains(query)))
        .toList();

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                style: const TextStyle(
                    fontSize: 15, color: Color(0xFF1A1A2E)),
                decoration: InputDecoration(
                  hintText: '输入或选择标签',
                  hintStyle: const TextStyle(color: Color(0xFFCCCCCC)),
                  prefixIcon: const Icon(Icons.label_rounded,
                      size: 18, color: Color(0xFF4A6CF7)),
                  filled: true,
                  fillColor: const Color(0xFFF5F6FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                  suffixIcon: _ctrl.text.trim().isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.add_rounded,
                              color: Color(0xFF4A6CF7)),
                          onPressed: () => widget.onAdd(_ctrl.text),
                        )
                      : null,
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) widget.onAdd(v);
                },
              ),
            ),
            const SizedBox(height: 8),
            if (suggestions.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  itemCount: suggestions.length,
                  itemBuilder: (_, i) => InkWell(
                    onTap: () => widget.onAdd(suggestions[i]),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 11),
                      child: Row(
                        children: [
                          const Icon(Icons.label_rounded,
                              size: 15, color: Color(0xFF4A6CF7)),
                          const SizedBox(width: 10),
                          Text('# ${suggestions[i]}',
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF1A1A2E))),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ── 已有图片横向预览 ──────────────────────────────────────────

class _ExistingImageRow extends StatelessWidget {
  final List<ImageMeta> metas;
  final TraceImageService imageService;
  final void Function(int) onRemove;

  const _ExistingImageRow({
    required this.metas,
    required this.imageService,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: metas.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final meta = metas[index];
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 110,
                  height: 110,
                  child: meta.cid.isNotEmpty
                      ? TraceImage(
                          cid: meta.cid,
                          encryptionKey: meta.encryptionKey,
                          imageService: imageService,
                        )
                      : Container(
                          color: const Color(0xFFF0F0F5),
                          child: const Icon(Icons.image_outlined,
                              size: 32, color: Color(0xFFCCCCCC)),
                        ),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () => onRemove(index),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 13, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── GPS 数据类 ────────────────────────────────────────────────

class _GpsData {
  final double latitude;
  final double longitude;
  const _GpsData(this.latitude, this.longitude);
}
