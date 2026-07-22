import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../domain/task.dart';
import '../domain/task_template.dart';

class TaskTemplateStore {
  TaskTemplateStore(this._box);

  final Box<dynamic> _box;
  static const String boxName = 'lifeos_task_templates';
  static const String _key = 'templates';

  List<TaskTemplate> getAll() {
    final List<TaskTemplate> custom = _loadCustom();
    return <TaskTemplate>[...BuiltInTaskTemplates.all, ...custom];
  }

  List<TaskTemplate> _loadCustom() {
    final dynamic raw = _box.get(_key);
    if (raw is! String || raw.isEmpty) {
      return const <TaskTemplate>[];
    }
    final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
    return list.map((dynamic e) => TaskTemplate.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> _saveCustom(List<TaskTemplate> templates) async {
    await _box.put(
      _key,
      jsonEncode(templates.map((TaskTemplate t) => t.toJson()).toList()),
    );
  }

  Future<TaskTemplate> saveFromTask(Task task, {required String name}) async {
    final List<TaskTemplate> custom = _loadCustom();
    final TaskTemplate template = TaskTemplate(
      id: const Uuid().v4(),
      name: name,
      title: task.title,
      description: task.description,
      priority: task.priority,
      project: task.project,
      labels: task.labels,
      recurrence: task.recurrence,
    );
    custom.add(template);
    await _saveCustom(custom);
    return template;
  }

  Future<void> delete(String id) async {
    final List<TaskTemplate> custom = _loadCustom().where((TaskTemplate t) => t.id != id).toList();
    await _saveCustom(custom);
  }
}
