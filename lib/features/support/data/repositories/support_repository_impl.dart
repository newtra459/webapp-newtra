import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/support_model.dart';
import 'support_repository.dart';

class SupportRepositoryImpl implements SupportRepository {
  final ApiClient _api;

  SupportRepositoryImpl(this._api);

  @override
  Future<SupportTicket> createTicket(SupportTicket ticket) async {
    final res = await _api.post(ApiEndpoints.support.createTicket, data: ticket.toJson());
    return SupportTicket.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<List<SupportTicket>> getMyTickets() async {
    final res = await _api.get(ApiEndpoints.support.myTickets);
    final list = res.data['data'] as List? ?? [];
    return list.map((e) => SupportTicket.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<String> sendChatMessage(String message) async {
    // Backend /faqs/ is GET-only (returns FAQ list), no chat endpoint exists.
    // Return empty string gracefully.
    try {
      final res = await _api.get(ApiEndpoints.support.chat);
      final root = (res.data is Map<String, dynamic>)
          ? (res.data as Map<String, dynamic>)
          : <String, dynamic>{};
      // FAQs response is paginated: {data: {data: [...], pagination: {...}}}
      final data = root['data'];
      if (data is Map<String, dynamic>) {
        final faqs = data['data'] as List? ?? [];
        if (faqs.isNotEmpty) {
          final faq = faqs.first as Map<String, dynamic>;
          return faq['answer'] as String? ?? '';
        }
      }
      return '';
    } catch (_) {
      return '';
    }
  }
}
