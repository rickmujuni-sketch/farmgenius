import '../models/operations_assist.dart';
import 'farmgenius_content_localizer.dart';

class OperationsAssistQuestionService {
  static OperationsAssistQuestionResponse answerQuestion({
    required String question,
    required OperationsAssistQuestionContext context,
  }) {
    final normalizedQuestion = question.trim();
    final query = normalizedQuestion.toLowerCase();

    if (normalizedQuestion.isEmpty) {
      return _buildPromptResponse();
    }

    if (_containsAny(query, const [
      'verification',
      'supplier',
      'doctor',
      'payment',
      'payments',
      'approve',
      'approved',
      'external',
      'invoice',
      'uthibitisho',
      'msambazaji',
      'daktari',
      'malipo',
    ])) {
      return _buildVerificationResponse(context);
    }

    if (_containsAny(query, const [
      'weather',
      'forecast',
      'rain',
      'rainfall',
      'temperature',
      'temp',
      'humidity',
      'wind',
      'hali ya hewa',
      'mvua',
      'joto',
      'unyevu',
      'upepo',
    ])) {
      return _buildWeatherResponse(context);
    }

    if (_containsAny(query, const [
      'readiness',
      'ready',
      'prepared',
      'preparedness',
      'risk',
      'utayari',
      'hali',
    ])) {
      return _buildReadinessResponse(context);
    }

    if (_containsAny(query, const [
      'livestock',
      'herd',
      'breed',
      'goat',
      'goats',
      'sheep',
      'cattle',
      'cow',
      'heifer',
      'calf',
      'galla',
      'dorper',
      'ankole',
      'pwani',
      'tanga',
      'holstein',
      'friesian',
      'jersey',
      'mifugo',
      'mbuzi',
      'kondoo',
      'ngombe',
      "ng'ombe",
      'ndama',
    ])) {
      return _buildLivestockResponse(context, query: query);
    }

    if (_containsAny(query, const [
      'feed',
      'inventory',
      'stock',
      'reorder',
      'replenish',
      'supplies',
      'fertilizer',
      'seed',
      'chakula',
      'ghala',
      'stoo',
    ])) {
      return _buildInventoryResponse(context, query: query);
    }

    if (_containsAny(query, const [
      'medicine',
      'medication',
      'vaccine',
      'health',
      'disease',
      'vet',
      'afya',
      'chanjo',
      'dawa',
    ])) {
      return _buildHealthResponse(context, query: query);
    }

    if (_containsAny(query, const [
      'labor',
      'staff',
      'workload',
      'tasks',
      'task',
      'overdue',
      'shift',
      'attendance',
      'hiring',
      'workers',
      'wafanyakazi',
      'kazi',
      'ucheleweshaji',
    ])) {
      return _buildWorkloadResponse(context, query: query);
    }

    if (_containsAny(query, const [
      'log',
      'logs',
      'report',
      'reports',
      'activity',
      'activities',
      'recent',
      'field',
      'change',
      'trend',
      'ripoti',
      'ughuli',
    ])) {
      return _buildLogsResponse(context);
    }

    return _buildGeneralResponse(context);
  }

  static OperationsAssistQuestionResponse _buildPromptResponse() {
    return OperationsAssistQuestionResponse(
      topicKey: 'prompt',
      answer: _t(
        'Ask about readiness, livestock, feed or inventory, health, staff workload, verification, or recent logs.',
      ),
      confidenceLabel: _t('Ready'),
      evidence: const [],
      actionLabel: _t('Open Reports'),
      actionType: OperationsAssistQuestionActionType.openReports,
      taskRecommendation: null,
    );
  }

