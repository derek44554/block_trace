import 'dart:convert';
import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart' as fic;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class TraceImageCompressionPlan {
  final int strength;
  final int quality;
  final int minDimension;
  final String label;

  const TraceImageCompressionPlan({
    required this.strength,
    required this.quality,
    required this.minDimension,
    required this.label,
  });

  String get detail => '质量 $quality · 短边约 $minDimension px';
}

class TraceImageCompressionEstimate {
  final int originalBytes;
  final int resultBytes;
  final int eligibleCount;
  final int skippedCount;

  const TraceImageCompressionEstimate({
    required this.originalBytes,
    required this.resultBytes,
    required this.eligibleCount,
    required this.skippedCount,
  });

  int get savedBytes => originalBytes - resultBytes;

  double get savedRatio => originalBytes <= 0 ? 0 : savedBytes / originalBytes;
}

class TracePreparedImages {
  final List<File> files;
  final TraceImageCompressionEstimate estimate;

  const TracePreparedImages({required this.files, required this.estimate});
}

class TraceImageCompressionService {
  static const int defaultStrength = 45;
  static const _eligibleExtensions = {
    '.jpg',
    '.jpeg',
    '.jpe',
    '.heic',
    '.heif',
  };

  TraceImageCompressionPlan planForStrength(int strength) {
    final normalized = strength.clamp(0, 100);
    final quality = (94 - normalized * 0.20).round().clamp(72, 94);
    final minDimension = switch (normalized) {
      <= 25 => 2560,
      <= 55 => 1920,
      <= 80 => 1600,
      _ => 1280,
    };
    final label = switch (normalized) {
      <= 25 => '轻度',
      <= 55 => '推荐',
      <= 80 => '高压缩',
      _ => '极限',
    };

    return TraceImageCompressionPlan(
      strength: normalized,
      quality: quality,
      minDimension: minDimension,
      label: label,
    );
  }

  bool canSafelyCompress(File file) {
    final ext = p.extension(file.path).toLowerCase();
    return _eligibleExtensions.contains(ext);
  }

  Future<TraceImageCompressionEstimate> estimate({
    required List<File> images,
    required bool enabled,
    required int strength,
  }) async {
    if (images.isEmpty) {
      return const TraceImageCompressionEstimate(
        originalBytes: 0,
        resultBytes: 0,
        eligibleCount: 0,
        skippedCount: 0,
      );
    }

    final plan = planForStrength(strength);
    var originalBytes = 0;
    var resultBytes = 0;
    var eligibleCount = 0;
    var skippedCount = 0;

    for (final file in images) {
      final originalLength = await file.length();
      originalBytes += originalLength;

      if (!enabled) {
        resultBytes += originalLength;
        continue;
      }

      if (!canSafelyCompress(file)) {
        skippedCount++;
        resultBytes += originalLength;
        continue;
      }

      eligibleCount++;
      try {
        final cached = await _cachedCompressedFile(file: file, plan: plan);
        if (await cached.exists()) {
          final cachedLength = await cached.length();
          resultBytes += cachedLength < originalLength
              ? cachedLength
              : originalLength;
          continue;
        }

        final bytes = await fic.FlutterImageCompress.compressWithFile(
          file.absolute.path,
          quality: plan.quality,
          minWidth: plan.minDimension,
          minHeight: plan.minDimension,
          format: fic.CompressFormat.jpeg,
          keepExif: true,
          autoCorrectionAngle: true,
        );
        final compressedLength = bytes?.length ?? originalLength;
        resultBytes += compressedLength < originalLength
            ? compressedLength
            : originalLength;
      } catch (_) {
        resultBytes += originalLength;
      }
    }

    return TraceImageCompressionEstimate(
      originalBytes: originalBytes,
      resultBytes: resultBytes,
      eligibleCount: eligibleCount,
      skippedCount: skippedCount,
    );
  }

  Future<TracePreparedImages> prepareForUpload({
    required List<File> images,
    required bool enabled,
    required int strength,
  }) async {
    if (images.isEmpty) {
      return const TracePreparedImages(
        files: [],
        estimate: TraceImageCompressionEstimate(
          originalBytes: 0,
          resultBytes: 0,
          eligibleCount: 0,
          skippedCount: 0,
        ),
      );
    }

    final plan = planForStrength(strength);
    final prepared = <File>[];
    var originalBytes = 0;
    var resultBytes = 0;
    var eligibleCount = 0;
    var skippedCount = 0;

    for (final file in images) {
      final originalLength = await file.length();
      originalBytes += originalLength;

      if (!enabled) {
        prepared.add(file);
        resultBytes += originalLength;
        continue;
      }

      if (!canSafelyCompress(file)) {
        skippedCount++;
        prepared.add(file);
        resultBytes += originalLength;
        continue;
      }

      eligibleCount++;
      File? compressedFile;
      try {
        compressedFile = await _ensureCompressedFile(file: file, plan: plan);
      } catch (_) {
        compressedFile = null;
      }

      if (compressedFile == null) {
        prepared.add(file);
        resultBytes += originalLength;
        continue;
      }

      final compressedLength = await compressedFile.length();
      if (compressedLength >= originalLength) {
        prepared.add(file);
        resultBytes += originalLength;
        continue;
      }

      prepared.add(compressedFile);
      resultBytes += compressedLength;
    }

    return TracePreparedImages(
      files: prepared,
      estimate: TraceImageCompressionEstimate(
        originalBytes: originalBytes,
        resultBytes: resultBytes,
        eligibleCount: eligibleCount,
        skippedCount: skippedCount,
      ),
    );
  }

  Future<File?> _ensureCompressedFile({
    required File file,
    required TraceImageCompressionPlan plan,
  }) async {
    final target = await _cachedCompressedFile(file: file, plan: plan);
    if (await target.exists()) {
      return target;
    }

    final result = await fic.FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      target.path,
      quality: plan.quality,
      minWidth: plan.minDimension,
      minHeight: plan.minDimension,
      format: fic.CompressFormat.jpeg,
      keepExif: true,
      autoCorrectionAngle: true,
    );
    if (result == null) return null;
    return File(result.path);
  }

  Future<File> _cachedCompressedFile({
    required File file,
    required TraceImageCompressionPlan plan,
  }) async {
    final stat = await file.stat();
    final cacheDir = Directory(
      p.join((await getTemporaryDirectory()).path, 'compressed_images'),
    );
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    final signature = _hashKey(
      jsonEncode({
        'path': file.absolute.path,
        'size': stat.size,
        'modifiedAtMs': stat.modified.millisecondsSinceEpoch,
        'quality': plan.quality,
        'minDimension': plan.minDimension,
      }),
    );
    return File(p.join(cacheDir.path, '$signature.jpg'));
  }

  String _hashKey(String raw) {
    var hash = 0xcbf29ce484222325;
    for (final byte in utf8.encode(raw)) {
      hash ^= byte;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}
