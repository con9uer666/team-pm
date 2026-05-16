class ObjectiveSummary {
  const ObjectiveSummary({
    required this.id,
    required this.title,
    required this.scope, // 'group' | 'division'
    required this.status, // 'active' | 'completed' | 'cancelled'
    required this.dueDate,
    this.description,
    this.groupId,
    this.divisionId,
    this.totalTasks,
    this.completedTasks,
    this.manuallyCompleted = false,
  });

  final String id;
  final String title;
  final String scope;
  final String status;
  final DateTime dueDate;
  final String? description;
  final String? groupId;
  final String? divisionId;
  final int? totalTasks;
  final int? completedTasks;
  final bool manuallyCompleted;

  bool get isActive => status == 'active';

  double? get progress {
    if (totalTasks == null || totalTasks == 0) return null;
    return (completedTasks ?? 0) / totalTasks!;
  }

  factory ObjectiveSummary.fromJson(Map<String, dynamic> j) {
    return ObjectiveSummary(
      id: j['id'] as String,
      title: (j['title'] ?? '') as String,
      scope: (j['scope'] ?? '') as String,
      status: (j['status'] ?? 'active') as String,
      dueDate: DateTime.parse(j['dueDate'] as String),
      description: j['description'] as String?,
      groupId: j['groupId'] as String?,
      divisionId: j['divisionId'] as String?,
      totalTasks: j['totalTasks'] as int?,
      completedTasks: j['completedTasks'] as int?,
      manuallyCompleted: (j['manuallyCompleted'] ?? false) as bool,
    );
  }
}
