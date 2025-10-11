import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../config/app_config.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';

// Auth State
class AuthState {
  final User? user;
  final String? token;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;

  const AuthState({
    this.user,
    this.token,
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    User? user,
    String? token,
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
  }) {
    return AuthState(
      user: user ?? this.user,
      token: token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

// Auth Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final GoogleSignIn _googleSignIn;
  final ApiService _apiService;

  AuthNotifier(this._googleSignIn, this._apiService) : super(const AuthState()) {
    _checkAuthStatus();
  }

  // Check if user is already authenticated
  Future<void> _checkAuthStatus() async {
    state = state.copyWith(isLoading: true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConfig.userTokenKey);
      final userData = prefs.getString(AppConfig.userDataKey);
      
      if (token != null && userData != null) {
        final user = User.fromJson(jsonDecode(userData));
        state = state.copyWith(
          user: user,
          token: token,
          isAuthenticated: true,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to check authentication status',
        isLoading: false,
      );
    }
  }

  // Sign in with Google
  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // Sign in with Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Google sign in was cancelled',
        );
        return false;
      }

      // Get authentication details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      if (googleAuth.accessToken == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to get Google access token',
        );
        return false;
      }

      // Send token to backend for verification
      final response = await _apiService.post(
        '${AppConfig.authEndpoint}/google/callback',
        data: {
          'code': googleAuth.accessToken,
          'state': googleUser.id,
        },
      );

      if (response.statusCode == 200) {
        // Extract token from response (assuming backend returns JWT)
        final responseData = jsonDecode(response.body);
        final token = responseData['token'] ?? responseData['access_token'];
        
        if (token != null) {
          // Get user profile
          final userResponse = await _apiService.get(
            '${AppConfig.authEndpoint}/profile',
            token: token,
          );
          
          if (userResponse.statusCode == 200) {
            final user = User.fromJson(jsonDecode(userResponse.body));
            
            // Store authentication data
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(AppConfig.userTokenKey, token);
            await prefs.setString(AppConfig.userDataKey, jsonEncode(user.toJson()));
            
            state = state.copyWith(
              user: user,
              token: token,
              isAuthenticated: true,
              isLoading: false,
              error: null,
            );
            
            return true;
          }
        }
      }
      
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to authenticate with backend',
      );
      return false;
      
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Sign in failed: ${e.toString()}',
      );
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    
    try {
      // Sign out from Google
      await _googleSignIn.signOut();
      
      // Clear local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConfig.userTokenKey);
      await prefs.remove(AppConfig.userDataKey);
      
      // Call backend logout endpoint
      if (state.token != null) {
        try {
          await _apiService.post(
            '${AppConfig.authEndpoint}/logout',
            token: state.token,
          );
        } catch (e) {
          // Ignore backend logout errors
          // Backend logout failed: $e
        }
      }
      
      state = const AuthState();
      
    } catch (e) {
      state = state.copyWith(
        error: 'Sign out failed: ${e.toString()}',
        isLoading: false,
      );
    }
  }

  // Refresh user data
  Future<void> refreshUser() async {
    if (state.token == null) return;
    
    try {
      final response = await _apiService.get(
        '${AppConfig.authEndpoint}/profile',
        token: state.token,
      );
      
      if (response.statusCode == 200) {
        final user = User.fromJson(jsonDecode(response.body));
        
        // Update local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConfig.userDataKey, jsonEncode(user.toJson()));
        
        state = state.copyWith(user: user);
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to refresh user data');
    }
  }

  // Update user preferences
  Future<void> updatePreferences(Map<String, dynamic> preferences) async {
    if (state.token == null) return;
    
    try {
      final response = await _apiService.put(
        '${AppConfig.authEndpoint}/preferences',
        data: preferences,
        token: state.token,
      );
      
      if (response.statusCode == 200) {
        // Refresh user data
        await refreshUser();
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to update preferences');
    }
  }

  // Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Providers
final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  return GoogleSignIn(
    clientId: AppConfig.googleClientId,
    scopes: [
      'email',
      'profile',
      'https://www.googleapis.com/auth/calendar',
      'https://www.googleapis.com/auth/gmail.send',
    ],
  );
});

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final googleSignIn = ref.watch(googleSignInProvider);
  final apiService = ref.watch(apiServiceProvider);
  return AuthNotifier(googleSignIn, apiService);
});

// Convenience providers
final userProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).user;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});

final authLoadingProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isLoading;
});

final authErrorProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).error;
});