  static OperationsAssistQuestionResponse _buildReadinessResponse(
    OperationsAssistQuestionContext context,
  ) {
    final topRecommendation = _firstRecommendation(
      context.assist.recommendations,
    );
    final counts = context.assist.recommendationStatusCounts;
    final proposed = counts['proposed'] ?? 0;
    final accepted = counts['accepted'] ?? 0;
    final executed = counts['executed'] ?? 0;
    final deferred = counts['deferred'] ?? 0;

    final statusLabel = context.assist.readinessScore < 60
        ? 'under pressure'
        : context.assist.readinessScore < 80
        ? 'mixed'
        : 'stable';
    final answer = topRecommendation == null
        ? _t(
            'Farm readiness is $statusLabel at ${context.assist.readinessScore}/100. I do not see a dominant recommendation yet, so the next best step is to review forecasts and fresh field logs.',
          )
        : _t(
            'Farm readiness is $statusLabel at ${context.assist.readinessScore}/100. The strongest current signal is ${topRecommendation.title}, and that is the first issue I would act on.',
          );

    final evidence = <String>[
      _t(
        'Execution tracker: $executed executed, $accepted accepted, $proposed proposed, $deferred deferred.',
      ),
    ];

    if (topRecommendation != null) {
      evidence.add(_t('Next action: ${topRecommendation.action}'));
    }
    if (context.pendingVerificationCount > 0) {
      evidence.add(
        _t(
          '${context.pendingVerificationCount} doctor or supplier records still need verification before they should influence payments or planning.',
        ),
      );
    }

    return OperationsAssistQuestionResponse(
      topicKey: 'readiness',
      answer: answer,
      confidenceLabel: _t(
        topRecommendation == null ? 'Medium confidence' : 'High confidence',
      ),
      evidence: evidence,
      actionLabel: _t(
        topRecommendation == null
            ? 'Open Forecast Engine'
            : 'Create Follow-up Task',
      ),
      actionType: topRecommendation == null
          ? OperationsAssistQuestionActionType.openForecast
          : OperationsAssistQuestionActionType.createTask,
      taskRecommendation: topRecommendation == null
          ? null
          : '${topRecommendation.title}. ${topRecommendation.action}',
    );
  }

