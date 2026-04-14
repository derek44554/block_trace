import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:block_flutter/block_flutter.dart';
import '../core/platform_helper.dart';
import '../models/block_item.dart';
import '../providers/connection_provider.dart';
import '../providers/tag_provider.dart';
import '../providers/trace_provider.dart';
import '../services/image_service.dart';
import '../widgets/gps_card.dart';
import '../widgets/image_card.dart';
import '../widgets/rich_card.dart';
import 'detail_screen.dart';
import 'edit_screen.dart';
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

class _MacHomeScreen extends StatelessWidget {
  const _MacHomeScreen();

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
                DragToMoveArea(
                  child: SizedBox(
                    width: menuWidth,
                    child: _MacSidebar(isCompact: isCompact),
                  ),
                ),
                SizedBox(width: isCompact ? 8 : 12),
                Expanded(child: _MacContentArea(isCompact: isCompact)),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// macOS 侧边栏：全部 + 标签列表 + 设置
// ─────────────────────────────────────────────────────────────

class _MacSidebar extends StatefulWidget {
  final bool isCompact;

  const _MacSidebar({required this.isCompact});

  @override
  State<_MacSidebar> createState() => _MacSidebarState();
}

class _MacSidebarState extends State<_MacSidebar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(6, widget.isCompact ? 4 : 4, 6, widget.isCompact ? 6 : 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          // 占位空布局 - 调整系统按钮位置
          const SizedBox(height: 8),
          // 痕迹 + 添加按钮
          Padding(
            padding: const EdgeInsets.only(bottom: 4, top: 4),
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

          // 全部痕迹按钮
          _MacSidebarItem(
            icon: Icons.all_inclusive_rounded,
            label: '全部痕迹',
            isAll: true,
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
                    return _MacTagItem(tag: tag);
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 6),

          // 分隔线
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 4),
            color: Colors.white.withValues(alpha: 0.08),
          ),

          // 设置按钮
          _MacSidebarItem(
            icon: Icons.settings_outlined,
            label: '设置',
            isSettings: true,
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              child: const Text('取消')),
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
// macOS 侧边栏项：全部 / 设置
// ─────────────────────────────────────────────────────────────

class _MacSidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isAll;
  final bool isSettings;

  const _MacSidebarItem({
    required this.icon,
    required this.label,
    this.isAll = false,
    this.isSettings = false,
  });

