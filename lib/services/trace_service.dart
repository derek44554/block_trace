import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:block_flutter/block_flutter.dart';

import '../providers/connection_provider.dart';

const _traceModelId = '50f690463c297d781062c0a2ce701364';
const _fileModelId = 'c4238dd0d3d95db7b473adb449f6d282';

class TraceService {
  TraceService(this._connectionProvider);

  final ConnectionProvider _connectionProvider;
  static const _uploadedImageCacheKey = 'block_trace_uploaded_image_cache_v1';

  Future<BlockModel> saveTrace({
    required String title,
    required String content,
    List<String> tags = const [],
    List<File> images = const [],
    List<String> existingImageBids = const [],
    double? latitude,
    double? longitude,
    DateTime? addTime,
    String? existingBid,
    void Function(String status)? onStatus,
    void Function({
      required int total,
      required int completed,
      int? uploadingIndex,
      required bool fromCache,
    })? onImageProgress,
  }) async {
    final connection = _connectionProvider.activeConnection;
    if (connection == null) throw Exception('当前没有可用的连接');

    final nodeData = connection.nodeData;
    String nodeBid =
        nodeData != null ? (nodeData['sender'] as String? ?? '') : '';

    if (nodeBid.length < 10) {
      try {
        final fresh = await ApiClient(connection: connection).postToBridge(
          protocol: 'open',
          routing: '/node/node',
          data: const {},
        );
        nodeBid = fresh['sender'] as String? ?? '';
      } catch (_) {}
    }
    if (nodeBid.length < 10) throw Exception('无效的节点 BID，请重新连接节点');

    print('=== saveTrace: images=${images.length}, nodeBid=${nodeBid.substring(0, 10)}...');

    // 1. 上传图片（失败时跳过，不阻止保存）
    // 优先用 enableIpfsStorage 的连接上传
    final storageConnection = _connectionProvider.connections
        .where((c) => c.enableIpfsStorage)
        .firstOrNull ?? connection;

    final imageBids = <String>[];
    final totalImages = images.length;
    var completedImages = 0;
    for (var i = 0; i < images.length; i++) {
      onStatus?.call('上传图片 ${i + 1}/${images.length}...');
      try {
        final file = images[i];
        final cachedBid = await _getCachedImageBid(file);
        if (cachedBid != null && cachedBid.isNotEmpty) {
          imageBids.add(cachedBid);
          completedImages++;
          onImageProgress?.call(
            total: totalImages,
            completed: completedImages,
            uploadingIndex: null,
            fromCache: true,
          );
          continue;
        }

        onImageProgress?.call(
          total: totalImages,
          completed: completedImages,
          uploadingIndex: i + 1,
          fromCache: false,
        );

        final imageBid = await _uploadFileAsBlock(
          file: file,
          storageConnection: storageConnection,
          blockConnection: connection,
          nodeBid: nodeBid,
        );
        await _cacheUploadedImageBid(file, imageBid);
        imageBids.add(imageBid);
        completedImages++;
        onImageProgress?.call(
          total: totalImages,
          completed: completedImages,
          uploadingIndex: null,
          fromCache: false,
        );
        print('=== 图片 block 创建成功: $imageBid');
      } catch (e) {
        print('=== 图片上传失败: $e');
      }
    }
    print('=== imageBids: $imageBids');

    // 2. 构建 block data
    onStatus?.call('保存记录...');
    final bid = existingBid ?? generateBidV2(nodeBid);
    final now = addTime ?? DateTime.now(); // 有原始时间则保留

    final blockData = <String, dynamic>{
      'bid': bid,
      'model': _traceModelId,
      'title': title,
      'content': content,
      'tag': tags,
      'add_time': iso8601WithOffset(now),
    };

    if (latitude != null && longitude != null) {
      blockData['gps'] = {'latitude': latitude, 'longitude': longitude};
    }
    if (imageBids.isNotEmpty || existingImageBids.isNotEmpty) {
      final allBids = [...existingImageBids, ...imageBids];
      blockData['image_list'] = allBids;
      blockData['link'] = allBids;
    }

    print('=== saveTrace blockData ===\n${jsonEncode(blockData)}');

    final api = BlockApi(connection: connection);
    try {
      await api.saveBlock(data: blockData, receiverBid: nodeBid);
      // 写入本地缓存
      await BlockCache.instance.put(bid, BlockModel(data: blockData));
    } catch (e) {
      debugPrint('saveBlock error: $e');
      rethrow;
    }

    return BlockModel(data: blockData);
  }

  // ── 上传图片并创建图片 Block，返回 bid ───────────────────────

  Future<String> _uploadFileAsBlock({
    required File file,
    required ConnectionModel storageConnection,
    required ConnectionModel blockConnection,
    required String nodeBid,
  }) async {
    final ipfsData = await _uploadFile(
        file: file, connection: storageConnection);

    final imageBid = generateBidV2(nodeBid);
    final imageBlockData = <String, dynamic>{
      'bid': imageBid,
      'node_bid': nodeBid,
      'model': _fileModelId,
      'ipfs': ipfsData,
      'add_time': iso8601WithOffset(DateTime.now()),
    };

    print('=== imageBlockData ===\n${jsonEncode(imageBlockData)}');
    final api = BlockApi(connection: blockConnection);
    await api.saveBlock(data: imageBlockData, receiverBid: nodeBid);

    return imageBid;
  }

