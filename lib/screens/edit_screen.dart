import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/block_item.dart';
import '../core/platform_helper.dart';
import '../providers/connection_provider.dart';
import '../providers/draft_provider.dart';
import '../providers/tag_provider.dart';
import '../providers/trace_provider.dart';
import '../services/image_service.dart';
import '../services/trace_service.dart';
import '../widgets/trace_image.dart';

class EditScreen extends StatefulWidget {
  final String? initialTitle;
  final String? initialContent;
  final List<String> initialTags;
  final List<String> initialLocalImagePaths;
  final List<ImageMeta> initialImageMetas;
  final String? existingBid;
  final DateTime? initialAddTime;
  final bool initialUseManualAddTime;
  final double? initialLat;
  final double? initialLng;
  final String? draftId;

  const EditScreen({
    super.key,
    this.initialTitle,
    this.initialContent,
    this.initialTags = const [],
    this.initialLocalImagePaths = const [],
    this.initialImageMetas = const [],
    this.existingBid,
    this.initialAddTime,
    this.initialUseManualAddTime = false,
    this.initialLat,
    this.initialLng,
    this.draftId,
  });

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  final _titleFocus = FocusNode();
  final _contentFocus = FocusNode();
  final _moreButtonKey = GlobalKey();
  final List<XFile> _images = [];
  final _picker = ImagePicker();
  double _lastBottomInset = 0;
  _GpsData? _gpsPosition;
  bool _fetchingGps = false;
  late final List<String> _selectedTags;
  late final List<ImageMeta> _existingImageMetas; // 已有图片（不重新上传）
  late final List<String> _initialTags;
  late final List<String> _initialLocalImagePaths;
  late final List<String> _initialExistingImageMetaSignatures;
  late final String _initialTitle;
  late final String _initialContent;
  late final double? _initialLat;
  late final double? _initialLng;
  late final DateTime? _initialEffectiveAddTime;
  bool _useManualAddTime = false;
  DateTime? _manualAddTime;
  bool _saving = false;
  bool _saved = false;
  bool _exitHandled = false;
  DraftProvider? _draftProvider;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initialTitle ?? '');
    _contentCtrl = TextEditingController(text: widget.initialContent ?? '');
    _selectedTags = List.from(widget.initialTags);
    _existingImageMetas = List.from(widget.initialImageMetas);
    _images.addAll(widget.initialLocalImagePaths.map(XFile.new));

    _initialTitle = (widget.initialTitle ?? '').trim();
    _initialContent = (widget.initialContent ?? '').trim();
    _initialTags = List.from(widget.initialTags);
    _initialLocalImagePaths = List.from(widget.initialLocalImagePaths);
    _initialExistingImageMetaSignatures =
        widget.initialImageMetas.map(_metaSignature).toList();
    _initialLat = widget.initialLat;
    _initialLng = widget.initialLng;
    _initialEffectiveAddTime = widget.initialAddTime;
    _useManualAddTime = widget.initialUseManualAddTime;
    _manualAddTime = widget.initialAddTime ?? DateTime.now();

    // 恢复原始 GPS
    if (widget.initialLat != null && widget.initialLng != null) {
      _gpsPosition = _GpsData(widget.initialLat!, widget.initialLng!);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _draftProvider ??= context.read<DraftProvider>();
    final inset = MediaQuery.of(context).viewInsets.bottom;
    if (_lastBottomInset > 0 && inset == 0) FocusScope.of(context).unfocus();
    _lastBottomInset = inset;
  }

  @override
  void dispose() {
    _persistDraftOnDispose();
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _titleFocus.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  DateTime? get _effectiveAddTime =>
      _useManualAddTime ? _manualAddTime : widget.initialAddTime;

  DateTime? _parseManualTime(String raw) {
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2})$',
    ).firstMatch(raw.trim());
    if (match == null) return null;

    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final hour = int.parse(match.group(4)!);
    final minute = int.parse(match.group(5)!);

    if (month < 1 ||
        month > 12 ||
        day < 1 ||
        day > 31 ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }

    final parsed = DateTime(year, month, day, hour, minute);
    if (parsed.year != year ||
        parsed.month != month ||
        parsed.day != day ||
        parsed.hour != hour ||
        parsed.minute != minute) {
      return null;
    }
    return parsed;
  }

  String _formatEditableTime(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  String _buildTimeHint() {
    if (widget.initialAddTime != null) {
      return '关闭后沿用原时间';
    }
    return '关闭后保存时自动取当前时间';
  }

  RelativeRect? _buttonRelativeRect(GlobalKey key) {
    final buttonContext = key.currentContext;
    if (buttonContext == null) return null;
    final buttonBox = buttonContext.findRenderObject() as RenderBox?;
    final overlayBox = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (buttonBox == null || overlayBox == null) return null;

    final offset = buttonBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final rect = offset & buttonBox.size;
    return RelativeRect.fromRect(rect, Offset.zero & overlayBox.size);
  }

  Rect? _buttonRect(GlobalKey key) {
    final buttonContext = key.currentContext;
    if (buttonContext == null) return null;
    final box = buttonContext.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final offset = box.localToGlobal(Offset.zero);
    return offset & box.size;
  }

  Future<void> _showMoreMenu() async {
    if (_saving) return;
    final position = _buttonRelativeRect(_moreButtonKey);
    if (position == null) return;

    final action = await showMenu<String>(
      context: context,
      position: position,
      color: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: [
        PopupMenuItem<String>(
          value: 'edit_time',
          padding: EdgeInsets.zero,
          child: _PopoverMenuCard(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A6CF7).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.access_time_rounded,
                    size: 16,
                    color: Color(0xFF4A6CF7),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  '修改时间',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF2F6FF),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (action == 'edit_time' && mounted) {
      await _showEditTimePopover();
    }
  }

  Future<void> _showEditTimePopover() async {
    final anchorRect = _buttonRect(_moreButtonKey);
    if (anchorRect == null) return;

    final result = await showGeneralDialog<_EditTimeResult>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭修改时间',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (_, __, ___) => _AnchoredPopoverLayout(
        anchorRect: anchorRect,
        estimatedHeight: _useManualAddTime ? 250 : 192,
        child: _EditTimePopover(
          initialUseManualAddTime: _useManualAddTime,
          initialManualAddTime:
              _manualAddTime ?? widget.initialAddTime ?? DateTime.now(),
          originalAddTime: widget.initialAddTime,
          autoHint: _buildTimeHint(),
          formatTime: _formatEditableTime,
          parseTime: _parseManualTime,
        ),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            alignment: Alignment.topRight,
            child: child,
          ),
        );
      },
    );

    if (result == null || !mounted) return;
    setState(() {
      _useManualAddTime = result.useManualAddTime;
      if (result.manualAddTime != null) {
        _manualAddTime = result.manualAddTime;
      }
    });
  }

  Future<void> _pickImages() async {
    try {
      if (PlatformHelper.isMacOS) {
        final picked = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );
        if (picked != null && mounted) {
          setState(() => _images.add(picked));
        }
        return;
      }

      final picked = await _picker.pickMultiImage(imageQuality: 85);
      if (picked.isNotEmpty && mounted) {
        setState(() => _images.addAll(picked));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('打开图片选择失败：$e')),
      );
    }
  }

  void _removeImage(int index) => setState(() => _images.removeAt(index));

  Future<void> _fetchGps() async {
    setState(() => _fetchingGps = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('系统定位服务未开启，请先在系统设置中打开定位服务')),
          );
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('位置权限被拒绝，请在系统设置里允许本应用访问定位')),
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
    final isMacOS = PlatformHelper.isMacOS;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isMacOS ? const Color(0xFF232841) : null,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '插入图片 BID',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isMacOS ? const Color(0xFFF2F6FF) : null,
          ),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(
            color: isMacOS ? const Color(0xFFF2F6FF) : null,
          ),
          cursorColor: isMacOS ? const Color(0xFF8DA6FF) : null,
          decoration: InputDecoration(
            hintText: '输入图片 BID',
            hintStyle: TextStyle(
              color: isMacOS ? const Color(0xFF7E8AAF) : null,
            ),
            filled: true,
            fillColor: isMacOS
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFF5F6FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isMacOS
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.transparent,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isMacOS
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.transparent,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isMacOS
                    ? const Color(0xFF8DA6FF).withValues(alpha: 0.7)
                    : const Color(0xFF4A6CF7),
              ),
            ),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              '取消',
              style: TextStyle(
                color: isMacOS ? const Color(0xFFAFBAD8) : null,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4A6CF7),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('插入'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMacOS = PlatformHelper.isMacOS;
    final bgColor = isMacOS ? const Color(0xFF1A1A2E) : const Color(0xFFF5F6FA);

    return WillPopScope(
      onWillPop: () async {
        await _onExitWithoutSaving();
        return false;
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isMacOS
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.black.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.close_rounded,
              size: 18,
              color: isMacOS ? const Color(0xFFF2F6FF) : const Color(0xFF1A1A2E),
            ),
          ),
          onPressed: _onExitWithoutSaving,
        ),
        title: null,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: IconButton(
              key: _moreButtonKey,
              onPressed: _showMoreMenu,
              icon: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isMacOS
                      ? Colors.white.withValues(alpha: 0.10)
                      : Colors.black.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.more_horiz_rounded,
                  size: 18,
                  color: isMacOS
                      ? const Color(0xFFF2F6FF)
                      : const Color(0xFF1A1A2E),
                ),
              ),
            ),
          ),
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
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: isMacOS
                                ? const Color(0xFFF2F6FF)
                                : const Color(0xFF1A1A2E),
                            letterSpacing: -0.3,
                          ),
                          decoration: InputDecoration(
                            hintText: '标题',
                            hintStyle: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: isMacOS
                                  ? const Color(0xFF6C7897)
                                  : const Color(0xFFD0D0D8),
                              letterSpacing: -0.3,
                            ),
                            border: const UnderlineInputBorder(
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
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
                          style: TextStyle(
                            fontSize: 15,
                            color: isMacOS
                                ? const Color(0xFFBCC8E4)
                                : const Color(0xFF444455),
                            height: 1.8,
                          ),
                          decoration: InputDecoration(
                            hintText: '写点什么...',
                            hintStyle: TextStyle(
                              fontSize: 15,
                              color: isMacOS
                                  ? const Color(0xFF6C7897)
                                  : const Color(0xFFD0D0D8),
                            ),
                            border: const UnderlineInputBorder(
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
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
      ),
    );
  }

  Future<void> _onExitWithoutSaving() async {
    if (_saving || _saved || _exitHandled) return;
    _exitHandled = true;

    final hasAnyContent = _hasAnyContent();

    final draftProvider = _draftProvider ?? context.read<DraftProvider>();
    if (!hasAnyContent) {
      if (widget.draftId != null) {
        await draftProvider.remove(widget.draftId!);
      }
      if (mounted) Navigator.pop(context, false);
      return;
    }

    if (_isDirty() || widget.draftId != null) {
      await draftProvider.upsert(_buildDraft(draftProvider));
    }

    if (mounted) {
      Navigator.pop(context, false);
    }
  }

  bool _hasAnyContent() =>
      _titleCtrl.text.trim().isNotEmpty ||
      _contentCtrl.text.trim().isNotEmpty ||
      _selectedTags.isNotEmpty ||
      _images.isNotEmpty ||
      _existingImageMetas.isNotEmpty ||
      _gpsPosition != null;

  TraceDraft _buildDraft(DraftProvider draftProvider) {
    final draftId = _resolveDraftId(draftProvider);
    return _buildDraftWithId(draftId: draftId);
  }

  String _resolveDraftId(DraftProvider draftProvider) {
    if (widget.draftId != null && widget.draftId!.isNotEmpty) {
      return widget.draftId!;
    }
    final existing = draftProvider.findLatestByExistingBid(widget.existingBid);
    if (existing != null) return existing.id;
    return draftProvider.newDraftId();
  }

  TraceDraft _buildDraftWithId({required String draftId}) {
    return TraceDraft(
      id: draftId,
      title: _titleCtrl.text.trim(),
      content: _contentCtrl.text.trim(),
      tags: List.from(_selectedTags),
      localImagePaths: _images.map((e) => e.path).toList(),
      existingImageMetas: List.from(_existingImageMetas),
      existingBid: widget.existingBid,
      initialAddTime: _effectiveAddTime,
      useManualAddTime: _useManualAddTime,
      lat: _gpsPosition?.latitude,
      lng: _gpsPosition?.longitude,
      updatedAt: DateTime.now(),
    );
  }

  void _persistDraftOnDispose() {
    if (_saved || _saving || _exitHandled) return;
    final draftProvider = _draftProvider;
    if (draftProvider == null) return;

    if (!_hasAnyContent()) {
      if (widget.draftId != null) {
        draftProvider.remove(widget.draftId!);
      }
      return;
    }

    if (_isDirty() || widget.draftId != null) {
      draftProvider.upsert(_buildDraft(draftProvider));
    }
  }

  bool _isDirty() {
    final currentTitle = _titleCtrl.text.trim();
    final currentContent = _contentCtrl.text.trim();
    final currentLocalImagePaths = _images.map((e) => e.path).toList();
    final currentMetaSignatures = _existingImageMetas.map(_metaSignature).toList();
    final currentLat = _gpsPosition?.latitude;
    final currentLng = _gpsPosition?.longitude;
    final currentAddTimeMs = _effectiveAddTime?.millisecondsSinceEpoch;
    final initialAddTimeMs = _initialEffectiveAddTime?.millisecondsSinceEpoch;

    return currentTitle != _initialTitle ||
        currentContent != _initialContent ||
        !listEquals(_selectedTags, _initialTags) ||
        !listEquals(currentLocalImagePaths, _initialLocalImagePaths) ||
        !listEquals(currentMetaSignatures, _initialExistingImageMetaSignatures) ||
        currentAddTimeMs != initialAddTimeMs ||
        currentLat != _initialLat ||
        currentLng != _initialLng;
  }

  String _metaSignature(ImageMeta meta) =>
      '${meta.cid}|${meta.encryptionKey ?? ''}|${meta.bid ?? ''}';

  Future<void> _onSave() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    DateTime? addTime = widget.initialAddTime;

    if (_useManualAddTime) {
      addTime = _manualAddTime;
    }

    print('=== _onSave called, title=$title, content=$content, images=${_images.length}, gps=$_gpsPosition');

    if (title.isEmpty &&
        content.isEmpty &&
        _selectedTags.isEmpty &&
        _images.isEmpty &&
        _existingImageMetas.isEmpty &&
        _gpsPosition == null) {
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

    final draftProvider = context.read<DraftProvider>();
    final traceProvider = context.read<TraceProvider>();
    final draftId = _resolveDraftId(draftProvider);
    final images = _images.map((x) => File(x.path)).toList();
    final existingImageBids =
        _existingImageMetas.map((m) => m.bid ?? m.cid).toList();

    await draftProvider.upsert(_buildDraftWithId(draftId: draftId));
    await draftProvider.markSavingStart(id: draftId, uploadTotal: images.length);
    if (mounted) {
      setState(() => _saving = true);
    }

    _saved = true;
    _exitHandled = true;

    unawaited(
      _saveInBackground(
        draftId: draftId,
        draftProvider: draftProvider,
        traceProvider: traceProvider,
        connProvider: connProvider,
        title: title,
        content: content,
        tags: List.from(_selectedTags),
        images: images,
        existingImageBids: existingImageBids,
        latitude: _gpsPosition?.latitude,
        longitude: _gpsPosition?.longitude,
        addTime: addTime,
      ),
    );

    if (mounted) {
      Navigator.pop(context, false);
    }
  }

  Future<void> _saveInBackground({
    required String draftId,
    required DraftProvider draftProvider,
    required TraceProvider traceProvider,
    required ConnectionProvider connProvider,
    required String title,
    required String content,
    required List<String> tags,
    required List<File> images,
    required List<String> existingImageBids,
    required double? latitude,
    required double? longitude,
    required DateTime? addTime,
  }) async {
    try {
      final service = TraceService(connProvider);
      await service.saveTrace(
        title: title,
        content: content,
        tags: tags,
        images: images,
        existingImageBids: existingImageBids,
        latitude: latitude,
        longitude: longitude,
        addTime: addTime,
        existingBid: widget.existingBid,
        onImageProgress: ({
          required int total,
          required int completed,
          int? uploadingIndex,
          required bool fromCache,
        }) {
          draftProvider.markSavingProgress(
            id: draftId,
            completed: completed,
            total: total,
            uploadingIndex: uploadingIndex,
          );
        },
      );
      await draftProvider.remove(draftId);
      await traceProvider.refresh();
    } catch (e) {
      print('=== saveTrace error: $e');
      await draftProvider.markSavingFailed(
        id: draftId,
        error: e.toString(),
      );
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
    final isMacOS = PlatformHelper.isMacOS;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMacOS
            ? Colors.white.withValues(alpha: 0.07)
            : const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: (isMacOS
                    ? Colors.white
                    : const Color(0xFF4A6CF7))
                .withValues(alpha: isMacOS ? 0.16 : 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF4A6CF7)
                  .withValues(alpha: isMacOS ? 0.18 : 0.12),
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
                Text('当前位置',
                    style: TextStyle(
                        fontSize: 11,
                        color: isMacOS ? Color(0xFF8DA6FF) : Color(0xFF4A6CF7),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4)),
                const SizedBox(height: 2),
                Text(
                  '${position.latitude.toStringAsFixed(6)},  ${position.longitude.toStringAsFixed(6)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isMacOS ? Color(0xFFEAF0FF) : Color(0xFF1A1A2E),
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
                color: isMacOS
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: isMacOS ? const Color(0xFFAFBAD8) : const Color(0xFF666680),
              ),
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

class _EditTimeResult {
  final bool useManualAddTime;
  final DateTime? manualAddTime;

  const _EditTimeResult({
    required this.useManualAddTime,
    required this.manualAddTime,
  });
}

class _AnchoredPopoverLayout extends StatelessWidget {
  final Rect anchorRect;
  final double estimatedHeight;
  final Widget child;

  const _AnchoredPopoverLayout({
    required this.anchorRect,
    required this.estimatedHeight,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    const width = 320.0;
    const margin = 12.0;
    const gap = 8.0;
    final media = MediaQuery.of(context);
    final maxLeft = media.size.width - width - margin;
    final left = (anchorRect.right - width).clamp(margin, maxLeft);
    final spaceBelow = media.size.height - media.padding.bottom - anchorRect.bottom;
    final showBelow = spaceBelow >= estimatedHeight + gap + margin;
    final top = showBelow
        ? anchorRect.bottom + gap
        : (anchorRect.top - estimatedHeight - gap).clamp(
            media.padding.top + margin,
            media.size.height - estimatedHeight - margin,
          );

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          width: width,
          child: child,
        ),
      ],
    );
  }
}

