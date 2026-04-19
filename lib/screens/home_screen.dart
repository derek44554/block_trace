import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:block_flutter/block_flutter.dart';
import '../core/platform_helper.dart';
import '../models/block_item.dart';
import '../providers/connection_provider.dart';
import '../providers/draft_provider.dart';
import '../providers/tag_provider.dart';
import '../providers/trace_provider.dart';
import '../services/image_service.dart';
import '../widgets/gps_card.dart';
import '../widgets/image_card.dart';
import '../widgets/rich_card.dart';
import 'about_screen.dart';
import 'detail_screen.dart';
import 'edit_screen.dart';
import 'setup_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (PlatformHelper.isMacOS) {
      return const _MacHomeScreen();
    }
    return const _MobileHomeScreen();
  }
}

// ─────────────────────────────────────────────────────────────
// macOS 版本：左侧标签筛选 + 右侧内容
// ─────────────────────────────────────────────────────────────

class _MacHomeScreen extends StatefulWidget {
  const _MacHomeScreen();

  @override
  State<_MacHomeScreen> createState() => _MacHomeScreenState();
}

class _MacHomeScreenState extends State<_MacHomeScreen> {
  final GlobalKey<NavigatorState> _contentNavigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _overviewNavigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _draftNavigatorKey =
      GlobalKey<NavigatorState>();
  _SidebarView _view = _SidebarView.timeline;

  Future<void> _openCreate() async {
    final result = await _contentNavigatorKey.currentState?.push<bool>(
      MaterialPageRoute(builder: (_) => const EditScreen()),
    );
    if (result == true && mounted) {
      context.read<TraceProvider>().refresh();
    }
  }

