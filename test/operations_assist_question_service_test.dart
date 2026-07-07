import 'package:flutter_test/flutter_test.dart';
import 'package:farmgenius/models/operations_assist.dart';
import 'package:farmgenius/services/operations_assist_question_service.dart';

void main() {
  OperationsAssistQuestionContext buildContext({
    int totalLivestockCount = 0,
    Map<String, int> livestockCountBySpecies = const {},
    DateTime? latestLivestockStockUpdateAt,
    int bioAssetTaskPendingCount = 0,
    int bioAssetTaskOverdueCount = 0,
    int bioAssetTaskCompletedCount = 0,
    int inventoryAlertCount = 0,
    int medicationAlertCount = 0,
    String? livestockFocusSpecies,
    int livestockFocusHerdSize = 0,
  }) {
    return OperationsAssistQuestionContext(
      assist: const OperationsAssistSnapshot(
        readinessScore: 78,
        recommendations: [],
        ownershipRules: [],
      ),
      recentFieldLogCount: 5,
      last30DayCheckCount: 12,
      last30DayCheckDeltaLabel: '+10%',
      pendingVerificationCount: 0,
      activeBioAssetCount: 20,
      gestationStock: 4,
      newbornStock: 3,
      unhealthyTrees: 0,
      breedRecommendationCount: 2,
      totalLivestockCount: totalLivestockCount,
      livestockCountBySpecies: livestockCountBySpecies,
      latestLivestockStockUpdateAt: latestLivestockStockUpdateAt,
      bioAssetTaskPendingCount: bioAssetTaskPendingCount,
      bioAssetTaskOverdueCount: bioAssetTaskOverdueCount,
      bioAssetTaskCompletedCount: bioAssetTaskCompletedCount,
      inventoryAlertCount: inventoryAlertCount,
      medicationAlertCount: medicationAlertCount,
      livestockFocusSpecies: livestockFocusSpecies,
      livestockFocusHerdSize: livestockFocusHerdSize,
      livestockFocusBreed: null,
      livestockFocusReason: null,
      livestockMaintenanceFocus: null,
    );
  }

  group('OperationsAssistQuestionService livestock count', () {
    test('returns species-specific count for goat questions', () {
      final response = OperationsAssistQuestionService.answerQuestion(
        question: 'number of goats?',
        context: buildContext(
          totalLivestockCount: 67,
          livestockCountBySpecies: const {
            'cattle': 50,
            'goats': 17,
          },
          livestockFocusSpecies: 'cattle',
          livestockFocusHerdSize: 50,
        ),
      );

      expect(response.topicKey, 'livestock');
      final normalized = response.answer.toLowerCase();
      expect(normalized, contains('goats'));
      expect(normalized, contains('17'));
    });

    test('returns exact livestock total when asked for count', () {
      final response = OperationsAssistQuestionService.answerQuestion(
        question: 'Do we have a livestock count?',
        context: buildContext(
          totalLivestockCount: 67,
          livestockCountBySpecies: const {
            'cattle': 50,
            'goats': 17,
          },
          livestockFocusSpecies: 'cattle',
          livestockFocusHerdSize: 50,
        ),
      );

      expect(response.topicKey, 'livestock');
      expect(response.answer.toLowerCase(), contains('67'));
      expect(
        response.evidence.join(' ').toLowerCase(),
        contains('cattle 50'),
      );
      expect(
        response.evidence.join(' ').toLowerCase(),
        contains('goats 17'),
      );
    });

    test('returns limited confidence when livestock count is unavailable', () {
      final response = OperationsAssistQuestionService.answerQuestion(
        question: 'How many livestock do we have?',
        context: buildContext(),
      );

      expect(response.topicKey, 'livestock');
      expect(response.confidenceLabel.toLowerCase(), contains('limited'));
    });

    test('returns task counts for workload count questions', () {
      final response = OperationsAssistQuestionService.answerQuestion(
        question: 'How many overdue tasks do we have?',
        context: buildContext(
          bioAssetTaskPendingCount: 8,
          bioAssetTaskOverdueCount: 3,
          bioAssetTaskCompletedCount: 12,
        ),
      );

      expect(response.topicKey, 'workload');
      final normalized = response.answer.toLowerCase();
      expect(normalized, contains('8'));
      expect(normalized, contains('3'));
      expect(normalized, contains('12'));
    });

    test('returns medication alert count for medicine count questions', () {
      final response = OperationsAssistQuestionService.answerQuestion(
        question: 'How many medicine alerts are there?',
        context: buildContext(medicationAlertCount: 4),
      );

      expect(response.topicKey, 'health');
      expect(response.answer.toLowerCase(), contains('4'));
    });
  });

  group('OperationsAssistQuestionService weather questions', () {
    test('routes weather question to weather topic response', () {
      final response = OperationsAssistQuestionService.answerQuestion(
        question: 'what is the weather like at the farm?',
        context: buildContext(
          totalLivestockCount: 67,
          livestockCountBySpecies: const {
            'cattle': 50,
            'goats': 17,
          },
        ),
      );

      expect(response.topicKey, 'weather');
      expect(response.actionType, OperationsAssistQuestionActionType.openForecast);
      expect(response.actionLabel.toLowerCase(), contains('forecast'));
    });
  });
}
