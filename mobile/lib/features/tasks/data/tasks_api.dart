import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/dio_provider.dart';
import 'task_models.dart';

class TasksApi {
  TasksApi(this._client);
  final DioClient _client;

  Future<List<TaskItem>> getMyScope({String? status, String? scope}) async {
    final q = <String, dynamic>{};
    if (status != null && status.isNotEmpty) q['status'] = status;
    if (scope != null && scope.isNotEmpty) q['scope'] = scope;
    final data = await _client.get<List<dynamic>>('/tasks/my-scope', query: q.isEmpty ? null : q);
    return data.map((e) => TaskItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<TaskItem>> getAll({String? assigneeId, String? status}) async {
    final q = <String, dynamic>{};
    if (assigneeId != null) q['assigneeId'] = assigneeId;
    if (status != null && status.isNotEmpty) q['status'] = status;
    final data = await _client.get<List<dynamic>>('/tasks', query: q.isEmpty ? null : q);
    // /tasks returns Task (no reviews). We still parse via TaskItem with empty reviews.
    return data.map((e) => TaskItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<TaskItem> create({
    required String title,
    String? description,
    String? content,
    String? divisionId,
    String? groupId,
    String? objectiveId,
    String? completionRequirements,
    required DateTime dueDate,
    int priority = 2,
    List<String>? dependencyIds,
    String? assigneeId,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'dueDate': dueDate.toUtc().toIso8601String(),
      'priority': priority,
      if (description != null) 'description': description,
      if (content != null) 'content': content,
      if (divisionId != null) 'divisionId': divisionId,
      if (groupId != null) 'groupId': groupId,
      if (objectiveId != null) 'objectiveId': objectiveId,
      if (completionRequirements != null) 'completionRequirements': completionRequirements,
      if (dependencyIds != null) 'dependencyIds': dependencyIds,
      if (assigneeId != null) 'assigneeId': assigneeId,
    };
    final data = await _client.post<Map<String, dynamic>>('/tasks', body: body);
    return TaskItem.fromJson(data);
  }

  Future<TaskItem> review({
    required String id,
    required String action, // approve | reject
    required String reviewType, // division | group
    String? reason,
  }) async {
    final body = <String, dynamic>{
      'action': action,
      'reviewType': reviewType,
      if (reason != null) 'reason': reason,
    };
    final data = await _client.patch<Map<String, dynamic>>('/tasks/$id/review', body: body);
    return TaskItem.fromJson(data);
  }

  Future<TaskItem> complete({
    required String id,
    List<String> attachments = const [],
    String? note,
  }) async {
    final body = <String, dynamic>{
      'attachments': attachments,
      if (note != null) 'note': note,
    };
    final data = await _client.patch<Map<String, dynamic>>('/tasks/$id/complete', body: body);
    return TaskItem.fromJson(data);
  }

  Future<TaskItem> verifyCompletion({
    required String id,
    required String action, // approve | reject
    String? reason,
  }) async {
    final body = <String, dynamic>{
      'action': action,
      if (reason != null) 'reason': reason,
    };
    final data = await _client.patch<Map<String, dynamic>>('/tasks/$id/verify-completion', body: body);
    return TaskItem.fromJson(data);
  }

  Future<TaskItem> getById(String id) async {
    final data = await _client.get<Map<String, dynamic>>('/tasks/$id');
    return TaskItem.fromJson(data);
  }

  Future<List<TaskReview>> getReviews(String id) async {
    final data = await _client.get<List<dynamic>>('/tasks/$id/reviews');
    return data.map((e) => TaskReview.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<String>> getReviewableTypes(String id) async {
    final data = await _client.get<List<dynamic>>('/tasks/$id/reviewable-types');
    return data.map((e) => e.toString()).toList();
  }

  Future<List<TaskItem>> getDependencies(String id) async {
    final data = await _client.get<List<dynamic>>('/tasks/$id/dependencies');
    return data.map((e) => TaskItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<TaskItem> updateObjective(String id, String? objectiveId) async {
    final data = await _client.patch<Map<String, dynamic>>(
      '/tasks/$id/objective',
      body: {'objectiveId': objectiveId},
    );
    return TaskItem.fromJson(data);
  }

  Future<TaskItem> resubmit({
    required String id,
    String? title,
    String? description,
    DateTime? dueDate,
  }) async {
    final body = <String, dynamic>{
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (dueDate != null) 'dueDate': dueDate.toUtc().toIso8601String(),
    };
    final data = await _client.patch<Map<String, dynamic>>('/tasks/$id/resubmit', body: body);
    return TaskItem.fromJson(data);
  }

  Future<void> delete(String id) async {
    await _client.delete<dynamic>('/tasks/$id');
  }
}

final tasksApiProvider = Provider<TasksApi>((ref) {
  return TasksApi(ref.watch(dioClientProvider));
});
