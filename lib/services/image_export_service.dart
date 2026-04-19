import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;

class TraceImageExportService {
  Future<File?> exportFileWithDialog({
    required File sourceFile,
    String? preferredName,
  }) async {
    final bytes = await sourceFile.readAsBytes();
    final ext = p.extension(sourceFile.path);
    final baseName = preferredName == null || preferredName.trim().isEmpty
        ? p.basenameWithoutExtension(sourceFile.path)
        : preferredName.trim();
    return exportBytesWithDialog(
      bytes: bytes,
      preferredName: baseName,
      preferredExtension: ext,
    );
  }

  Future<File?> exportBytesWithDialog({
    required Uint8List bytes,
    String? preferredName,
    String? preferredExtension,
  }) async {
    final ext = _normalizeExtension(
      preferredExtension?.trim().isNotEmpty == true
          ? preferredExtension
          : _detectExtension(bytes),
    );
    final suggestedName = preferredName == null || preferredName.trim().isEmpty
        ? 'block_trace_image_${DateTime.now().millisecondsSinceEpoch}$ext'
        : '${preferredName.trim()}$ext';

    final location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: [
        XTypeGroup(label: 'Image', extensions: [ext.replaceFirst('.', '')]),
      ],
    );
    if (location == null || location.path.isEmpty) {
      return null;
    }

    final target = File(location.path);
    await target.parent.create(recursive: true);
    await target.writeAsBytes(bytes, flush: true);
    return target;
  }

  String _normalizeExtension(String? ext) {
    if (ext == null || ext.isEmpty) return '.jpg';
    return ext.startsWith('.') ? ext.toLowerCase() : '.${ext.toLowerCase()}';
  }

  String _detectExtension(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return '.jpg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return '.png';
    }
    if (bytes.length >= 6 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46) {
      return '.gif';
    }
    if (bytes.length >= 12) {
      final brand = String.fromCharCodes(bytes.sublist(8, 12));
      if (brand == 'heic' || brand == 'heix' || brand == 'heif') {
        return '.heic';
      }
      if (brand == 'avif') {
        return '.avif';
      }
      if (String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
          String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
        return '.webp';
      }
    }
    return '.jpg';
  }
}