  static OperationsAssistQuestionResponse _buildLivestockResponse(
    OperationsAssistQuestionContext context,
    {
    required String query,
  }
  ) {
    if (_isLivestockCountQuestion(query)) {
      final requestedSpecies = _requestedLivestockSpecies(query);

      if (requestedSpecies != null) {
        final speciesCount = _countForSpecies(
          context.livestockCountBySpecies,
          requestedSpecies,
        );

        if (speciesCount == null) {
          return OperationsAssistQuestionResponse(
            topicKey: 'livestock',
            answer: _t(
              'I cannot confirm a reliable ${_speciesDisplayLabel(requestedSpecies)} count from the current owner snapshot yet. Please sync biological asset records and species-level stock updates first.',
            ),
            confidenceLabel: _t('Limited confidence'),
            evidence: [
              _t(
                'Current tracked total livestock count: ${context.totalLivestockCount}.',
              ),
              _t(
                'Tracked breed recommendation sets: ${context.breedRecommendationCount}.',
              ),
            ],
            actionLabel: _t('Open Breed Recommendations'),
            actionType:
                OperationsAssistQuestionActionType.openBreedRecommendations,
            taskRecommendation: null,
          );
        }

        return OperationsAssistQuestionResponse(
          topicKey: 'livestock',
          answer: _t(
            'Yes. The current tracked ${_speciesDisplayLabel(requestedSpecies)} count is $speciesCount.',
          ),
          confidenceLabel: _t('High confidence'),
          evidence: [
            _t(
              'Current tracked total livestock count: ${context.totalLivestockCount}.',
            ),
            if (context.latestLivestockStockUpdateAt != null)
              _t(
                'Latest stock update: ${_formatDate(context.latestLivestockStockUpdateAt!)}.',
              ),
            _t(
              'Tracked breed recommendation sets: ${context.breedRecommendationCount}.',
            ),
          ],
          actionLabel: _t('Open Breed Recommendations'),
          actionType: OperationsAssistQuestionActionType.openBreedRecommendations,
          taskRecommendation: null,
        );
      }

      if (context.totalLivestockCount <= 0) {
        return OperationsAssistQuestionResponse(
          topicKey: 'livestock',
          answer: _t(
            'I cannot confirm a reliable livestock count from the current owner snapshot yet. Please sync biological asset records and breed stock updates first.',
          ),
          confidenceLabel: _t('Limited confidence'),
          evidence: [
            _t(
              'Tracked breed recommendation sets: ${context.breedRecommendationCount}.',
            ),
          ],
          actionLabel: _t('Open Breed Recommendations'),
          actionType: OperationsAssistQuestionActionType.openBreedRecommendations,
          taskRecommendation: null,
        );
      }

      final speciesRows = context.livestockCountBySpecies.entries.toList()
        ..sort((left, right) {
          final countCompare = right.value.compareTo(left.value);
          if (countCompare != 0) return countCompare;
          return left.key.compareTo(right.key);
        });

      final speciesSummary = speciesRows
          .map((entry) => '${_titleCase(entry.key)} ${entry.value}')
          .join(', ');

      return OperationsAssistQuestionResponse(
        topicKey: 'livestock',
        answer: _t(
          'Yes. The current tracked livestock count is ${context.totalLivestockCount}.',
        ),
        confidenceLabel: _t('High confidence'),
        evidence: [
          if (speciesSummary.isNotEmpty)
            _t('Species breakdown: $speciesSummary.'),
          if (context.latestLivestockStockUpdateAt != null)
            _t(
              'Latest stock update: ${_formatDate(context.latestLivestockStockUpdateAt!)}.',
            ),
          _t(
            'Tracked breed recommendation sets: ${context.breedRecommendationCount}.',
          ),
        ],
        actionLabel: _t('Open Breed Recommendations'),
        actionType: OperationsAssistQuestionActionType.openBreedRecommendations,
        taskRecommendation: null,
      );
    }

    if (context.livestockFocusSpecies == null ||
        context.livestockFocusHerdSize <= 0) {
      final healthRecommendation = _findRecommendation(
        context.assist.recommendations,
        areas: const ['medication_vaccine'],
      );
      return OperationsAssistQuestionResponse(
        topicKey: 'livestock',
        answer: _t(
          'I do not have enough ranked livestock data to name a single herd group yet. The strongest animal-care signal in the current snapshot is ${healthRecommendation?.title ?? 'to review recent livestock health logs and breed records'}.',
        ),
        confidenceLabel: _t('Medium confidence'),
        evidence: [
          _t(
            'Tracked breed recommendation sets: ${context.breedRecommendationCount}.',
          ),
          if (healthRecommendation != null)
            _t('Recommended follow-up: ${healthRecommendation.action}'),
        ],
        actionLabel: _t('Open Breed Recommendations'),
        actionType: OperationsAssistQuestionActionType.openBreedRecommendations,
        taskRecommendation: healthRecommendation == null
            ? null
            : '${healthRecommendation.title}. ${healthRecommendation.action}',
      );
    }

    final answer = _t(
      'Start with ${_titleCase(context.livestockFocusSpecies!)}. It has the largest tracked herd in the current owner snapshot (${context.livestockFocusHerdSize}) and the strongest improvement path currently points to ${context.livestockFocusBreed ?? 'a targeted breed review'}.',
    );

    final evidence = <String>[
      _t(
        'Tracked herd size: ${context.livestockFocusHerdSize} for ${_titleCase(context.livestockFocusSpecies!)}.',
      ),
      if (context.livestockFocusReason != null &&
          context.livestockFocusReason!.isNotEmpty)
        _t('Reason: ${context.livestockFocusReason!}'),
      if (context.livestockMaintenanceFocus != null &&
          context.livestockMaintenanceFocus!.isNotEmpty)
        _t('Maintenance focus: ${context.livestockMaintenanceFocus!}'),
      if (context.gestationStock > 0 || context.newbornStock > 0)
        _t(
          'Current stock signals: ${context.gestationStock} gestation records and ${context.newbornStock} newborn records.',
        ),
    ];

    return OperationsAssistQuestionResponse(
      topicKey: 'livestock',
      answer: answer,
      confidenceLabel: _t('High confidence'),
      evidence: evidence,
      actionLabel: _t('Open Breed Recommendations'),
      actionType: OperationsAssistQuestionActionType.openBreedRecommendations,
      taskRecommendation: null,
    );
  }

