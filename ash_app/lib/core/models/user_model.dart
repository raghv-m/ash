class User {
  final String userId;
  final String email;
  final String name;
  final String? picture;
  final String timeZone;
  final UserPreferences preferences;
  final bool hasValidGoogleTokens;
  final DateTime lastLogin;
  final DateTime createdAt;

  const User({
    required this.userId,
    required this.email,
    required this.name,
    this.picture,
    required this.timeZone,
    required this.preferences,
    required this.hasValidGoogleTokens,
    required this.lastLogin,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['userId'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      picture: json['picture'],
      timeZone: json['timeZone'] ?? 'UTC',
      preferences: UserPreferences.fromJson(json['preferences'] ?? {}),
      hasValidGoogleTokens: json['hasValidGoogleTokens'] ?? false,
      lastLogin: DateTime.parse(json['lastLogin'] ?? DateTime.now().toIso8601String()),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'email': email,
      'name': name,
      'picture': picture,
      'timeZone': timeZone,
      'preferences': preferences.toJson(),
      'hasValidGoogleTokens': hasValidGoogleTokens,
      'lastLogin': lastLogin.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  User copyWith({
    String? userId,
    String? email,
    String? name,
    String? picture,
    String? timeZone,
    UserPreferences? preferences,
    bool? hasValidGoogleTokens,
    DateTime? lastLogin,
    DateTime? createdAt,
  }) {
    return User(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      name: name ?? this.name,
      picture: picture ?? this.picture,
      timeZone: timeZone ?? this.timeZone,
      preferences: preferences ?? this.preferences,
      hasValidGoogleTokens: hasValidGoogleTokens ?? this.hasValidGoogleTokens,
      lastLogin: lastLogin ?? this.lastLogin,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class UserPreferences {
  final bool voiceEnabled;
  final String ttsProvider;
  final int reminderMinutes;
  final WorkingHours workingHours;
  final List<String> workingDays;

  const UserPreferences({
    required this.voiceEnabled,
    required this.ttsProvider,
    required this.reminderMinutes,
    required this.workingHours,
    required this.workingDays,
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      voiceEnabled: json['voiceEnabled'] ?? true,
      ttsProvider: json['ttsProvider'] ?? 'openai',
      reminderMinutes: json['reminderMinutes'] ?? 30,
      workingHours: WorkingHours.fromJson(json['workingHours'] ?? {}),
      workingDays: List<String>.from(json['workingDays'] ?? ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'voiceEnabled': voiceEnabled,
      'ttsProvider': ttsProvider,
      'reminderMinutes': reminderMinutes,
      'workingHours': workingHours.toJson(),
      'workingDays': workingDays,
    };
  }

  UserPreferences copyWith({
    bool? voiceEnabled,
    String? ttsProvider,
    int? reminderMinutes,
    WorkingHours? workingHours,
    List<String>? workingDays,
  }) {
    return UserPreferences(
      voiceEnabled: voiceEnabled ?? this.voiceEnabled,
      ttsProvider: ttsProvider ?? this.ttsProvider,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      workingHours: workingHours ?? this.workingHours,
      workingDays: workingDays ?? this.workingDays,
    );
  }
}

class WorkingHours {
  final String start;
  final String end;

  const WorkingHours({
    required this.start,
    required this.end,
  });

  factory WorkingHours.fromJson(Map<String, dynamic> json) {
    return WorkingHours(
      start: json['start'] ?? '09:00',
      end: json['end'] ?? '17:00',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'start': start,
      'end': end,
    };
  }

  WorkingHours copyWith({
    String? start,
    String? end,
  }) {
    return WorkingHours(
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }
}


