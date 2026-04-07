import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:block_flutter/block_flutter.dart';
import 'connection_provider.dart';

class TraceProvider extends ChangeNotifier {
  TraceProvider(this._connectionProvider) {
    _connectionProvider.addListener(_onConnectionChanged);
    if (_connectionProvider.hasActiveConnection) {
      load(refresh: true);
    }
  }

  final ConnectionProvider _connectionProvider;

  List<BlockModel> _blocks = [];
  final Map<String, Map<String, String?>> _imageBlockCache = {};
  bool _loading = false;
  bool _hasMore = true;
  String? _error;
  int _page = 1;
  String? _activeTag;
  static const _limit = 20;
  static const _traceModelId = '50f690463c297d781062c0a2ce701364';

  List<BlockModel> get blocks => List.unmodifiable(_blocks);
  bool get loading => _loading;
  bool get hasMore => _hasMore;
  String? get error => _error;
  String? get activeTag => _activeTag;

  void setTag(String? tag) {
    if (_activeTag == tag) return;
    _activeTag = tag;
    load(refresh: true);
  }

  /// 根据图片 block bid 获取 cid 和 encryptionKey
  Map<String, String?>? getImageInfo(String bid) => _imageBlockCache[bid];

  void _onConnectionChanged() {
    if (_connectionProvider.hasActiveConnection && _blocks.isEmpty && !_loading) {
      load(refresh: true);
    }
  }

  @override
  void dispose() {
    _connectionProvider.removeListener(_onConnectionChanged);
    super.dispose();
  }

  Future<void> load({bool refresh = false}) async {
    if (_loading) return;
    if (!refresh && !_hasMore) return;

    final connection = _connectionProvider.activeConnection;
    if (connection == null) return;

    _loading = true;
    _error = null;
    if (refresh) {
      _page = 1;
      _hasMore = true;
    }
    notifyListeners();

    try {
      final api = BlockApi(connection: connection);
      final nodeBid = connection.nodeData?['sender'] as String?;

      final response = await api.getAllBlocks(
        page: _page,
        limit: _limit,
        order: 'desc',
        model: _traceModelId,
        tag: _activeTag,
        receiverBid: nodeBid,
      );

      final data = response['data'] ?? response;
      final items = data['blocks'] ?? data['items'] ?? data['list'];
      final List<BlockModel> fetched = [];

      if (items is List) {
        for (final item in items.whereType<Map<String, dynamic>>()) {
          final block = BlockModel(data: item);
          fetched.add(block);
          // 写入缓存
          final bid = block.maybeString('bid');
          if (bid != null) unawaited(BlockCache.instance.put(bid, block));
        }
      }

      if (refresh) {
        _blocks = fetched;
      } else {
        _blocks.addAll(fetched);
      }

      _hasMore = fetched.length >= _limit;
      _page++;

      // 预加载图片 block 信息
      await _prefetchImageBlocks(fetched, api);
    } catch (e) {
      _error = e.toString();
      debugPrint('TraceProvider.load error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _prefetchImageBlocks(
      List<BlockModel> blocks, BlockApi api) async {
    // 收集所有未缓存的图片 bid
    final missing = <String>{};
    for (final block in blocks) {
      final imageList = block.getList<String>('image_list');
      for (final bid in imageList) {
        if (!_imageBlockCache.containsKey(bid)) missing.add(bid);
      }
    }
    if (missing.isEmpty) return;

    // 批量获取
    try {
      final response =
          await api.getMultipleBlocks(bids: missing.toList());
      final data = response['data'] ?? response;
      final list = data['blocks'] ?? data['items'] ?? data['list'];
      if (list is List) {
        for (final item in list.whereType<Map<String, dynamic>>()) {
          final b = BlockModel(data: item);
          final bid = b.maybeString('bid');
          if (bid == null) continue;
          final ipfs = b.getMap('ipfs');
          final cid = ipfs['cid'] as String?;
          final enc = ipfs['encryption'];
          String? key;
          if (enc is Map) key = enc['key'] as String?;
          _imageBlockCache[bid] = {'cid': cid, 'key': key};
        }
      }
    } catch (e) {
      debugPrint('prefetchImageBlocks error: $e');
    }

    notifyListeners();
  }

  Future<void> refresh() => load(refresh: true);

  /// 获取单个 block，优先缓存
  Future<BlockModel?> getBlock(String bid) async {
    final cached = await BlockCache.instance.get(bid);
    if (cached != null) return cached;

    final connection = _connectionProvider.activeConnection;
    if (connection == null) return null;
    try {
      final api = BlockApi(connection: connection);
      final response = await api.getBlock(bid: bid);
      final data = response['data'];
      final blockData =
          data is Map<String, dynamic> ? data : response;
      final block = BlockModel(data: blockData);
      await BlockCache.instance.put(bid, block);
      return block;
    } catch (_) {
      return null;
    }
  }
}