class _PopoverMenuCard extends StatelessWidget {
  final Widget child;

  const _PopoverMenuCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF232841).withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _EditTimePopover extends StatefulWidget {
  final bool initialUseManualAddTime;
  final DateTime initialManualAddTime;
  final DateTime? originalAddTime;
  final String autoHint;
  final String Function(DateTime dt) formatTime;
  final DateTime? Function(String raw) parseTime;

  const _EditTimePopover({
    required this.initialUseManualAddTime,
    required this.initialManualAddTime,
    required this.originalAddTime,
    required this.autoHint,
    required this.formatTime,
    required this.parseTime,
  });

  @override
  State<_EditTimePopover> createState() => _EditTimePopoverState();
}

class _EditTimePopoverState extends State<_EditTimePopover> {
  late bool _useManualAddTime;
  late DateTime _manualAddTime;
  late final TextEditingController _timeCtrl;
  final _timeFocus = FocusNode();
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _useManualAddTime = widget.initialUseManualAddTime;
    _manualAddTime = widget.initialManualAddTime;
    _timeCtrl = TextEditingController(text: widget.formatTime(_manualAddTime));
  }

  @override
  void dispose() {
    _timeCtrl.dispose();
    _timeFocus.dispose();
    super.dispose();
  }

  void _submit() {
    if (_useManualAddTime) {
      final parsed = widget.parseTime(_timeCtrl.text);
      if (parsed == null) {
        setState(() => _errorText = '时间格式请使用 YYYY-MM-DD HH:mm');
        _timeFocus.requestFocus();
        return;
      }
      _manualAddTime = parsed;
      _timeCtrl.text = widget.formatTime(parsed);
    }

    Navigator.of(context).pop(
      _EditTimeResult(
        useManualAddTime: _useManualAddTime,
        manualAddTime: _manualAddTime,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: BoxDecoration(
              color: const Color(0xFF232841).withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.10),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 32,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '修改时间',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFF2F6FF),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _useManualAddTime
                      ? '手动时间 ${widget.formatTime(_manualAddTime)}'
                      : (widget.originalAddTime != null
                          ? '当前为原时间 ${widget.formatTime(widget.originalAddTime!)}'
                          : '当前为自动时间'),
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color(0xFF9BA9CC),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      _SegmentButton(
                        label: '自动',
                        selected: !_useManualAddTime,
                        onTap: () => setState(() {
                          _useManualAddTime = false;
                          _errorText = null;
                        }),
                      ),
                      const SizedBox(width: 6),
                      _SegmentButton(
                        label: '手动',
                        selected: _useManualAddTime,
                        onTap: () => setState(() {
                          _useManualAddTime = true;
                          _errorText = null;
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_useManualAddTime) ...[
                  TextField(
                    controller: _timeCtrl,
                    focusNode: _timeFocus,
                    autofocus: true,
                    keyboardType: TextInputType.datetime,
                    style: TextStyle(
                      color: const Color(0xFFF2F6FF),
                    ),
                    decoration: InputDecoration(
                      hintText: 'YYYY-MM-DD HH:mm',
                      errorText: _errorText,
                      helperText: '统一格式：YYYY-MM-DD HH:mm',
                      hintStyle: const TextStyle(color: Color(0xFF8E9CBE)),
                      helperStyle: const TextStyle(color: Color(0xFF8E9CBE)),
                      errorStyle: const TextStyle(color: Color(0xFFFF8F8F)),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: Color(0xFF8DA6FF)),
                      ),
                    ),
                    onChanged: (_) {
                      if (_errorText != null) {
                        setState(() => _errorText = null);
                      }
                    },
                    onSubmitted: (_) => _submit(),
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      widget.autoHint,
                      style: TextStyle(
                        fontSize: 13,
                        color: const Color(0xFFD5DDF5),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        '取消',
                        style: TextStyle(
                          color: const Color(0xFFAFBAD8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF4A6CF7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('完成'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected
                  ? const Color(0xFFF2F6FF)
                  : const Color(0xFF97A6CB),
            ),
          ),
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
    final isMacOS = PlatformHelper.isMacOS;

    return Container(
      color: isMacOS ? const Color(0xFF1A1A2E) : const Color(0xFFF5F6FA),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: bottomInset > 0 ? 8 : bottomPadding + 10,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isMacOS
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: isMacOS
              ? Border.all(color: Colors.white.withValues(alpha: 0.14))
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isMacOS ? 0.22 : 0.07),
              blurRadius: isMacOS ? 20 : 24,
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
    final isMacOS = PlatformHelper.isMacOS;
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
                      color: isMacOS
                          ? Colors.white.withValues(alpha: 0.12)
                          : const Color(0xFFF0F2FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon,
                        size: 20,
                        color: isMacOS
                            ? const Color(0xFF8DA6FF)
                            : const Color(0xFF4A6CF7)),
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
    final isMacOS = PlatformHelper.isMacOS;
    return GestureDetector(
      onLongPress: onRemove,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isMacOS
              ? Colors.white.withValues(alpha: 0.10)
              : const Color(0xFFF0F2FF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '# $tag',
          style: TextStyle(
            fontSize: 11,
            color: isMacOS ? const Color(0xFF9EB5FF) : const Color(0xFF4A6CF7),
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
    final isMacOS = PlatformHelper.isMacOS;
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
        decoration: BoxDecoration(
          color: isMacOS ? const Color(0xFF232841) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 12),
              decoration: BoxDecoration(
                color: isMacOS
                    ? Colors.white.withValues(alpha: 0.20)
                    : Colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                style: TextStyle(
                    fontSize: 15,
                    color: isMacOS ? const Color(0xFFF2F6FF) : const Color(0xFF1A1A2E)),
                decoration: InputDecoration(
                  hintText: '输入或选择标签',
                  hintStyle: TextStyle(
                    color: isMacOS ? const Color(0xFF7986A7) : const Color(0xFFCCCCCC),
                  ),
                  prefixIcon: const Icon(Icons.label_rounded,
                      size: 18, color: Color(0xFF4A6CF7)),
                  filled: true,
                  fillColor: isMacOS
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFF5F6FA),
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
                              style: TextStyle(
                                  fontSize: 14,
                                  color: isMacOS
                                      ? const Color(0xFFF2F6FF)
                                      : const Color(0xFF1A1A2E))),
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
    final isMacOS = PlatformHelper.isMacOS;
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
                          color: isMacOS
                              ? Colors.white.withValues(alpha: 0.08)
                              : const Color(0xFFF0F0F5),
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