  void _openDetail(BlockModel block) {
    final imageService = TraceImageService(context.read<ConnectionProvider>());
    _contentNavigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => DetailScreen(block: block, imageService: imageService),
      ),
    );
  }

  void _openOverview() {
    setState(() => _view = _SidebarView.overview);
    _overviewNavigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  void _showTimeline() {
    setState(() => _view = _SidebarView.timeline);
    _contentNavigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  void _showDrafts() {
    setState(() => _view = _SidebarView.drafts);
    _draftNavigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 900;
          final menuWidth = isCompact ? 160.0 : 200.0;

          return Padding(
            padding: EdgeInsets.fromLTRB(
              isCompact ? 4 : 6,
              6,
              isCompact ? 4 : 6,
              isCompact ? 4 : 6,
            ),
            child: Row(
              children: [
                // Sidebar (draggable area)
                SizedBox(
                  width: menuWidth,
                  child: _MacSidebar(
                    isCompact: isCompact,
                    currentView: _view,
                    onCreate: _openCreate,
                    onOverview: _openOverview,
                    onShowDrafts: _showDrafts,
                    onShowTimeline: _showTimeline,
                  ),
                ),
                SizedBox(width: isCompact ? 8 : 12),
                Expanded(
                  child: _MacContentArea(
                    isCompact: isCompact,
                    currentView: _view,
                    overviewNavigatorKey: _overviewNavigatorKey,
                    draftNavigatorKey: _draftNavigatorKey,
                    navigatorKey: _contentNavigatorKey,
                    onOpenDetail: _openDetail,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

enum _SidebarView { timeline, overview, drafts }

// ─────────────────────────────────────────────────────────────
// macOS 侧边栏：全部 + 标签列表 + 设置
// ─────────────────────────────────────────────────────────────

class _MacSidebar extends StatefulWidget {
  final bool isCompact;
  final _SidebarView currentView;
  final Future<void> Function() onCreate;
  final VoidCallback onOverview;
  final VoidCallback onShowDrafts;
  final VoidCallback onShowTimeline;

  const _MacSidebar({
    required this.isCompact,
    required this.currentView,
    required this.onCreate,
    required this.onOverview,
    required this.onShowDrafts,
    required this.onShowTimeline,
  });

  @override
  State<_MacSidebar> createState() => _MacSidebarState();
}

class _MacSidebarState extends State<_MacSidebar> {
  bool _publishHovered = false;
  bool _publishPressed = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        6,
        widget.isCompact ? 4 : 4,
        6,
        widget.isCompact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          // 仅顶部区域可拖拽窗口，避免菜单点击被拖拽手势延迟
          const DragToMoveArea(
            child: SizedBox(
              height: 28,
              width: double.infinity,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _OverviewCard(
              onTap: widget.onOverview,
              selected: widget.currentView == _SidebarView.overview,
            ),
          ),
          // 痕迹 + 添加按钮
          Padding(
            padding: const EdgeInsets.only(bottom: 4, top: 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '痕迹',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white54,
                    letterSpacing: 0.5,
                  ),
                ),
                GestureDetector(
                  onTap: _showAddTagDialog,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          Consumer<DraftProvider>(
            builder: (context, draftProvider, _) {
              if (draftProvider.drafts.isEmpty) {
                return const SizedBox.shrink();
              }
              return Column(
                children: [
                  _MacSidebarItem(
                    icon: Icons.edit_note_rounded,
                    label: '未保存 (${draftProvider.drafts.length})',
                    selected: widget.currentView == _SidebarView.drafts,
                    onTap: widget.onShowDrafts,
                  ),
                  const SizedBox(height: 2),
                ],
              );
            },
          ),

          // 全部痕迹按钮
          _MacSidebarItem(
            icon: Icons.all_inclusive_rounded,
            label: '全部痕迹',
            isAll: true,
            selected: widget.currentView == _SidebarView.timeline &&
                context.watch<TraceProvider>().activeTag == null,
            onAfterSelect: widget.onShowTimeline,
          ),
          const SizedBox(height: 2),

          // 标签列表（可滚动）
          Expanded(
            child: Consumer<TagProvider>(
              builder: (context, tagProvider, _) {
                final tags = tagProvider.tags;
                if (tags.isEmpty) {
                  return const SizedBox.shrink();
                }
                return ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: tags.length,
                  itemBuilder: (context, index) {
                    final tag = tags[index];
                    return _MacTagItem(
                      tag: tag,
                      selected: widget.currentView == _SidebarView.timeline &&
                          context.watch<TraceProvider>().activeTag == tag,
                      onAfterSelect: widget.onShowTimeline,
                    );
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 6),

          // 发布按钮
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(
                0,
                _publishPressed ? 1.5 : (_publishHovered ? -1.5 : 0),
                0,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: widget.onCreate,
                      onHover: (v) {
                        if (_publishHovered != v) {
                          setState(() => _publishHovered = v);
                        }
                      },
                      onHighlightChanged: (v) {
                        if (_publishPressed != v) {
                          setState(() => _publishPressed = v);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _publishHovered
                                ? Colors.white.withValues(alpha: 0.40)
                                : Colors.white.withValues(alpha: 0.26),
                            width: 1,
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(
                                alpha: _publishHovered ? 0.26 : 0.18,
                              ),
                              const Color(0xFF8AA6FF).withValues(
                                alpha: _publishHovered ? 0.20 : 0.14,
                              ),
                              const Color(0xFF5E7EFA).withValues(
                                alpha: _publishHovered ? 0.24 : 0.16,
                              ),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: _publishHovered ? 0.22 : 0.15,
                              ),
                              blurRadius: _publishHovered ? 18 : 12,
                              offset: Offset(0, _publishHovered ? 8 : 5),
                            ),
                            BoxShadow(
                              color: const Color(0xFF89A1FF).withValues(
                                alpha: _publishHovered ? 0.20 : 0.12,
                              ),
                              blurRadius: _publishHovered ? 20 : 15,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOut,
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: const Color(0xFFBFD0FF).withValues(
                                  alpha: _publishHovered ? 0.26 : 0.18,
                                ),
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(
                                  color: Colors.white.withValues(
                                    alpha: _publishHovered ? 0.36 : 0.24,
                                  ),
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.add_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '发布',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

        ],
      ),
    );
  }

  void _showAddTagDialog() {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('添加标签'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入标签名称',
            prefixText: '# ',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onSubmitted: (v) {
            context.read<TagProvider>().addTag(v);
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              context.read<TagProvider>().addTag(ctrl.text);
              Navigator.pop(context);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final VoidCallback onTap;
  final bool selected;

  const _OverviewCard({required this.onTap, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: selected
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF7278FF), Color(0xFF8A5DF1)],
                  )
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF5E62C8), Color(0xFF755DB5)],
                  ),
            border: Border.all(
              color: selected
                  ? Colors.white.withValues(alpha: 0.42)
                  : Colors.white.withValues(alpha: 0.06),
              width: 1.1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF5660FF).withValues(alpha: 0.32),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : const [],
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '概括',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    selected ? '当前正在查看' : '点击查看入口面板',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.82),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (selected)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      '选中',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewPlaceholderPage extends StatelessWidget {
  const _OverviewPlaceholderPage();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF6C70FF).withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: -30,
            bottom: -50,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF8A5DF1).withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 34, 28, 28),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '概括',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '把常用入口放在这里，右侧内容区保持专注。',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.62),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _OverviewEntryTile(
                    icon: Icons.dns_rounded,
                    accent: const Color(0xFF4A6CF7),
                    title: '节点设置',
                    subtitle: '管理 Block 节点与 IPFS 连接',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SetupScreen()),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _OverviewEntryTile(
                    icon: Icons.info_outline_rounded,
                    accent: const Color(0xFF8A5DF1),
                    title: '关于',
                    subtitle: '版本、作者与项目说明',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutScreen()),
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

class _OverviewEntryTile extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OverviewEntryTile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 22, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Colors.white.withValues(alpha: 0.68),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Colors.white.withValues(alpha: 0.38),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// macOS 侧边栏项：全部 / 设置
// ─────────────────────────────────────────────────────────────

class _MacSidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isAll;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onAfterSelect;

  const _MacSidebarItem({
    required this.icon,
    required this.label,
    this.isAll = false,
    this.selected = false,
    this.onTap,
    this.onAfterSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (onTap != null) {
            onTap!.call();
            return;
          }
          if (isAll) {
            context.read<TraceProvider>().setTag(null);
            onAfterSelect?.call();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected
                ? const Color(0xFF4A6CF7).withValues(alpha: 0.15)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? const Color(0xFF4A6CF7)
                    : Colors.white.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected
                        ? const Color(0xFF4A6CF7)
                        : Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// macOS 标签项
// ─────────────────────────────────────────────────────────────

class _MacTagItem extends StatelessWidget {
  final String tag;
  final bool selected;
  final VoidCallback? onAfterSelect;

  const _MacTagItem({
    required this.tag,
    required this.selected,
    this.onAfterSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
          child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            context.read<TraceProvider>().setTag(selected ? null : tag);
            onAfterSelect?.call();
          },
          onLongPress: () => _showTagOptions(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: selected
                  ? const Color(0xFF4A6CF7).withValues(alpha: 0.15)
                  : Colors.transparent,
            ),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF4A6CF7)
                        : const Color(0xFFF0F2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.label_rounded,
                    size: 14,
                    color: selected ? Colors.white : const Color(0xFF4A6CF7),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '# $tag',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: selected
                          ? const Color(0xFF4A6CF7)
                          : Colors.white.withValues(alpha: 0.8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: Color(0xFF4A6CF7),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTagOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Text(
                  '# $tag',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9E9E9E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: Colors.red,
                  ),
                ),
                title: const Text(
                  '删除标签',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.red,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmRemoveTag(context);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmRemoveTag(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('删除标签'),
        content: Text('确定要删除标签「$tag」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              context.read<TagProvider>().removeTag(tag);
              if (context.read<TraceProvider>().activeTag == tag) {
                context.read<TraceProvider>().setTag(null);
              }
              Navigator.pop(context);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// macOS 添加标签按钮
// ─────────────────────────────────────────────────────────────

class _MacAddTagButton extends StatelessWidget {
  const _MacAddTagButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showAddTagDialog(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.add_rounded,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '添加标签',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddTagDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('添加标签'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入标签名称',
            prefixText: '# ',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onSubmitted: (v) {
            context.read<TagProvider>().addTag(v);
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              context.read<TagProvider>().addTag(ctrl.text);
              Navigator.pop(context);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// macOS 内容区：发布按钮 + 列表
// ─────────────────────────────────────────────────────────────

class _MacContentArea extends StatelessWidget {
  final bool isCompact;
  final _SidebarView currentView;
  final GlobalKey<NavigatorState> overviewNavigatorKey;
  final GlobalKey<NavigatorState> draftNavigatorKey;
  final GlobalKey<NavigatorState> navigatorKey;
  final ValueChanged<BlockModel> onOpenDetail;

  const _MacContentArea({
    required this.isCompact,
    required this.currentView,
    required this.overviewNavigatorKey,
    required this.draftNavigatorKey,
    required this.navigatorKey,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isCompact ? 12 : 16),
        color: Colors.transparent,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isCompact ? 12 : 16),
              child: IndexedStack(
                index: switch (currentView) {
                  _SidebarView.overview => 0,
                  _SidebarView.drafts => 1,
                  _SidebarView.timeline => 2,
                },
                children: [
                  Navigator(
                    key: overviewNavigatorKey,
                    onGenerateRoute: (_) => MaterialPageRoute(
                      builder: (_) => const _OverviewPlaceholderPage(),
                    ),
                  ),
                  Navigator(
                    key: draftNavigatorKey,
                    onGenerateRoute: (_) => MaterialPageRoute(
                      builder: (_) => const _DraftsContent(),
                    ),
                  ),
                  Navigator(
                    key: navigatorKey,
                    onGenerateRoute: (_) => MaterialPageRoute(
                      builder: (_) => _TimelineContent(
                        isCompact: isCompact,
                        onOpenDetail: onOpenDetail,
                      ),
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

// ─────────────────────────────────────────────────────────────
// macOS 草稿列表
// ─────────────────────────────────────────────────────────────

class _DraftsContent extends StatelessWidget {
  const _DraftsContent();

  @override
  Widget build(BuildContext context) {
    return Consumer<DraftProvider>(
      builder: (context, provider, _) {
        final drafts = provider.drafts;
        if (drafts.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.note_alt_outlined,
                  size: 52,
                  color: Colors.white.withValues(alpha: 0.24),
                ),
                const SizedBox(height: 12),
                const Text(
                  '没有未保存内容',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB8C3DF),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '编辑后未保存的内容会自动出现在这里',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.46),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          itemCount: drafts.length,
          itemBuilder: (context, index) {
            final draft = drafts[index];
            final title = draft.title.trim().isEmpty ? '未命名草稿' : draft.title.trim();
            final subtitle = draft.content.trim().isEmpty
                ? '无正文'
                : draft.content.trim().replaceAll('\n', ' ');
            final uploadInfo = draft.isSaving
                ? '上传中 ${draft.uploadCompleted}/${draft.uploadTotal}'
                : (draft.saveError == null ? null : '保存失败：${draft.saveError}');
            final info =
                '${draft.tags.isNotEmpty ? '#${draft.tags.join(' #')} · ' : ''}${draft.localImagePaths.length + draft.existingImageMetas.length} 张图 · ${_formatDraftTime(draft.updatedAt)}';

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    if (draft.isSaving) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('该草稿正在上传保存中，暂时不可编辑'),
                        ),
                      );
                      return;
                    }
                    final result = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditScreen(
                          draftId: draft.id,
                          initialTitle: draft.title.isEmpty ? null : draft.title,
                          initialContent:
                              draft.content.isEmpty ? null : draft.content,
                          initialTags: draft.tags,
                          initialLocalImagePaths: draft.localImagePaths,
                          initialImageMetas: draft.existingImageMetas,
                          existingBid: draft.existingBid,
                          initialAddTime: draft.initialAddTime,
                          initialUseManualAddTime: draft.useManualAddTime,
                          initialLat: draft.lat,
                          initialLng: draft.lng,
                        ),
                      ),
                    );
                    if (result == true && context.mounted) {
                      context.read<TraceProvider>().refresh();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.white.withValues(alpha: 0.06),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: const Color(0xFF8DA6FF).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.edit_note_rounded,
                            size: 20,
                            color: Color(0xFF8DA6FF),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFEAF0FF),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: Colors.white.withValues(alpha: 0.62),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                info,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.45),
                                ),
                              ),
                              if (uploadInfo != null) ...[
                                const SizedBox(height: 5),
                                Text(
                                  draft.uploadingIndex == null
                                      ? uploadInfo
                                      : '$uploadInfo · 当前第 ${draft.uploadingIndex} 张',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: draft.isSaving
                                        ? const Color(0xFF98B1FF)
                                        : const Color(0xFFFF8A8A),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: '删除草稿',
                          visualDensity: VisualDensity.compact,
                          onPressed:
                              draft.isSaving ? null : () => provider.remove(draft.id),
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.52),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDraftTime(DateTime dt) {
    String two(int v) => v < 10 ? '0$v' : '$v';
    return '${dt.month}/${dt.day} ${two(dt.hour)}:${two(dt.minute)}';
  }
}

// ─────────────────────────────────────────────────────────────
// macOS 时间线列表
// ─────────────────────────────────────────────────────────────

class _TimelineContent extends StatefulWidget {
  final bool isCompact;
  final ValueChanged<BlockModel>? onOpenDetail;

  const _TimelineContent({required this.isCompact, this.onOpenDetail});

  @override
  State<_TimelineContent> createState() => _TimelineContentState();
}

class _TimelineContentState extends State<_TimelineContent> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 300) {
      context.read<TraceProvider>().load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TraceProvider>(
      builder: (context, provider, _) {
        if (provider.loading && provider.blocks.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF4A6CF7)),
          );
        }
        if (provider.error != null && provider.blocks.isEmpty) {
          return _buildError(provider.error!, provider);
        }
        if (provider.blocks.isEmpty) {
          return _buildEmpty();
        }
        return ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
          itemCount: provider.blocks.length + (provider.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == provider.blocks.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF4A6CF7)),
                ),
              );
            }
            final item = _blockToItem(provider.blocks[index]);
            if (item == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: GestureDetector(
                onTap: () {
                  final block = provider.blocks[index];
                  if (widget.onOpenDetail != null) {
                    widget.onOpenDetail!(block);
                    return;
                  }
                  final imageService = TraceImageService(
                    context.read<ConnectionProvider>(),
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DetailScreen(
                        block: block,
                        imageService: imageService,
                      ),
                    ),
                  );
                },
                onLongPress: () =>
                    _showCardOptions(context, provider.blocks[index]),
                child: _buildCard(item),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timeline_rounded,
            size: 56,
            color: Colors.black.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 16),
          const Text(
            '还没有记录',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF9E9E9E),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '点击右上角发布开始记录',
            style: TextStyle(fontSize: 13, color: Color(0xFFBBBBBB)),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error, TraceProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 48,
              color: Colors.black.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 16),
            const Text(
              '加载失败',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9E9E9E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFFBBBBBB)),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: provider.refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCardOptions(BuildContext context, BlockModel block) {
    final bid = block.maybeString('bid') ?? '';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF20263D).withValues(alpha: 0.96),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.36),
              blurRadius: 26,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (bid.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Text(
                    bid,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8FA6FF).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.copy_rounded,
                    size: 18,
                    color: Color(0xFF4A6CF7),
                  ),
                ),
                title: const Text(
                  '复制 BID',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFEAF0FF),
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  if (bid.isNotEmpty) {
                    Clipboard.setData(ClipboardData(text: bid));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('BID 已复制'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: Colors.red,
                  ),
                ),
                title: const Text(
                  '删除',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.red,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context, block);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, BlockModel block) {
    final bid = block.maybeString('bid') ?? '';
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('删除记录'),
        content: const Text('确定要删除这条记录吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              if (bid.isEmpty) return;
              try {
                final conn = context
                    .read<ConnectionProvider>()
                    .activeConnection;
                if (conn == null) return;
                await BlockApi(connection: conn).deleteBlock(bid: bid);
                await BlockCache.instance.remove(bid);
                if (mounted) {
                  context.read<TraceProvider>().refresh();
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('已删除')));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('删除失败：$e')));
                }
              }
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BlockItem item) {
    final imageService = TraceImageService(context.read<ConnectionProvider>());
    switch (item.type) {
      case BlockType.gps:
        return GpsCard(item: item, imageService: imageService);
      case BlockType.image:
        return ImageCard(item: item, imageService: imageService);
      case BlockType.rich:
        return RichCard(item: item, imageService: imageService);
    }
  }

  BlockItem? _blockToItem(BlockModel block) {
    final title = block.maybeString('title');
    final content = block.maybeString('content');
    final tags = block.getList<String>('tag');
    final addTime = block.getDateTime('add_time') ?? DateTime.now();
    final gps = block.getMap('gps');
    final imageList = block.getList<String>('image_list');
    final traceProvider = context.read<TraceProvider>();

    final imageMetas = imageList.map((imageBid) {
      final info = traceProvider.getImageInfo(imageBid);
      final cid = info?['cid'] ?? imageBid;
      final key = info?['key'];
      return ImageMeta(cid: cid, encryptionKey: key, bid: imageBid);
    }).toList();

    if (imageMetas.isNotEmpty) {
      if (title != null || content != null || tags.isNotEmpty) {
        return BlockItem(
          type: BlockType.rich,
          title: title,
          content: content,
          tags: tags,
          imageMetas: imageMetas,
          createdAt: addTime,
        );
      }
      return BlockItem(
        type: BlockType.image,
        tags: tags,
        imageMetas: imageMetas,
        createdAt: addTime,
      );
    }

    if (gps.isNotEmpty) {
      return BlockItem(
        type: BlockType.gps,
        title: title,
        content: content,
        tags: tags,
        lat: (gps['latitude'] as num?)?.toDouble(),
        lng: (gps['longitude'] as num?)?.toDouble(),
        createdAt: addTime,
      );
    }

    return BlockItem(
      type: BlockType.rich,
      title: title,
      content: content,
      tags: tags,
      createdAt: addTime,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 移动端版本：原有布局
// ─────────────────────────────────────────────────────────────

class _MobileHomeScreen extends StatefulWidget {
  const _MobileHomeScreen();

  @override
  State<_MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<_MobileHomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  double? _dragStartX;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 300) {
      context.read<TraceProvider>().load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: const Color(0xFFF5F6FA),
        surfaceTintColor: const Color(0xFFF5F6FA),
        shadowColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      endDrawerEnableOpenDragGesture: false,
      endDrawer: const _SettingsDrawer(),
      body: Column(
        children: [
          _HomeHeader(
            onNodeTap: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: (d) => _dragStartX = d.globalPosition.dx,
              onHorizontalDragUpdate: (d) {
                if (_dragStartX == null) return;
                if (_dragStartX! - d.globalPosition.dx > 20) {
                  _scaffoldKey.currentState?.openEndDrawer();
                  _dragStartX = null;
                }
              },
              onHorizontalDragEnd: (_) => _dragStartX = null,
              child: Consumer<TraceProvider>(
                builder: (context, provider, _) {
                  if (provider.loading && provider.blocks.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF4A6CF7),
                      ),
                    );
                  }
                  if (provider.error != null && provider.blocks.isEmpty) {
                    return _buildError(provider.error!, provider);
                  }
                  if (provider.blocks.isEmpty) {
                    return _buildEmpty();
                  }
                  return ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount:
                        provider.blocks.length + (provider.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == provider.blocks.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF4A6CF7),
                            ),
                          ),
                        );
                      }
                      final item = _blockToItem(provider.blocks[index]);
                      if (item == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: GestureDetector(
                          onTap: () {
                            final imageService = TraceImageService(
                              context.read<ConnectionProvider>(),
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DetailScreen(
                                  block: provider.blocks[index],
                                  imageService: imageService,
                                ),
                              ),
                            );
                          },
                          onLongPress: () => _showCardOptions(
                            context,
                            provider.blocks[index],
                          ),
                          child: _buildCard(item),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const EditScreen()),
          );
          if (result == true && mounted) {
            context.read<TraceProvider>().refresh();
          }
        },
        backgroundColor: const Color(0xFF4A6CF7),
        elevation: 6,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timeline_rounded,
            size: 56,
            color: Colors.black.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 16),
          const Text(
            '还没有记录',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF9E9E9E),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '点击右下角 + 开始记录',
            style: TextStyle(fontSize: 13, color: Color(0xFFBBBBBB)),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error, TraceProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 48,
              color: Colors.black.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 16),
            const Text(
              '加载失败',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9E9E9E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFFBBBBBB)),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: provider.refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCardOptions(BuildContext context, BlockModel block) {
    final bid = block.maybeString('bid') ?? '';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF20263D).withValues(alpha: 0.96),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.36),
              blurRadius: 26,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (bid.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Text(
                    bid,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8FA6FF).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.copy_rounded,
                    size: 18,
                    color: Color(0xFF4A6CF7),
                  ),
                ),
                title: const Text(
                  '复制 BID',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFEAF0FF),
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  if (bid.isNotEmpty) {
                    Clipboard.setData(ClipboardData(text: bid));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('BID 已复制'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: Colors.red,
                  ),
                ),
                title: const Text(
                  '删除',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.red,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context, block);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, BlockModel block) {
    final bid = block.maybeString('bid') ?? '';
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('删除记录'),
        content: const Text('确定要删除这条记录吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              if (bid.isEmpty) return;
              try {
                final conn = context
                    .read<ConnectionProvider>()
                    .activeConnection;
                if (conn == null) return;
                await BlockApi(connection: conn).deleteBlock(bid: bid);
                await BlockCache.instance.remove(bid);
                if (mounted) {
                  context.read<TraceProvider>().refresh();
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('已删除')));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('删除失败：$e')));
                }
              }
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BlockItem item) {
    final imageService = TraceImageService(context.read<ConnectionProvider>());
    switch (item.type) {
      case BlockType.gps:
        return GpsCard(item: item, imageService: imageService);
      case BlockType.image:
        return ImageCard(item: item, imageService: imageService);
      case BlockType.rich:
        return RichCard(item: item, imageService: imageService);
    }
  }

  BlockItem? _blockToItem(BlockModel block) {
    final title = block.maybeString('title');
    final content = block.maybeString('content');
    final tags = block.getList<String>('tag');
    final addTime = block.getDateTime('add_time') ?? DateTime.now();
    final gps = block.getMap('gps');
    final imageList = block.getList<String>('image_list');
    final traceProvider = context.read<TraceProvider>();

    final imageMetas = imageList.map((imageBid) {
      final info = traceProvider.getImageInfo(imageBid);
      final cid = info?['cid'] ?? imageBid;
      final key = info?['key'];
      return ImageMeta(cid: cid, encryptionKey: key, bid: imageBid);
    }).toList();

    if (imageMetas.isNotEmpty) {
      if (title != null || content != null || tags.isNotEmpty) {
        return BlockItem(
          type: BlockType.rich,
          title: title,
          content: content,
          tags: tags,
          imageMetas: imageMetas,
          createdAt: addTime,
        );
      }
      return BlockItem(
        type: BlockType.image,
        tags: tags,
        imageMetas: imageMetas,
        createdAt: addTime,
      );
    }

    if (gps.isNotEmpty) {
      return BlockItem(
        type: BlockType.gps,
        title: title,
        content: content,
        tags: tags,
        lat: (gps['latitude'] as num?)?.toDouble(),
        lng: (gps['longitude'] as num?)?.toDouble(),
        createdAt: addTime,
      );
    }

    return BlockItem(
      type: BlockType.rich,
      title: title,
      content: content,
      tags: tags,
      createdAt: addTime,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 移动端 Header 和抽屉
// ─────────────────────────────────────────────────────────────

class _HomeHeader extends StatelessWidget {
  final VoidCallback onNodeTap;
  const _HomeHeader({required this.onNodeTap});

  @override
  Widget build(BuildContext context) {
    final activeTag = context.watch<TraceProvider>().activeTag;
    return Container(
      color: const Color(0xFFF5F6FA),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Block Trace',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E),
                  letterSpacing: -0.5,
                ),
              ),
              if (activeTag != null) ...[
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.label_rounded,
                      size: 11,
                      color: Color(0xFF4A6CF7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '# $activeTag',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF4A6CF7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          _NodeStatusButton(onTap: onNodeTap),
        ],
      ),
    );
  }
}