  static OperationsAssistQuestionResponse _buildInventoryResponse(
    OperationsAssistQuestionContext context,
    {
    required String query,
  }
  ) {
    if (_isCountQuestion(query)) {
      return OperationsAssistQuestionResponse(
        topicKey: 'inventory',
        answer: _t(
          'Current inventory/procurement alert count is ${context.inventoryAlertCount}.',
        ),
        confidenceLabel: _t('Medium confidence'),
        evidence: [
          _t(
            'This reflects recommendation signals for inventory, stock, or procurement in the current owner snapshot.',
          ),
        ],
        actionLabel: _t('Open Reports'),
        actionType: OperationsAssistQuestionActionType.openReports,
        taskRecommendation: null,
      );
    }

    final recommendation = _findRecommendation(
      context.assist.recommendations,
      areas: const ['inventory', 'procurement'],
    );

    if (recommendation == null) {
      return OperationsAssistQuestionResponse(
        topicKey: 'inventory',
        answer: _t(
          'I do not see a strong inventory or procurement alert in the current owner snapshot. The safer next step is to inspect recent logs and confirm that feed, medicine, and input usage are being recorded consistently.',
        ),
        confidenceLabel: _t('Medium confidence'),
        evidence: [
          _t('Recent field logs available: ${context.recentFieldLogCount}.'),
          _t('Tracked active bioassets: ${context.activeBioAssetCount}.'),
        ],
        actionLabel: _t('Open Reports'),
        actionType: OperationsAssistQuestionActionType.openReports,
        taskRecommendation: null,
      );
    }

    return OperationsAssistQuestionResponse(
      topicKey: 'inventory',
      answer: _t(
        'The clearest stock and spend signal right now is ${recommendation.title}. ${recommendation.expectedImpact}',
      ),
      confidenceLabel: _t('High confidence'),
      evidence: [
        _t('Recommended move: ${recommendation.action}'),
        _t('Recent field logs available: ${context.recentFieldLogCount}.'),
      ],
      actionLabel: _t('Create Restock Task'),
      actionType: OperationsAssistQuestionActionType.createTask,
      taskRecommendation: '${recommendation.title}. ${recommendation.action}',
    );
  }

  static OperationsAssistQuestionResponse _buildHealthResponse(
    OperationsAssistQuestionContext context,
    {
    required String query,
  }
  ) {
    if (_isCountQuestion(query)) {
      return OperationsAssistQuestionResponse(
        topicKey: 'health',
        answer: _t(
          'Current medication/vaccine-related alert count is ${context.medicationAlertCount}.',
        ),
        confidenceLabel: _t('Medium confidence'),
        evidence: [
          _t(
            'This reflects health and treatment recommendation signals in the current owner snapshot.',
          ),
        ],
        actionLabel: _t('Open Reports'),
        actionType: OperationsAssistQuestionActionType.openReports,
        taskRecommendation: null,
      );
    }

    final recommendation = _findRecommendation(
      context.assist.recommendations,
      areas: const ['medication_vaccine'],
    );

    if (recommendation == null) {
      return OperationsAssistQuestionResponse(
        topicKey: 'health',
        answer: _t(
          'There is no dominant medication or vaccine alert in the current owner snapshot. Keep batch-level treatment records complete so the next health signal is easier to trust.',
        ),
        confidenceLabel: _t('Medium confidence'),
        evidence: [
          _t(
            'Recent check coverage: ${context.last30DayCheckCount} checks in the last 30 days (${context.last30DayCheckDeltaLabel}).',
          ),
        ],
        actionLabel: _t('Open Reports'),
        actionType: OperationsAssistQuestionActionType.openReports,
        taskRecommendation: null,
      );
    }

    return OperationsAssistQuestionResponse(
      topicKey: 'health',
      answer: _t(
        'The strongest health signal is ${recommendation.title}. ${recommendation.expectedImpact}',
      ),
      confidenceLabel: _t('High confidence'),
      evidence: [
        _t('Recommended move: ${recommendation.action}'),
        _t(
          'Recent check coverage: ${context.last30DayCheckCount} checks in the last 30 days (${context.last30DayCheckDeltaLabel}).',
        ),
      ],
      actionLabel: _t('Create Health Follow-up Task'),
      actionType: OperationsAssistQuestionActionType.createTask,
      taskRecommendation: '${recommendation.title}. ${recommendation.action}',
    );
  }

