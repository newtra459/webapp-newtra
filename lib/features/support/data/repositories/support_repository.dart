import '../models/support_model.dart';

abstract class SupportRepository {
  Future<SupportTicket> createTicket(SupportTicket ticket);
  Future<List<SupportTicket>> getMyTickets();
  Future<String> sendChatMessage(String message);
}
