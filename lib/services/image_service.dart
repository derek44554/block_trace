import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;
import 'package:block_flutter/block_flutter.dart';

import '../providers/connection_provider.dart';

class TraceImageService {
  TraceImageService(this._connectionProvider);

  final ConnectionProvider _connectionProvider;

  String? get _endpoint => _connectionProvider.ipfsEndpoint;

  final _pending = HashMap<String, Future<Uint8List?>>();

  Future<Uint8List?> loadByCid({
    required String cid,
    String? encryptionKey,
  }) async {
    if (cid.isEmpty) return null;
    final endpoint = _endpoint;
    if (endpoint == null || endpoint.isEmpty) return null;

    final mem = ImageCacheHelper.getMemoryImage(cid, variant: ImageVariant.medium);
    if (mem != null) return mem;

    final disk = await ImageCacheHelper.getCachedImage(cid, variant: ImageVariant.medium);
    if (disk != null) {
      final bytes = await disk.readAsBytes();
      ImageCacheHelper.cacheMemoryImage(cid, bytes, variant: ImageVariant.medium);
      return bytes;
    }

    final existing = _pending[cid];
    if (existing != null) return await existing;

    final future = _downloadAndDecrypt(
      cid: cid,
      endpoint: endpoint,
      encryptionKey: encryptionKey,
    );
    _pending[cid] = future;
    try {
      final bytes = await future;
      if (bytes != null) {
        ImageCacheHelper.cacheMemoryImage(cid, bytes, variant: ImageVariant.medium);
        unawaited(ImageCacheHelper.saveImageToCache(cid, bytes, variant: ImageVariant.medium));
      }
      return bytes;
    } finally {
      _pending.remove(cid);
    }
  }

  Future<Uint8List?> _downloadAndDecrypt({
    required String cid,
    required String endpoint,
    String? encryptionKey,
  }) async {
    try {
      final url = '${endpoint.replaceAll(RegExp(r'/+$'), '')}/$cid';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return null;

      var bytes = response.bodyBytes;
      if (encryptionKey != null && encryptionKey.isNotEmpty) {
        bytes = await Isolate.run(() => _decryptSync(bytes, encryptionKey));
      }
      return bytes;
    } catch (_) {
      return null;
    }
  }
}

// ── 解密（与 block_photo 完全一致）────────────────────────────

Future<Uint8List> _decryptSync(Uint8List data, String keyValue) async {
  if (data.length < 32) throw Exception('Encrypted payload too short');

  final keyBytes = _decodeKey(keyValue);
  final algorithm = AesGcm.with256bits();
  final secretKey = await algorithm.newSecretKeyFromBytes(keyBytes);

  final strategies = [
    (nonceLen: 12, macAtEnd: false),
    (nonceLen: 12, macAtEnd: true),
    (nonceLen: 16, macAtEnd: false),
    (nonceLen: 16, macAtEnd: true),
  ];

  for (final s in strategies) {
    if (data.length <= s.nonceLen + 16) continue;
    try {
      final nonce = data.sublist(0, s.nonceLen);
      final Uint8List mac;
      final Uint8List cipher;
      if (s.macAtEnd) {
        mac = data.sublist(data.length - 16);
        cipher = data.sublist(s.nonceLen, data.length - 16);
      } else {
        mac = data.sublist(s.nonceLen, s.nonceLen + 16);
        cipher = data.sublist(s.nonceLen + 16);
      }
      final box = SecretBox(cipher, nonce: nonce, mac: Mac(mac));
      final decrypted = await algorithm.decrypt(box, secretKey: secretKey);
      return Uint8List.fromList(decrypted);
    } on SecretBoxAuthenticationError {
      continue;
    } catch (_) {
      continue;
    }
  }
  throw Exception('Unsupported encrypted payload format');
}

Uint8List _decodeKey(String value) {
  final normalized = value.trim();
  if (RegExp(r'^[0-9a-fA-F]+$').hasMatch(normalized) && normalized.length.isEven) {
    return _hexToBytes(normalized);
  }
  try {
    final rem = normalized.length % 4;
    final padded = rem == 0 ? normalized : normalized + '=' * (4 - rem);
    return base64Decode(padded);
  } catch (_) {}
  return _hexToBytes(normalized);
}

Uint8List _hexToBytes(String hex) {
  final cleaned = hex.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
  final result = Uint8List(cleaned.length ~/ 2);
  for (var i = 0; i < cleaned.length; i += 2) {
    result[i ~/ 2] = int.parse(cleaned.substring(i, i + 2), radix: 16);
  }
  return result;
}