  Future<Map<String, dynamic>> _uploadFile({
    required File file,
    required ConnectionModel connection,
  }) async {
    final bytes = await file.readAsBytes();
    final ext = p.extension(file.path);

    final tempDir = await getTemporaryDirectory();
    final payload = _EncPayload(
      bytes: bytes,
      tempDirPath: tempDir.path,
    );

    // 在 Isolate 里加密，与 block_photo 保持一致
    final result = await Isolate.run(() => _encryptBytes(payload));

    try {
      final uploadUrl = Uri.parse(connection.address)
          .replace(path: '/ipfs/ipfs/upload')
          .toString();
      final password =
          IpfsPasswordHelper.computeUploadPassword(connection.keyBase64);

      debugPrint('IPFS upload → $uploadUrl');

      final request = http.MultipartRequest('POST', Uri.parse(uploadUrl))
        ..fields['password'] = password
        ..files.add(await http.MultipartFile.fromPath('file', result.uploadPath));

      final response = await request.send();
      final body = await response.stream.bytesToString();
      debugPrint('IPFS response: ${response.statusCode} $body');

      if (response.statusCode != 200) {
        throw Exception('上传失败(${response.statusCode}): $body');
      }

      final json = jsonDecode(body) as Map<String, dynamic>;
      final cid = json['cid'] as String?;
      if (cid == null || cid.isEmpty) throw Exception('响应缺少 cid');

      final resolvedExt =
          ext.isNotEmpty ? (ext.startsWith('.') ? ext : '.$ext') : '';

      return {
        'cid': cid,
        'ext': resolvedExt,
        'size': result.fileSize,
        'encryption': {'algo': 'PPE-001', 'key': result.encryptionKeyHex},
      };
    } finally {
      try { await File(result.uploadPath).delete(); } catch (_) {}
    }
  }

  Future<String?> _getCachedImageBid(File file) async {
    try {
      final key = await _imageCacheKey(file);
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_uploadedImageCacheKey);
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      final bid = map[key];
      return bid is String && bid.isNotEmpty ? bid : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheUploadedImageBid(File file, String bid) async {
    try {
      final key = await _imageCacheKey(file);
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_uploadedImageCacheKey);
      final map = <String, dynamic>{};
      if (raw != null && raw.isNotEmpty) {
        final parsed = jsonDecode(raw);
        if (parsed is Map) {
          for (final entry in parsed.entries) {
            map[entry.key.toString()] = entry.value;
          }
        }
      }
      map[key] = bid;
      await prefs.setString(_uploadedImageCacheKey, jsonEncode(map));
    } catch (_) {}
  }

  Future<String> _imageCacheKey(File file) async {
    final stat = await file.stat();
    return '${file.path}|${stat.size}|${stat.modified.millisecondsSinceEpoch}';
  }
}

// ── Isolate 数据类 ────────────────────────────────────────────

class _EncPayload {
  const _EncPayload({required this.bytes, required this.tempDirPath});
  final Uint8List bytes;
  final String tempDirPath;
}

class _EncResult {
  const _EncResult({
    required this.uploadPath,
    required this.fileSize,
    required this.encryptionKeyHex,
  });
  final String uploadPath;
  final int fileSize;
  final String encryptionKeyHex;
}

// ── Isolate 任务（与 block_photo._processBytesPayload 完全一致）─

Future<_EncResult> _encryptBytes(_EncPayload payload) async {
  final bytes = payload.bytes;
  final key = _randomBytes(32);
  final algorithm = AesGcm.with256bits();
  final secretKey = await algorithm.newSecretKeyFromBytes(key);
  final nonce = algorithm.newNonce();
  final secretBox =
      await algorithm.encrypt(bytes, secretKey: secretKey, nonce: nonce);

  final combined = Uint8List.fromList([
    ...nonce,
    ...secretBox.mac.bytes,
    ...secretBox.cipherText,
  ]);

  final tempPath = p.join(
    payload.tempDirPath,
    'enc_${DateTime.now().microsecondsSinceEpoch}_${_randomHex(8)}',
  );
  await File(tempPath).writeAsBytes(combined, flush: true);

  return _EncResult(
    uploadPath: tempPath,
    fileSize: combined.length,
    encryptionKeyHex: _bytesToHex(key),
  );
}

// ── 工具函数 ──────────────────────────────────────────────────

Uint8List _randomBytes(int length) {
  final rnd = Random.secure();
  return Uint8List.fromList(List.generate(length, (_) => rnd.nextInt(256)));
}

String _randomHex(int length) {
  final rnd = Random.secure();
  final buf = StringBuffer();
  for (var i = 0; i < length; i++) {
    buf.write(rnd.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return buf.toString();
}

String _bytesToHex(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
