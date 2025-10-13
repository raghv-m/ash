class AppConfig {
  // App Information
  static const String appName = 'ASH';
  static const String appDescription = 'AI Scheduling Helper';
  static const String appVersion = '1.0.0';
  
  // API Configuration
  static const String baseUrl = 'http://localhost:3000';
  static const String apiVersion = 'v1';
  
  // API Endpoints
  static const String authEndpoint = '/auth';
  static const String scheduleEndpoint = '/schedule';
  static const String eventsEndpoint = '/events';
  static const String voiceEndpoint = '/voice';
  static const String speakEndpoint = '/speak';
  
  // WebSocket Configuration
  static const String wsUrl = 'ws://localhost:3000/voice/ws';
  
  // Google OAuth Configuration
  static const String googleClientId = 'your_google_client_id_here';
  
  // Voice Configuration
  static const bool voiceEnabled = true;
  static const String defaultVoice = 'alloy';
  static const String defaultLanguage = 'en-US';
  
  // UI Configuration
  static const double borderRadius = 12.0;
  static const double cardElevation = 2.0;
  static const double buttonHeight = 48.0;
  
  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);
  
  // Storage Keys
  static const String userTokenKey = 'user_token';
  static const String userDataKey = 'user_data';
  static const String themeKey = 'theme_mode';
  static const String voiceEnabledKey = 'voice_enabled';
  static const String notificationsEnabledKey = 'notifications_enabled';
  
  // Default Settings
  static const bool defaultVoiceEnabled = true;
  static const bool defaultNotificationsEnabled = true;
  static const int defaultReminderMinutes = 30;
  static const String defaultTimeZone = 'UTC';
  
  // Working Hours
  static const String defaultWorkingStart = '09:00';
  static const String defaultWorkingEnd = '17:00';
  static const List<String> defaultWorkingDays = [
    'Monday',
    'Tuesday', 
    'Wednesday',
    'Thursday',
    'Friday'
  ];
  
  // Error Messages
  static const String networkError = 'Network connection error. Please check your internet connection.';
  static const String authError = 'Authentication failed. Please sign in again.';
  static const String voiceError = 'Voice feature is not available. Please check your microphone permissions.';
  static const String calendarError = 'Calendar access denied. Please grant calendar permissions.';
  
  // Success Messages
  static const String eventCreated = 'Event created successfully!';
  static const String eventUpdated = 'Event updated successfully!';
  static const String eventCancelled = 'Event cancelled successfully!';
  static const String reminderSet = 'Reminder set successfully!';
  
  // ASH Personality Messages
  static const List<String> greetingMessages = [
    "Hey there, I'm ASH. I manage your calendar so you don't have to. Want to check what's next on your schedule?",
    "Hello! I'm ASH, your AI scheduling assistant. How can I help you organize your time today?",
    "Hi! I'm ASH. Ready to help you schedule and manage your meetings efficiently.",
    "Welcome back! I'm ASH, your intelligent scheduling companion. What can I help you with today?"
  ];
  
  static const List<String> confirmationMessages = [
    "Got it! I'll take care of that for you.",
    "Perfect! I've got that scheduled.",
    "All set! Your meeting is now in the calendar.",
    "Done! I've handled that scheduling request."
  ];
  
  static const List<String> errorMessages = [
    "I apologize, but I encountered an issue. Let me try that again.",
    "Something went wrong there. Could you please try rephrasing your request?",
    "I'm having trouble with that. Let me help you in a different way.",
    "I didn't quite catch that. Could you be more specific about what you'd like to schedule?"
  ];
}


