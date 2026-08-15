// Dummy data mock — swap back to SupportRepositoryImpl in support_provider.dart
// when the backend /support endpoint is live.

import '../models/support_model.dart';
import 'support_repository.dart';

class SupportRepositoryMock implements SupportRepository {
  final List<SupportTicket> _tickets = [
    SupportTicket(
      id: 'tkt-001',
      category: 'Billing',
      subject: 'Charged twice for March subscription',
      description: 'I was charged ₹149 twice on 1st March for Campus Pro plan.',
      status: 'resolved',
      createdAt: DateTime(2026, 3, 2, 10, 15),
    ),
    SupportTicket(
      id: 'tkt-002',
      category: 'Bike Issue',
      subject: 'E-Bike #B09 brakes squeaking',
      description: 'The front brake on B09 makes a loud squeaking sound. Reported at Main Gate station.',
      status: 'in_progress',
      createdAt: DateTime(2026, 3, 15, 14, 30),
    ),
    SupportTicket(
      id: 'tkt-003',
      category: 'App Bug',
      subject: 'Map not loading on Android',
      description: 'The home screen map shows a blank grey area on my Pixel 7 (Android 14).',
      status: 'open',
      createdAt: DateTime(2026, 3, 18, 9, 0),
    ),
  ];

  @override
  Future<SupportTicket> createTicket(SupportTicket ticket) async {
    await Future.delayed(const Duration(milliseconds: 700));
    final newTicket = SupportTicket(
      id: 'tkt-${(_tickets.length + 1).toString().padLeft(3, '0')}',
      category: ticket.category,
      subject: ticket.subject,
      description: ticket.description,
      status: 'open',
      createdAt: DateTime.now(),
    );
    _tickets.add(newTicket);
    return newTicket;
  }

  @override
  Future<List<SupportTicket>> getMyTickets() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return List.from(_tickets.reversed);
  }

  @override
  Future<String> sendChatMessage(String message) async {
    await Future.delayed(const Duration(milliseconds: 800));
    return 'Thanks for your message! Our support team will get back to you within 24 hours.';
  }
}