class _NodeStatusButton extends StatelessWidget {
  final VoidCallback onTap;
  const _NodeStatusButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final connected = context.watch<ConnectionProvider>().hasActiveConnection;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F2FF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          children: [
            const Center(
              child: Icon(
                Icons.hub_rounded,
                size: 18,
                color: Color(0xFF4A6CF7),
              ),
            ),
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: connected
                      ? const Color(0xFF34C759)
                      : const Color(0xFFFF3B30),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFF0F2FF),
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsDrawer extends StatefulWidget {
  const _SettingsDrawer();

  @override
  State<_SettingsDrawer> createState() => _SettingsDrawerState();
}

class _SettingsDrawerState extends State<_SettingsDrawer> {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 290,
      backgroundColor: const Color(0xFFF5F6FA),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.label_rounded,
                    color: Color(0xFF4A6CF7),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    '标签',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add_rounded, size: 22),
                    color: const Color(0xFF4A6CF7),
                    tooltip: '添加标签',
                    onPressed: () => _showAddTagDialog(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.black.withValues(alpha: 0.06)),
            const SizedBox(height: 8),
            Expanded(
              child: Consumer<TagProvider>(
                builder: (context, tagProvider, _) {
                  final tags = tagProvider.tags;
                  if (tags.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.label_off_outlined,
                            size: 40,
                            color: Colors.black.withValues(alpha: 0.15),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '暂无标签',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF9E9E9E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '点击右上角 + 添加',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFBBBBBB),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    itemCount: tags.length,
                    itemBuilder: (context, index) {
                      final tag = tags[index];
                      final selected =
                          context.watch<TraceProvider>().activeTag == tag;
                      return _TagListTile(
                        tag: tag,
                        selected: selected,
                        onTap: () => context.read<TraceProvider>().setTag(
                          selected ? null : tag,
                        ),
                        onLongPress: () => _confirmRemoveTag(context, tag),
                      );
                    },
                  );
                },
              ),
            ),
            Divider(height: 1, color: Colors.black.withValues(alpha: 0.06)),
            InkWell(
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    Icon(
                      Icons.settings_rounded,
                      size: 20,
                      color: Color(0xFF9E9E9E),
                    ),
                    SizedBox(width: 12),
                    Text(
                      '设置',
                      style: TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
                    ),
                    Spacer(),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Color(0xFF9E9E9E),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTagDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('添加标签'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入标签名称',
            prefixText: '# ',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onSubmitted: (v) {
            context.read<TagProvider>().addTag(v);
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              context.read<TagProvider>().addTag(ctrl.text);
              Navigator.pop(context);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveTag(BuildContext context, String tag) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('删除标签'),
        content: Text('确定要删除标签「$tag」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              context.read<TagProvider>().removeTag(tag);
              if (context.read<TraceProvider>().activeTag == tag) {
                context.read<TraceProvider>().setTag(null);
              }
              Navigator.pop(context);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _TagListTile extends StatelessWidget {
  final String tag;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _TagListTile({
    required this.tag,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? const Color(0xFF4A6CF7).withValues(alpha: 0.08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF4A6CF7)
                      : const Color(0xFFF0F2FF),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  Icons.label_rounded,
                  size: 16,
                  color: selected ? Colors.white : const Color(0xFF4A6CF7),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '# $tag',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected
                        ? const Color(0xFF4A6CF7)
                        : const Color(0xFF1A1A2E),
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: Color(0xFF4A6CF7),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
