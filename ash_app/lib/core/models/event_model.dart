class Event {
  final String id;
  final String? googleEventId;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final String? location;
  final List<Attendee> attendees;
  final EventStatus status;
  final bool reminderSent;
  final DateTime? reminderTime;
  final bool isRecurring;
  final RecurrencePattern? recurrencePattern;
  final EventMetadata metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Event({
    required this.id,
    this.googleEventId,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    this.location,
    required this.attendees,
    required this.status,
    required this.reminderSent,
    this.reminderTime,
    required this.isRecurring,
    this.recurrencePattern,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] ?? '',
      googleEventId: json['googleEventId'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      location: json['location'],
      attendees: (json['attendees'] as List<dynamic>?)
          ?.map((e) => Attendee.fromJson(e))
          .toList() ?? [],
      status: EventStatus.fromString(json['status'] ?? 'scheduled'),
      reminderSent: json['reminderSent'] ?? false,
      reminderTime: json['reminderTime'] != null 
          ? DateTime.parse(json['reminderTime']) 
          : null,
      isRecurring: json['isRecurring'] ?? false,
      recurrencePattern: json['recurrencePattern'] != null
          ? RecurrencePattern.fromJson(json['recurrencePattern'])
          : null,
      metadata: EventMetadata.fromJson(json['metadata'] ?? {}),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'googleEventId': googleEventId,
      'title': title,
      'description': description,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'location': location,
      'attendees': attendees.map((e) => e.toJson()).toList(),
      'status': status.toString(),
      'reminderSent': reminderSent,
      'reminderTime': reminderTime?.toIso8601String(),
      'isRecurring': isRecurring,
      'recurrencePattern': recurrencePattern?.toJson(),
      'metadata': metadata.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Helper methods
  bool get isFuture => startTime.isAfter(DateTime.now());
  bool get isToday {
    final now = DateTime.now();
    return startTime.year == now.year &&
           startTime.month == now.month &&
           startTime.day == now.day;
  }
  
  int get durationInMinutes {
    return endTime.difference(startTime).inMinutes;
  }

  String get durationText {
    final duration = durationInMinutes;
    if (duration < 60) {
      return '${duration}m';
    } else {
      final hours = duration ~/ 60;
      final minutes = duration % 60;
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    }
  }

  bool get shouldSendReminder {
    if (reminderSent || !isFuture) return false;
    if (reminderTime == null) return false;
    return DateTime.now().isAfter(reminderTime!);
  }

  Event copyWith({
    String? id,
    String? googleEventId,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    List<Attendee>? attendees,
    EventStatus? status,
    bool? reminderSent,
    DateTime? reminderTime,
    bool? isRecurring,
    RecurrencePattern? recurrencePattern,
    EventMetadata? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Event(
      id: id ?? this.id,
      googleEventId: googleEventId ?? this.googleEventId,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      attendees: attendees ?? this.attendees,
      status: status ?? this.status,
      reminderSent: reminderSent ?? this.reminderSent,
      reminderTime: reminderTime ?? this.reminderTime,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrencePattern: recurrencePattern ?? this.recurrencePattern,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class Attendee {
  final String email;
  final String name;
  final ResponseStatus responseStatus;

  const Attendee({
    required this.email,
    required this.name,
    required this.responseStatus,
  });

  factory Attendee.fromJson(Map<String, dynamic> json) {
    return Attendee(
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      responseStatus: ResponseStatus.fromString(json['responseStatus'] ?? 'needsAction'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'name': name,
      'responseStatus': responseStatus.toString(),
    };
  }
}

enum EventStatus {
  scheduled,
  confirmed,
  cancelled,
  rescheduled,
  completed;

  static EventStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return EventStatus.scheduled;
      case 'confirmed':
        return EventStatus.confirmed;
      case 'cancelled':
        return EventStatus.cancelled;
      case 'rescheduled':
        return EventStatus.rescheduled;
      case 'completed':
        return EventStatus.completed;
      default:
        return EventStatus.scheduled;
    }
  }

  @override
  String toString() {
    return name;
  }
}

enum ResponseStatus {
  needsAction,
  declined,
  tentative,
  accepted;

  static ResponseStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'needsaction':
        return ResponseStatus.needsAction;
      case 'declined':
        return ResponseStatus.declined;
      case 'tentative':
        return ResponseStatus.tentative;
      case 'accepted':
        return ResponseStatus.accepted;
      default:
        return ResponseStatus.needsAction;
    }
  }

  @override
  String toString() {
    return name;
  }
}

class RecurrencePattern {
  final String frequency;
  final int interval;
  final DateTime? endDate;
  final List<String> daysOfWeek;

  const RecurrencePattern({
    required this.frequency,
    required this.interval,
    this.endDate,
    required this.daysOfWeek,
  });

  factory RecurrencePattern.fromJson(Map<String, dynamic> json) {
    return RecurrencePattern(
      frequency: json['frequency'] ?? 'weekly',
      interval: json['interval'] ?? 1,
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      daysOfWeek: List<String>.from(json['daysOfWeek'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'frequency': frequency,
      'interval': interval,
      'endDate': endDate?.toIso8601String(),
      'daysOfWeek': daysOfWeek,
    };
  }
}

class EventMetadata {
  final String createdBy;
  final bool voiceConfirmed;
  final String originalRequest;
  final String aiReasoning;

  const EventMetadata({
    required this.createdBy,
    required this.voiceConfirmed,
    required this.originalRequest,
    required this.aiReasoning,
  });

  factory EventMetadata.fromJson(Map<String, dynamic> json) {
    return EventMetadata(
      createdBy: json['createdBy'] ?? 'ash',
      voiceConfirmed: json['voiceConfirmed'] ?? false,
      originalRequest: json['originalRequest'] ?? '',
      aiReasoning: json['aiReasoning'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'createdBy': createdBy,
      'voiceConfirmed': voiceConfirmed,
      'originalRequest': originalRequest,
      'aiReasoning': aiReasoning,
    };
  }
}

