import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'dart:async';
import 'dart:convert';

import '../models/event_model.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

// Events State
class EventsState {
  final List<Event> events;
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdated;

  const EventsState({
    this.events = const [],
    this.isLoading = false,
    this.error,
    this.lastUpdated,
  });

  EventsState copyWith({
    List<Event>? events,
    bool? isLoading,
    String? error,
    DateTime? lastUpdated,
  }) {
    return EventsState(
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

// Events Notifier
class EventsNotifier extends StateNotifier<EventsState> {
  final ApiService _apiService;
  Timer? _refreshTimer;

  EventsNotifier(this._apiService) : super(const EventsState()) {
    _startPeriodicRefresh();
  }

  // Start periodic refresh every 5 minutes
  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (state.events.isNotEmpty) {
        refreshEvents();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // Load events from API
  Future<void> loadEvents({String? token}) async {
    if (token == null) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _apiService.get(
        '/events/upcoming',
        token: token,
        queryParams: {'limit': '10'},
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final eventsData = responseData['events'] as List<dynamic>;
        final events = eventsData.map((e) => Event.fromJson(e)).toList();

        state = state.copyWith(
          events: events,
          isLoading: false,
          lastUpdated: DateTime.now(),
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load events',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Network error: ${e.toString()}',
      );
    }
  }

  // Refresh events
  Future<void> refreshEvents() async {
    final token = _getCurrentToken();
    if (token != null) {
      await loadEvents(token: token);
    }
  }

  // Get upcoming events
  Future<void> loadUpcomingEvents({String? token}) async {
    if (token == null) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _apiService.get(
        '/events/upcoming',
        token: token,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final eventsData = responseData['events'] as List<dynamic>;
        final events = eventsData.map((e) => Event.fromJson(e)).toList();

        state = state.copyWith(
          events: events,
          isLoading: false,
          lastUpdated: DateTime.now(),
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load upcoming events',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Network error: ${e.toString()}',
      );
    }
  }

  // Get events for a specific date range
  Future<void> loadEventsForDateRange({
    required DateTime startDate,
    required DateTime endDate,
    String? token,
  }) async {
    if (token == null) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _apiService.get(
        '/events',
        token: token,
        queryParams: {
          'startDate': startDate.toIso8601String(),
          'endDate': endDate.toIso8601String(),
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final eventsData = responseData['events'] as List<dynamic>;
        final events = eventsData.map((e) => Event.fromJson(e)).toList();

        state = state.copyWith(
          events: events,
          isLoading: false,
          lastUpdated: DateTime.now(),
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load events for date range',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Network error: ${e.toString()}',
      );
    }
  }

  // Create a new event
  Future<bool> createEvent({
    required String title,
    required String description,
    required DateTime startTime,
    required DateTime endTime,
    String? location,
    List<Attendee>? attendees,
    String? token,
  }) async {
    if (token == null) return false;

    try {
      final response = await _apiService.post(
        '/schedule',
        token: token,
        data: {
          'text':
              'Schedule a meeting titled "$title" from ${startTime.toIso8601String()} to ${endTime.toIso8601String()}'
                  '${location != null ? ' at $location' : ''}'
                  '${description.isNotEmpty ? '. Description: $description' : ''}',
        },
      );

      if (response.statusCode == 200) {
        // Refresh events after creating
        await refreshEvents();
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(error: 'Failed to create event: ${e.toString()}');
      return false;
    }
  }

  // Update an event
  Future<bool> updateEvent({
    required String eventId,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    List<Attendee>? attendees,
    String? token,
  }) async {
    if (token == null) return false;

    try {
      final updateData = <String, dynamic>{};
      if (title != null) updateData['title'] = title;
      if (description != null) updateData['description'] = description;
      if (startTime != null)
        updateData['startTime'] = startTime.toIso8601String();
      if (endTime != null) updateData['endTime'] = endTime.toIso8601String();
      if (location != null) updateData['location'] = location;
      if (attendees != null)
        updateData['attendees'] = attendees.map((a) => a.toJson()).toList();

      final response = await _apiService.put(
        '/events/$eventId',
        token: token,
        data: updateData,
      );

      if (response.statusCode == 200) {
        // Refresh events after updating
        await refreshEvents();
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(error: 'Failed to update event: ${e.toString()}');
      return false;
    }
  }

  // Delete an event
  Future<bool> deleteEvent({
    required String eventId,
    String? token,
  }) async {
    if (token == null) return false;

    try {
      final response = await _apiService.delete(
        '/events/$eventId',
        token: token,
      );

      if (response.statusCode == 200) {
        // Remove from local state
        final updatedEvents =
            state.events.where((e) => e.id != eventId).toList();
        state = state.copyWith(events: updatedEvents);
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete event: ${e.toString()}');
      return false;
    }
  }

  // Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  // Get current token from auth state
  String? _getCurrentToken() {
    // This would need to be injected or accessed through a provider
    // For now, we'll return null and handle it in the calling code
    return null;
  }
}

// Providers
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

final eventsProvider =
    StateNotifierProvider<EventsNotifier, EventsState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return EventsNotifier(apiService);
});

// Convenience providers
final upcomingEventsProvider = FutureProvider<List<Event>>((ref) async {
  final authState = ref.watch(authProvider);
  final eventsNotifier = ref.read(eventsProvider.notifier);
  final token = ref.watch(authTokenProvider);
  return [];
});

final eventsLoadingProvider = Provider<bool>((ref) {
  return ref.watch(eventsProvider).isLoading;
});

final eventsErrorProvider = Provider<String?>((ref) {
  return ref.watch(eventsProvider).error;
});
