import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/models/checklist_item.dart';
import '../../../core/theme/app_colors.dart';

enum TaskPriority { low, medium, high }

extension TaskPriorityX on TaskPriority {
  String get label => switch (this) {
        TaskPriority.low => 'Low',
        TaskPriority.medium => 'Medium',
        TaskPriority.high => 'High',
      };

  Color get color => switch (this) {
        TaskPriority.low => AppColors.info,
        TaskPriority.medium => AppColors.warning,
        TaskPriority.high => AppColors.danger,
      };

  static TaskPriority parse(String? v) => TaskPriority.values.firstWhere(
        (e) => e.name == v,
        orElse: () => TaskPriority.medium,
      );
}

/// The kind of item: a plain task/assignment, an online course, or a video
/// (e.g. a YouTube tutorial the student wants to watch on a given day).
enum TaskType { task, course, video }

extension TaskTypeX on TaskType {
  String get label => switch (this) {
        TaskType.task => 'Task',
        TaskType.course => 'Course',
        TaskType.video => 'Video',
      };

  IconData get icon => switch (this) {
        TaskType.task => Icons.check_circle_outline_rounded,
        TaskType.course => Icons.school_rounded,
        TaskType.video => Icons.play_circle_fill_rounded,
      };

  Color get color => switch (this) {
        TaskType.task => AppColors.primary,
        TaskType.course => AppColors.info,
        TaskType.video => AppColors.coral,
      };

  static TaskType parse(String? v) => TaskType.values.firstWhere(
        (e) => e.name == v,
        orElse: () => TaskType.task,
      );
}

/// A task / assignment / deadline / course / video. Stored at
/// users/{uid}/tasks/{id}.
class TaskItem {
  final String id;
  final String title;
  final String? note;
  final String? subjectId; // optional link to a subject
  final DateTime? dueDate;
  final bool done;
  final TaskPriority priority;
  final TaskType type;
  final String? link; // optional external URL (course / video / resource)
  final List<ChecklistItem> subtasks;
  final DateTime? createdAt;

  const TaskItem({
    required this.id,
    required this.title,
    this.note,
    this.subjectId,
    this.dueDate,
    this.done = false,
    this.priority = TaskPriority.medium,
    this.type = TaskType.task,
    this.link,
    this.subtasks = const [],
    this.createdAt,
  });

  bool get isOverdue =>
      !done &&
      dueDate != null &&
      dueDate!.isBefore(DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day));

  bool get hasLink => link != null && link!.trim().isNotEmpty;

  bool get hasSubtasks => subtasks.isNotEmpty;
  int get subtasksDone => subtasks.where((s) => s.done).length;

  TaskItem copyWith({
    String? title,
    String? note,
    String? subjectId,
    DateTime? dueDate,
    bool? done,
    TaskPriority? priority,
    TaskType? type,
    String? link,
    List<ChecklistItem>? subtasks,
    bool clearDue = false,
    bool clearSubject = false,
    bool clearLink = false,
  }) {
    return TaskItem(
      id: id,
      title: title ?? this.title,
      note: note ?? this.note,
      subjectId: clearSubject ? null : (subjectId ?? this.subjectId),
      dueDate: clearDue ? null : (dueDate ?? this.dueDate),
      done: done ?? this.done,
      priority: priority ?? this.priority,
      type: type ?? this.type,
      link: clearLink ? null : (link ?? this.link),
      subtasks: subtasks ?? this.subtasks,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'note': note,
        'subjectId': subjectId,
        'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
        'done': done,
        'priority': priority.name,
        'type': type.name,
        'link': link,
        'subtasks': ChecklistItem.listToMap(subtasks),
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
      };

  factory TaskItem.fromMap(String id, Map<String, dynamic> map) {
    return TaskItem(
      id: id,
      title: (map['title'] as String?) ?? '',
      note: map['note'] as String?,
      subjectId: map['subjectId'] as String?,
      dueDate: (map['dueDate'] as Timestamp?)?.toDate(),
      done: (map['done'] as bool?) ?? false,
      priority: TaskPriorityX.parse(map['priority'] as String?),
      type: TaskTypeX.parse(map['type'] as String?),
      link: map['link'] as String?,
      subtasks: ChecklistItem.listFrom(map['subtasks']),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
