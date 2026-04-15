import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/block_item.dart';

class TraceDraft {
  final String id;
  final String title;
  final String content;
  final List<String> tags;
  final List<String> localImagePaths;
  final List<ImageMeta> existingImageMetas;
  final String? existingBid;
  final DateTime? initialAddTime;
  final double? lat;
  final double? lng;
  final DateTime updatedAt;
  final bool isSaving;
  final int uploadTotal;
  final int uploadCompleted;
  final int? uploadingIndex;
  final String? saveError;

  const TraceDraft({
    required this.id,
    required this.title,
    required this.content,
    required this.tags,
    required this.localImagePaths,
    required this.existingImageMetas,
    required this.updatedAt,
    this.isSaving = false,
    this.uploadTotal = 0,
    this.uploadCompleted = 0,
    this.uploadingIndex,
    this.saveError,
    this.existingBid,
    this.initialAddTime,
    this.lat,
    this.lng,
  });

  bool get hasContent =>
      title.trim().isNotEmpty ||
      content.trim().isNotEmpty ||
      tags.isNotEmpty ||
      localImagePaths.isNotEmpty ||
      existingImageMetas.isNotEmpty ||
      lat != null ||
      lng != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'tags': tags,
        'localImagePaths': localImagePaths,
        'existingImageMetas': existingImageMetas
            .map(
              (m) => {
                'cid': m.cid,
                'encryptionKey': m.encryptionKey,
                'bid': m.bid,
              },
            )
            .toList(),
        'existingBid': existingBid,
        'initialAddTimeMs': initialAddTime?.millisecondsSinceEpoch,
        'lat': lat,
        'lng': lng,
        'updatedAtMs': updatedAt.millisecondsSinceEpoch,
        'isSaving': isSaving,
        'uploadTotal': uploadTotal,
        'uploadCompleted': uploadCompleted,
        'uploadingIndex': uploadingIndex,
        'saveError': saveError,
      };

  factory TraceDraft.fromJson(Map<String, dynamic> json) {
    final metasRaw = json['existingImageMetas'];
    final metas = <ImageMeta>[];
    if (metasRaw is List) {
      for (final m in metasRaw) {
        if (m is! Map) continue;
        final cid = (m['cid'] ?? '').toString();
        if (cid.isEmpty) continue;
        metas.add(
          ImageMeta(
            cid: cid,
            encryptionKey: m['encryptionKey']?.toString(),
            bid: m['bid']?.toString(),
          ),
        );
      }
    }

    final tagsRaw = json['tags'];
    final imagePathsRaw = json['localImagePaths'];
    final initialAddTimeMs = json['initialAddTimeMs'];
    final updatedAtMs = json['updatedAtMs'];

    return TraceDraft(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      tags: tagsRaw is List ? tagsRaw.map((e) => e.toString()).toList() : [],
      localImagePaths: imagePathsRaw is List
          ? imagePathsRaw.map((e) => e.toString()).toList()
          : [],
      existingImageMetas: metas,
      existingBid: json['existingBid']?.toString(),
      initialAddTime:
          initialAddTimeMs is int ? DateTime.fromMillisecondsSinceEpoch(initialAddTimeMs) : null,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      updatedAt:
          updatedAtMs is int ? DateTime.fromMillisecondsSinceEpoch(updatedAtMs) : DateTime.now(),
      isSaving: json['isSaving'] == true,
      uploadTotal: (json['uploadTotal'] as num?)?.toInt() ?? 0,
      uploadCompleted: (json['uploadCompleted'] as num?)?.toInt() ?? 0,
      uploadingIndex: (json['uploadingIndex'] as num?)?.toInt(),
      saveError: json['saveError']?.toString(),
    );
  }

  TraceDraft copyWith({
    String? id,
    String? title,
    String? content,
    List<String>? tags,
    List<String>? localImagePaths,
    List<ImageMeta>? existingImageMetas,
    String? existingBid,
    DateTime? initialAddTime,
    double? lat,
    double? lng,
    DateTime? updatedAt,
    bool? isSaving,
    int? uploadTotal,
    int? uploadCompleted,
    int? uploadingIndex,
    bool clearUploadingIndex = false,
    String? saveError,
    bool clearSaveError = false,
  }) {
    return TraceDraft(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      localImagePaths: localImagePaths ?? this.localImagePaths,
      existingImageMetas: existingImageMetas ?? this.existingImageMetas,
      existingBid: existingBid ?? this.existingBid,
      initialAddTime: initialAddTime ?? this.initialAddTime,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      updatedAt: updatedAt ?? this.updatedAt,
      isSaving: isSaving ?? this.isSaving,
      uploadTotal: uploadTotal ?? this.uploadTotal,
      uploadCompleted: uploadCompleted ?? this.uploadCompleted,
      uploadingIndex: clearUploadingIndex
          ? null
          : (uploadingIndex ?? this.uploadingIndex),
      saveError: clearSaveError ? null : (saveError ?? this.saveError),
    );
  }
}

