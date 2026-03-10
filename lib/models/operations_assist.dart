class OperationsAssistRecommendation {
  final String area;
  final String title;
  final String action;
  final String expectedImpact;
  final String priority;

  const OperationsAssistRecommendation({
    required this.area,
    required this.title,
    required this.action,
    required this.expectedImpact,
    required this.priority,
  });
}

class RecommendationExecutionLog {
  final String actionType;
  final String recommendationText;
  final String? notes;
  final DateTime? actedAt;

  const RecommendationExecutionLog({
    required this.actionType,
    required this.recommendationText,
    required this.notes,
    required this.actedAt,
  });
}

class DataEntryOwnershipRule {
  final String dataType;
  final String primaryRole;
  final String reviewRole;
  final String positiveImpact;

  const DataEntryOwnershipRule({
    required this.dataType,
    required this.primaryRole,
    required this.reviewRole,
    required this.positiveImpact,
  });
}

class OperationsAssistSnapshot {
  final int readinessScore;
  final List<OperationsAssistRecommendation> recommendations;
  final List<DataEntryOwnershipRule> ownershipRules;
  final Map<String, int> recommendationStatusCounts;
  final List<RecommendationExecutionLog> recommendationExecutionLogs;

  const OperationsAssistSnapshot({
    required this.readinessScore,
    required this.recommendations,
    required this.ownershipRules,
    this.recommendationStatusCounts = const {},
    this.recommendationExecutionLogs = const [],
  });
}
