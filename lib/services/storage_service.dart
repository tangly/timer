import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trigger.dart';

class StorageService {
  static const String _paramSavedTriggers = 'saved_triggers';

  Future<List<Trigger>> loadSavedTriggers() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_paramSavedTriggers);
    if (jsonString == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((j) => Trigger.fromJson(j)).toList();
    } catch (e) {
      print('Error loading saved triggers: $e');
      return [];
    }
  }

  Future<void> saveTrigger(Trigger trigger) async {
    final triggers = await loadSavedTriggers();
    // Check if ID exists (update) or add new
    // For now, let's just append. User can delete.
    // Actually, distinct IDs.
    // If saving a new trigger from Create Screen, it will have a new ID.
    triggers.add(trigger);
    await _saveList(triggers);
  }

  Future<void> deleteTrigger(String id) async {
    final triggers = await loadSavedTriggers();
    triggers.removeWhere((t) => t.id == id);
    await _saveList(triggers);
  }

  Future<void> _saveList(List<Trigger> triggers) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = triggers.map((t) => t.toJson()).toList();
    await prefs.setString(_paramSavedTriggers, jsonEncode(jsonList));
  }
}