  @override
  Widget build(BuildContext context) {
    final activeTag = context.watch<TraceProvider>().activeTag;
    final isSelected = isAll && activeTag == null;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (isAll) {
            context.read<TraceProvider>().setTag(null);
          } else if (isSettings) {
            _openSettings(context);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isSelected
                ? const Color(0xFF4A6CF7).withValues(alpha: 0.15)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? const Color(0xFF4A6CF7)
                    : Colors.white.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
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

  void _openSettings(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(40),
        child: Container(
          width: 600,
          height: 500,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              // 标题栏
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFE0E0E0), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    const Text(
                      '设置',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // 设置内容
              const Expanded(child: SettingsScreen(isEmbedded: true)),
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

  const _MacTagItem({required this.tag});

  @override
  Widget build(BuildContext context) {
    final activeTag = context.watch<TraceProvider>().activeTag;
    final isSelected = activeTag == tag;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            context.read<TraceProvider>().setTag(isSelected ? null : tag);
          },
          onLongPress: () => _showTagOptions(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isSelected
                  ? const Color(0xFF4A6CF7).withValues(alpha: 0.15)
                  : Colors.transparent,
            ),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF4A6CF7)
                        : const Color(0xFFF0F2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.label_rounded,
                    size: 14,
                    color: isSelected ? Colors.white : const Color(0xFF4A6CF7),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '# $tag',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF4A6CF7)
                          : Colors.white.withValues(alpha: 0.8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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

  const _MacContentArea({required this.isCompact});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isCompact ? 12 : 16),
        color: const Color(0xFFF5F6FA),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // 发布按钮栏
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                // 当前筛选状态
                Consumer<TraceProvider>(
                  builder: (context, provider, _) {
                    final tag = provider.activeTag;
                    if (tag != null) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4A6CF7).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.label_rounded,
                                  size: 12,
                                  color: Color(0xFF4A6CF7),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '# $tag',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF4A6CF7),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => provider.setTag(null),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 14,
                                    color: Color(0xFF4A6CF7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                const Spacer(),
                // 发布按钮
                FilledButton.icon(
                  onPressed: () => _handleCreate(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4A6CF7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('发布'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 列表
          Expanded(
            child: _TimelineContent(isCompact: isCompact),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCreate(BuildContext context) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EditScreen()),
    );
    if (result == true) {
      context.read<TraceProvider>().refresh();
    }
  }
}

// ─────────────────────────────────────────────────────────────
// macOS 时间线列表
// ─────────────────────────────────────────────────────────────

class _TimelineContent extends StatefulWidget {
  final bool isCompact;

  const _TimelineContent({required this.isCompact});

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
        return RefreshIndicator(
          color: const Color(0xFF4A6CF7),
          onRefresh: provider.refresh,
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
            itemCount: provider.blocks.length + (provider.hasMore ? 1 : 0),
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
                    final imageService =
                        TraceImageService(context.read<ConnectionProvider>());
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
                  onLongPress: () =>
                      _showCardOptions(context, provider.blocks[index]),
                  child: _buildCard(item),
                ),
              );
            },
          ),
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
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFBBBBBB),
              ),
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
              if (bid.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    bid,
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
                    color: const Color(0xFFF0F2FF),
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
              const SizedBox(height: 8),
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
                final conn =
                    context.read<ConnectionProvider>().activeConnection;
                if (conn == null) return;
                await BlockApi(connection: conn).deleteBlock(bid: bid);
                await BlockCache.instance.remove(bid);
                if (mounted) {
                  context.read<TraceProvider>().refresh();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已删除')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('删除失败：$e')),
                  );
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
    final imageService =
        TraceImageService(context.read<ConnectionProvider>());
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
          _HomeHeader(onNodeTap: () => _scaffoldKey.currentState?.openEndDrawer()),
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
                            color: Color(0xFF4A6CF7)));
                  }
                  if (provider.error != null && provider.blocks.isEmpty) {
                    return _buildError(provider.error!, provider);
                  }
                  if (provider.blocks.isEmpty) {
                    return _buildEmpty();
                  }
                  return RefreshIndicator(
                    color: const Color(0xFF4A6CF7),
                    onRefresh: provider.refresh,
                    child: ListView.builder(
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
                                    color: Color(0xFF4A6CF7))),
                          );
                        }
                        final item = _blockToItem(provider.blocks[index]);
                        if (item == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: GestureDetector(
                            onTap: () {
                              final imageService = TraceImageService(
                                  context.read<ConnectionProvider>());
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
                            onLongPress: () =>
                                _showCardOptions(context, provider.blocks[index]),
                            child: _buildCard(item),
                          ),
                        );
                      },
                    ),
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
              context, MaterialPageRoute(builder: (_) => const EditScreen()));
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
          Icon(Icons.timeline_rounded,
              size: 56, color: Colors.black.withValues(alpha: 0.12)),
          const SizedBox(height: 16),
          const Text(
            '还没有记录',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9E9E9E)),
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
            Icon(Icons.wifi_off_rounded,
                size: 48, color: Colors.black.withValues(alpha: 0.15)),
            const SizedBox(height: 16),
            const Text(
              '加载失败',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9E9E9E)),
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
                label: const Text('重试')),
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
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
              if (bid.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    child: Text(
                      bid,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF9E9E9E)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )),
              ListTile(
                leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F2FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.copy_rounded,
                        size: 18, color: Color(0xFF4A6CF7))),
                title: const Text('复制 BID',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  if (bid.isNotEmpty) {
                    Clipboard.setData(ClipboardData(text: bid));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('BID 已复制'),
                          duration: Duration(seconds: 2)),
                    );
                  }
                },
              ),
              ListTile(
                leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_outline_rounded,
                        size: 18, color: Colors.red)),
                title: const Text('删除',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context, block);
                },
              ),
              const SizedBox(height: 8),
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
              child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              if (bid.isEmpty) return;
              try {
                final conn =
                    context.read<ConnectionProvider>().activeConnection;
                if (conn == null) return;
                await BlockApi(connection: conn).deleteBlock(bid: bid);
                await BlockCache.instance.remove(bid);
                if (mounted) {
                  context.read<TraceProvider>().refresh();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已删除')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('删除失败：$e')),
                  );
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
    final imageService =
        TraceImageService(context.read<ConnectionProvider>());
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
              const Text('Block Trace',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A2E),
                      letterSpacing: -0.5)),
              if (activeTag != null) ...[
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.label_rounded,
                        size: 11, color: Color(0xFF4A6CF7)),
                    const SizedBox(width: 4),
                    Text('# $activeTag',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF4A6CF7),
                            fontWeight: FontWeight.w500)),
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
    final connected =
        context.watch<ConnectionProvider>().hasActiveConnection;
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
                child: Icon(Icons.hub_rounded,
                    size: 18, color: Color(0xFF4A6CF7))),
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
                  border:
                      Border.all(color: const Color(0xFFF0F2FF), width: 1.2),
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
                  const Icon(Icons.label_rounded,
                      color: Color(0xFF4A6CF7), size: 20),
                  const SizedBox(width: 10),
                  const Text('标签',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A2E))),
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
                          Icon(Icons.label_off_outlined,
                              size: 40, color: Colors.black.withValues(alpha: 0.15)),
                          const SizedBox(height: 12),
                          const Text('暂无标签',
                              style: TextStyle(
                                  fontSize: 14, color: Color(0xFF9E9E9E))),
                          const SizedBox(height: 4),
                          const Text('点击右上角 + 添加',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFFBBBBBB))),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: tags.length,
                    itemBuilder: (context, index) {
                      final tag = tags[index];
                      final selected =
                          context.watch<TraceProvider>().activeTag == tag;
                      return _TagListTile(
                        tag: tag,
                        selected: selected,
                        onTap: () => context
                            .read<TraceProvider>()
                            .setTag(selected ? null : tag),
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
                    MaterialPageRoute(builder: (_) => const SettingsScreen()));
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    Icon(Icons.settings_rounded,
                        size: 20, color: Color(0xFF9E9E9E)),
                    SizedBox(width: 12),
                    Text('设置',
                        style: TextStyle(
                            fontSize: 14, color: Color(0xFF1A1A2E))),
                    Spacer(),
                    Icon(Icons.chevron_right_rounded,
                        size: 18, color: Color(0xFF9E9E9E)),
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              child: const Text('取消')),
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('删除标签'),
        content: Text('确定要删除标签「$tag」吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
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

  const _TagListTile(
      {required this.tag,
      required this.selected,
      required this.onTap,
      this.onLongPress});

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
                child: Icon(Icons.label_rounded,
                    size: 16,
                    color:
                        selected ? Colors.white : const Color(0xFF4A6CF7)),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Text('# $tag',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.normal,
                        color: selected
                            ? const Color(0xFF4A6CF7)
                            : const Color(0xFF1A1A2E),
                      ))),
              if (selected)
                const Icon(Icons.check_rounded,
                    size: 18, color: Color(0xFF4A6CF7)),
            ],
          ),
        ),
      ),
    );
  }
}