  static OperationsAssistQuestionResponse _buildWorkloadResponse(
    OperationsAssistQuestionContext context,
    {
    required String query,
  }
  ) {
    if (_isCountQuestion(query)) {
      return OperationsAssistQuestionResponse(
        topicKey: 'workload',
        answer: _t(
          'Current bioasset execution tasks: ${context.bioAssetTaskPendingCount} pending, ${context.bioAssetTaskOverdueCount} overdue, and ${context.bioAssetTaskCompletedCount} completed.',
        ),
        confidenceLabel: _t('High confidence'),
        evidence: [
          _t(
            'Counts come from owner bioasset execution tasks in the current dashboard snapshot.',
          ),
        ],
        actionLabel: _t('Open Reports'),
        actionType: OperationsAssistQuestionActionType.openReports,
        taskRecommendation: null,
      );
    }

    final recommendation = _findRecommendation(
      context.assist.recommendations,
      areas: const ['hiring', 'planting'],
    );

    if (recommendation == null) {
      return OperationsAssistQuestionResponse(
        topicKey: 'workload',
        answer: _t(
          'I do not have a direct overdue-task count in this owner snapshot. The current signal is mostly about keeping task execution and field reporting current so workload pressure becomes visible earlier.',
        ),
        confidenceLabel: _t('Limited confidence'),
        evidence: [
          _t(
            'Recommendation tracker currently shows ${context.assist.recommendationStatusCounts['executed'] ?? 0} executed items.',
          ),
        ],
        actionLabel: _t('Open Reports'),
        actionType: OperationsAssistQuestionActionType.openReports,
        taskRecommendation: null,
      );
    }

    return OperationsAssistQuestionResponse(
      topicKey: 'workload',
      answer: _t(
        'Workload pressure is most visible in ${recommendation.title}. I cannot confirm the exact overdue count from this card alone, but this recommendation is the best current signal for where labor or timing is tightening.',
      ),
      confidenceLabel: _t('Medium confidence'),
      evidence: [
        _t('Recommended move: ${recommendation.action}'),
        _t(recommendation.expectedImpact),
      ],
      actionLabel: _t('Create Workload Task'),
      actionType: OperationsAssistQuestionActionType.createTask,
      taskRecommendation: '${recommendation.title}. ${recommendation.action}',
    );
  }

  static OperationsAssistQuestionResponse _buildVerificationResponse(
    OperationsAssistQuestionContext context,
  ) {
    final recommendation = _findRecommendation(
      context.assist.recommendations,
      areas: const ['external_services'],
    );

    if (context.pendingVerificationCount <= 0) {
      return OperationsAssistQuestionResponse(
        topicKey: 'verification',
        answer: _t(
          'There are no pending doctor or supplier entries waiting for verification in the current owner snapshot.',
        ),
        confidenceLabel: _t('High confidence'),
        evidence: [
          if (recommendation != null) _t(recommendation.expectedImpact),
        ],
        actionLabel: _t('Open Reports'),
        actionType: OperationsAssistQuestionActionType.openReports,
        taskRecommendation: null,
      );
    }

    return OperationsAssistQuestionResponse(
      topicKey: 'verification',
      answer: _t(
        '${context.pendingVerificationCount} doctor or supplier records are still waiting for owner-side verification. That queue should be cleared before those records drive payments or analytics.',
      ),
      confidenceLabel: _t('High confidence'),
      evidence: [
        if (recommendation != null)
          _t('Recommended move: ${recommendation.action}'),
      ],
      actionLabel: _t('Review Verification Queue'),
      actionType: OperationsAssistQuestionActionType.reviewVerificationQueue,
      taskRecommendation: recommendation == null
          ? null
          : '${recommendation.title}. ${recommendation.action}',
    );
  }

