import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/role.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/dio_provider.dart';

/// A user waiting for approval, surfaced by `GET /approvals/pending`.
class PendingApplicant {
  const PendingApplicant({
    required this.id,
    required this.username,
    required this.realName,
    this.email,
    required this.requestedGroupIds,
    required this.createdAt,
  });

  final String id;
  final String username;
  final String realName;
  final String? email;
  final List<String> requestedGroupIds;
  final DateTime createdAt;

  factory PendingApplicant.fromJson(Map<String, dynamic> j) {
    final raw = j['createdAt'];
    return PendingApplicant(
      id: j['id'] as String,
      username: (j['username'] ?? '') as String,
      realName: (j['realName'] ?? '') as String,
      email: j['email'] as String?,
      requestedGroupIds:
          ((j['groupIds'] as List?) ?? const []).map((e) => e.toString()).toList(),
      createdAt: raw is String
          ? (DateTime.tryParse(raw)?.toLocal() ?? DateTime.now())
          : DateTime.now(),
    );
  }
}

class ApproveDto {
  const ApproveDto({
    this.roleLevel,
    this.position,
    this.groupIds,
    this.divisionIds,
  });
  final int? roleLevel;
  final Position? position;
  final List<String>? groupIds;
  final List<String>? divisionIds;

  Map<String, dynamic> toBody() => {
        if (roleLevel != null) 'roleLevel': roleLevel,
        if (position != null) 'position': position!.value,
        if (groupIds != null) 'groupIds': groupIds,
        if (divisionIds != null) 'divisionIds': divisionIds,
      };
}

class ApprovalsApi {
  ApprovalsApi(this._client);
  final DioClient _client;

  Future<List<PendingApplicant>> listPending() async {
    final data = await _client.get<List<dynamic>>('/approvals/pending');
    return data
        .map((e) => PendingApplicant.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> approve(String userId, ApproveDto dto) async {
    await _client.patch<dynamic>(
      '/approvals/$userId/approve',
      body: dto.toBody(),
    );
  }

  Future<void> reject(String userId, String reason) async {
    await _client.patch<dynamic>(
      '/approvals/$userId/reject',
      body: {'reason': reason},
    );
  }
}

final approvalsApiProvider = Provider<ApprovalsApi>((ref) {
  return ApprovalsApi(ref.watch(dioClientProvider));
});

final pendingApplicantsProvider =
    FutureProvider.autoDispose<List<PendingApplicant>>((ref) async {
  return ref.watch(approvalsApiProvider).listPending();
});
