class MonthlyReportKpi {
  final String label;
  final String value;

  const MonthlyReportKpi({
    required this.label,
    required this.value,
  });
}

class MonthlyReportHighlight {
  final String title;
  final String detail;

  const MonthlyReportHighlight({
    required this.title,
    required this.detail,
  });
}

class PeriodReportDocument {
  final String periodType;
  final String periodLabel;
  final DateTime generatedAt;
  final List<MonthlyReportKpi> kpis;
  final List<MonthlyReportHighlight> highlights;
  final String whatsappMessage;
  final String csvContent;

  const PeriodReportDocument({
    required this.periodType,
    required this.periodLabel,
    required this.generatedAt,
    required this.kpis,
    required this.highlights,
    required this.whatsappMessage,
    required this.csvContent,
  });
}

typedef MonthlyReportDocument = PeriodReportDocument;