class DraftProvider extends ChangeNotifier {
  static const _key = 'block_trace_drafts_v1';

  List<TraceDraft> _drafts = [];
  List<TraceDraft> get drafts => List.unmodifiable(_drafts);

  String newDraftId() => 'draft_${DateTime.now().microsecondsSinceEpoch}';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      _drafts = [];
      notifyListeners();
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        _drafts = decoded
            .whereType<Map>()
            .map((e) => TraceDraft.fromJson(Map<String, dynamic>.from(e)))
            .where((e) => e.id.isNotEmpty)
            .toList();
        _drafts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        _dedupeByExistingBid();
      }
    } catch (_) {
      _drafts = [];
    }

    notifyListeners();
  }

  Future<void> upsert(TraceDraft draft) async {
    if (!draft.hasContent) return;
    _removeDuplicatedExistingBidDrafts(
      existingBid: draft.existingBid,
      keepId: draft.id,
    );
    final i = _drafts.indexWhere((e) => e.id == draft.id);
    if (i >= 0) {
      _drafts[i] = draft;
    } else {
      _drafts.add(draft);
    }
    _drafts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _persist();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _drafts.removeWhere((e) => e.id == id);
    await _persist();
    notifyListeners();
  }

  TraceDraft? findById(String id) {
    final idx = _drafts.indexWhere((e) => e.id == id);
    if (idx < 0) return null;
    return _drafts[idx];
  }

  TraceDraft? findLatestByExistingBid(String? existingBid) {
    if (existingBid == null || existingBid.isEmpty) return null;
    for (final d in _drafts) {
      if (d.existingBid == existingBid) return d;
    }
    return null;
  }

  Future<void> markSavingStart({
    required String id,
    required int uploadTotal,
  }) async {
    final idx = _drafts.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    _removeDuplicatedExistingBidDrafts(
      existingBid: _drafts[idx].existingBid,
      keepId: _drafts[idx].id,
    );
    _drafts[idx] = _drafts[idx].copyWith(
      isSaving: true,
      uploadTotal: uploadTotal,
      uploadCompleted: 0,
      clearUploadingIndex: true,
      clearSaveError: true,
      updatedAt: DateTime.now(),
    );
    await _persist();
    notifyListeners();
  }

  Future<void> markSavingProgress({
    required String id,
    required int completed,
    required int total,
    int? uploadingIndex,
  }) async {
    final idx = _drafts.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    _drafts[idx] = _drafts[idx].copyWith(
      isSaving: true,
      uploadTotal: total,
      uploadCompleted: completed,
      uploadingIndex: uploadingIndex,
      updatedAt: DateTime.now(),
    );
    await _persist();
    notifyListeners();
  }

  Future<void> markSavingFailed({
    required String id,
    required String error,
  }) async {
    final idx = _drafts.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    _drafts[idx] = _drafts[idx].copyWith(
      isSaving: false,
      clearUploadingIndex: true,
      saveError: error,
      updatedAt: DateTime.now(),
    );
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_drafts.map((e) => e.toJson()).toList());
    await prefs.setString(_key, raw);
  }

  void _dedupeByExistingBid() {
    final seen = <String>{};
    _drafts = _drafts.where((d) {
      final bid = d.existingBid;
      if (bid == null || bid.isEmpty) return true;
      if (seen.contains(bid)) return false;
      seen.add(bid);
      return true;
    }).toList();
  }

  void _removeDuplicatedExistingBidDrafts({
    required String? existingBid,
    required String keepId,
  }) {
    if (existingBid == null || existingBid.isEmpty) return;
    _drafts.removeWhere(
      (d) => d.id != keepId && d.existingBid == existingBid,
    );
  }
}
