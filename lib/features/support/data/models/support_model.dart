class SupportTicket {
  final String id;
  final String category;
  final String subject;
  final String description;
  final String status; // open, in_progress, resolved, closed
  final DateTime createdAt;
  final String? bikeId;
  final String? stationId;

  const SupportTicket({
    required this.id,
    required this.category,
    required this.subject,
    required this.description,
    this.status = 'open',
    required this.createdAt,
    this.bikeId,
    this.stationId,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    // Backend Issues struct: id, user_id, station_id, bike_id, description, status, type
    return SupportTicket(
      id: json['id'] as String? ?? '',
      category: json['category'] as String? ?? json['type'] as String? ?? '',
      subject: json['subject'] as String? ?? json['type'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'open',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      bikeId: json['bike_id'] as String?,
      stationId: json['station_id'] as String?,
    );
  }

  /// Sends as backend CreateIssueReq: {bike_id, description, type}
  Map<String, dynamic> toJson() => {
        'bike_id': bikeId ?? '',
        'description': description,
        'type': category.isNotEmpty ? category : 'general',
      };
}
