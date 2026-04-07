import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TagProvider extends ChangeNotifier {
  static const _key = 'block_trace_tags';

  List<String> _tags = [];
  List<String> get tags => List.unmodifiable(_tags);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _tags = prefs.getStringList(_key) ?? [];
    notifyListeners();
  }

  Future<void> addTag(String tag) async {
    final t = tag.trim();
    if (t.isEmpty || _tags.contains(t)) return;
    _tags.add(t);
    await _persist();
    notifyListeners();
  }

  Future<void> removeTag(String tag) async {
    _tags.remove(tag);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _tags);
  }
}