  static OperationsAssistQuestionResponse _buildLogsResponse(
    OperationsAssistQuestionContext context,
  ) {
    final topRecommendation = _firstRecommendation(
      context.assist.recommendations,
    );

    return OperationsAssistQuestionResponse(
      topicKey: 'logs',
      answer: _t(
        'Recent reporting coverage shows ${context.recentFieldLogCount} field logs overall and ${context.last30DayCheckCount} daily checks in the last 30 days (${context.last30DayCheckDeltaLabel}). ${topRecommendation == null ? 'The next step is to inspect the report center for recent trends.' : 'The biggest recent change worth reviewing next is ${topRecommendation.title}.'}',
      ),
      confidenceLabel: _t('High confidence'),
      evidence: [
        if (topRecommendation != null)
          _t('Suggested review: ${topRecommendation.action}'),
      ],
      actionLabel: _t('Open Reports'),
      actionType: OperationsAssistQuestionActionType.openReports,
      taskRecommendation: null,
    );
  }

  static OperationsAssistQuestionResponse _buildWeatherResponse(
    OperationsAssistQuestionContext context,
  ) {
    final weatherRecommendation = _findRecommendation(
      context.assist.recommendations,
      areas: const [
        'forecast',
        'weather',
        'rain',
        'irrigation',
        'planting',
      ],
    );

    if (weatherRecommendation == null) {
      return OperationsAssistQuestionResponse(
        topicKey: 'weather',
        answer: _t(
          'I cannot confirm live weather conditions from this owner snapshot alone. Open the Forecast Engine to view current farm weather and short-term risk outlook.',
        ),
        confidenceLabel: _t('Limited confidence'),
        evidence: [
          _t(
            'This assistant card uses owner dashboard snapshot data and does not embed live weather values directly.',
          ),
        ],
        actionLabel: _t('Open Forecast Engine'),
        actionType: OperationsAssistQuestionActionType.openForecast,
        taskRecommendation: null,
      );
    }

    return OperationsAssistQuestionResponse(
      topicKey: 'weather',
      answer: _t(
        'The strongest weather-related signal in the current owner snapshot is ${weatherRecommendation.title}. For live conditions and forecast values, open the Forecast Engine.',
      ),
      confidenceLabel: _t('Medium confidence'),
      evidence: [
        _t('Recommended move: ${weatherRecommendation.action}'),
        _t(weatherRecommendation.expectedImpact),
      ],
      actionLabel: _t('Open Forecast Engine'),
      actionType: OperationsAssistQuestionActionType.openForecast,
      taskRecommendation:
          '${weatherRecommendation.title}. ${weatherRecommendation.action}',
    );
  }

