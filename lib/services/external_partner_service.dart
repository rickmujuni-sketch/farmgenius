import '../models/external_partner_entry.dart';
import 'supabase_service.dart';

class ExternalPartnerService {
  static const _table = 'external_partner_entries';

  static Future<List<ExternalPartnerEntry>> getEntries({
    bool pendingOnly = false,
    String? submittedBy,
    int limit = 40,
  }) async {
    try {
      var query = SupabaseService.client
          .from(_table)
          .select('id,partner_type,entry_kind,partner_name,service_date,description,amount_tzs,payment_status,verification_status,submitted_by,reviewed_by,reviewed_at,created_at');

      if (pendingOnly) {
        query = query.eq('verification_status', 'pending_review');
      }
      if (submittedBy != null && submittedBy.isNotEmpty) {
        query = query.eq('submitted_by', submittedBy);
      }

      final rows = await query.order('created_at', ascending: false).limit(limit);
      if (rows is List) {
        return rows
            .whereType<Map<String, dynamic>>()
            .map(ExternalPartnerEntry.fromMap)
            .toList();
      }
    } catch (_) {}

    return const [];
  }

  static Future<void> submitEntry({
    required String partnerType,
    required String entryKind,
    required String partnerName,
    required DateTime serviceDate,
    String? description,
    double amountTzs = 0,
    String paymentStatus = 'pending',
  }) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Authentication required');
    }

    await SupabaseService.client.from(_table).insert({
      'id': 'ext_${DateTime.now().millisecondsSinceEpoch}',
      'partner_type': partnerType,
      'entry_kind': entryKind,
      'partner_name': partnerName,
      'service_date': serviceDate.toIso8601String(),
      'description': description,
      'amount_tzs': amountTzs,
      'payment_status': paymentStatus,
      'verification_status': 'pending_review',
      'submitted_by': userId,
      'metadata': {
        'submitted_via': 'mobile_app',
      },
    });
  }

  static Future<void> reviewEntry({
    required String entryId,
    required bool approved,
    String? reviewNote,
  }) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Authentication required');
    }

    await SupabaseService.client.from(_table).update({
      'verification_status': approved ? 'approved' : 'rejected',
      'reviewed_by': userId,
      'reviewed_at': DateTime.now().toIso8601String(),
      'payment_status': approved ? 'approved_for_payment' : 'disputed',
      'metadata': {
        'review_note': reviewNote ?? '',
      },
    }).eq('id', entryId);
  }
}
