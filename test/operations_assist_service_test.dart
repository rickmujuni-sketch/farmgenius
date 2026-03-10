import 'package:farmgenius/services/operations_assist_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OperationsAssistService retrospective quality', () {
    test('flags cross-domain quality gaps from mistakes and unresolved issues', () {
      final now = DateTime(2026, 3, 10);
      final logs = [
        {
          'activity': 'HEALTH_CHECK',
          'notes': 'Checked livestock quickly',
          'photo_urls': null,
        },
        {
          'activity': 'PLANTING',
          'notes': 'Financial Category: fertilizer',
          'photo_urls': <String, dynamic>{},
        },
        {
          'activity': 'MAINTENANCE',
          'notes': 'Repair done without evidence',
          'photo_urls': null,
        },
        {
          'activity': 'TRACTOR_REPAIR',
          'notes': '',
          'photo_urls': null,
        },
      ];

      final tasks = [
        {
          'activity': 'PLANTING',
          'status': 'PENDING',
          'due_date': now.subtract(const Duration(days: 2)).toIso8601String(),
        },
        {
          'activity': 'HEALTH_CHECK',
          'status': 'IN_PROGRESS',
          'due_date': now.subtract(const Duration(days: 1)).toIso8601String(),
        },
      ];

      final anomalies = [
        {
          'type': 'health_alert',
          'status': 'OPEN',
        },
      ];

      final recommendations = OperationsAssistService.buildRetrospectiveRecommendationsForTest(
        logs: logs,
        tasks: tasks,
        anomalies: anomalies,
        now: now,
      );

      expect(recommendations, isNotEmpty);
      expect(
        recommendations.any((r) =>
            r.area == 'retrospective_quality' &&
            (r.title.toLowerCase().contains('livestock') ||
                r.title.toLowerCase().contains('plants') ||
                r.title.toLowerCase().contains('tools') ||
                r.title.toLowerCase().contains('infrastructure'))),
        isTrue,
      );
    });

    test('recommends replication when a domain shows strong practice consistency', () {
      final now = DateTime(2026, 3, 10);
      final logs = List.generate(
        5,
        (index) => {
          'activity': 'PLANTING',
          'notes': 'Effort Hours: 2.0\nFinancial Category: fertilizer\nExecution complete',
          'photo_urls': {
            'proof': 'https://example.com/photo_$index.jpg',
          },
        },
      );

      final recommendations = OperationsAssistService.buildRetrospectiveRecommendationsForTest(
        logs: logs,
        tasks: const [],
        anomalies: const [],
        now: now,
      );

      expect(
        recommendations.any((r) =>
            r.area == 'best_practices' && r.title.toLowerCase().contains('plants')),
        isTrue,
      );
    });
  });
}