  static OperationsAssistQuestionResponse _buildGeneralResponse(
    OperationsAssistQuestionContext context,
  ) {
    final topRecommendation = _firstRecommendation(
      context.assist.recommendations,
    );
    final answer = topRecommendation == null
        ? _t(
            'From the current owner snapshot, readiness is ${context.assist.readinessScore}/100 and the clearest next step is to review forecasts, verification, and recent field logs together.',
          )
        : _t(
            'From the current owner snapshot, readiness is ${context.assist.readinessScore}/100 and the leading action is ${topRecommendation.title}.',
          );

    return OperationsAssistQuestionResponse(
      topicKey: 'general',
      answer: answer,
      confidenceLabel: _t('Medium confidence'),
      evidence: [
        if (topRecommendation != null)
          _t('Next action: ${topRecommendation.action}'),
        if (context.pendingVerificationCount > 0)
          _t(
            '${context.pendingVerificationCount} external entries still need verification.',
          ),
        _t(
          'Recent check coverage: ${context.last30DayCheckCount} in the last 30 days (${context.last30DayCheckDeltaLabel}).',
        ),
      ],
      actionLabel: _t(
        topRecommendation == null ? 'Open Reports' : 'Create Follow-up Task',
      ),
      actionType: topRecommendation == null
          ? OperationsAssistQuestionActionType.openReports
          : OperationsAssistQuestionActionType.createTask,
      taskRecommendation: topRecommendation == null
          ? null
          : '${topRecommendation.title}. ${topRecommendation.action}',
    );
  }

  static OperationsAssistRecommendation? _firstRecommendation(
    List<OperationsAssistRecommendation> recommendations,
  ) {
    if (recommendations.isEmpty) {
      return null;
    }
    return recommendations.first;
  }

  static OperationsAssistRecommendation? _findRecommendation(
    List<OperationsAssistRecommendation> recommendations, {
    required List<String> areas,
  }) {
    for (final recommendation in recommendations) {
      final haystack =
          '${recommendation.area} ${recommendation.title} ${recommendation.action}'
              .toLowerCase();
      for (final area in areas) {
        if (haystack.contains(area.toLowerCase())) {
          return recommendation;
        }
      }
    }

    return null;
  }

  static bool _containsAny(String value, List<String> keywords) {
    for (final keyword in keywords) {
      if (value.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  static bool _isLivestockCountQuestion(String query) {
    return _isCountQuestion(query);
  }

  static String? _requestedLivestockSpecies(String query) {
    final normalized = query.toLowerCase();
    final species = _canonicalLivestockSpecies(normalized);
    if (species != null) {
      return species;
    }

    return null;
  }

  static int? _countForSpecies(Map<String, int> bySpecies, String species) {
    var total = 0;
    var found = false;

    for (final entry in bySpecies.entries) {
      final canonical = _canonicalLivestockSpecies(entry.key.toLowerCase());
      if (canonical == species) {
        total += entry.value;
        found = true;
      }
    }

    return found ? total : null;
  }

  static String _speciesDisplayLabel(String canonicalSpecies) {
    switch (canonicalSpecies) {
      case 'goats':
        return 'goats';
      case 'sheep':
        return 'sheep';
      case 'cattle':
        return 'cattle';
      default:
        return canonicalSpecies;
    }
  }

  static String? _canonicalLivestockSpecies(String value) {
    if (_containsAny(value, const ['goat', 'goats', 'mbuzi', 'galla'])) {
      return 'goats';
    }

    if (_containsAny(value, const ['sheep', 'kondoo', 'dorper', 'lamb'])) {
      return 'sheep';
    }

    if (_containsAny(value, const [
      'cattle',
      'cow',
      'cows',
      'heifer',
      'calf',
      'calves',
      'bull',
      'steer',
      'ngombe',
      "ng'ombe",
      'ndama',
      'ankole',
      'holstein',
      'friesian',
      'jersey',
      'pwani',
      'tanga',
    ])) {
      return 'cattle';
    }

    return null;
  }

  static bool _isCountQuestion(String query) {
    const countWords = [
      'count',
      'how many',
      'total',
      'number',
      'headcount',
      'idadi',
      'jumla',
      'hesabu',
    ];
    return _containsAny(query, countWords);
  }

  static String _formatDate(DateTime value) {
    final monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = monthNames[value.month - 1];
    return '${value.day.toString().padLeft(2, '0')} $month ${value.year}';
  }

  static String _titleCase(String value) {
    if (value.trim().isEmpty) {
      return value;
    }

    return value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) {
          final lower = part.toLowerCase();
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');
  }

  static String _t(String value) {
    return FarmGeniusContentLocalizer.localizePlainText(value);
  }
}
