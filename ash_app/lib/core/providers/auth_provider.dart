import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

/// Auth state model
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
      error: error ?? this.error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

/// Initialize GoogleSignIn - this happens once at startup
final googleSignInProvider = FutureProvider<GoogleSignIn>((ref) async {
  final googleSignIn = GoogleSignIn.instance;
  await googleSignIn.initialize(
      serverClientId:
          '417533035171-hq2rt5ltnd2rnpa0j1mo8f1ifh7pkhhn.apps.googleusercontent.com');
  return googleSignIn;
});

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

/// Auth notifier using Riverpod StateNotifier
class AuthNotifier extends StateNotifier<AuthState> {
  final GoogleSignIn _googleSignIn;
  final ApiService _apiService;

  AuthNotifier(this._googleSignIn, this._apiService)
      : super(const AuthState()) {
    _checkAuthStatus();
  }

  // Check auth status on init
  Future<void> _checkAuthStatus() async {
    state = state.copyWith(isLoading: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConfig.userTokenKey);
      final userData = prefs.getString(AppConfig.userDataKey);

      if (token != null && userData != null) {
        final user = User.fromJson(jsonDecode(userData));
        final response = await _apiService.get(
          '${AppConfig.authEndpoint}/profile',
          token: token,
        );

        if (response.statusCode == 200) {
          state = state.copyWith(
            user: user,
            token: token,
            isAuthenticated: true,
            isLoading: false,
            error: null,
          );
        } else {
          await _clearLocalStorage();
          state = state.copyWith(isLoading: false, error: null);
        }
      } else {
        state = state.copyWith(isLoading: false, error: null);
      }
    } catch (e, st) {
      developer.log('Error checking auth status: $e\n$st',
          name: 'AuthNotifier');
      state = state.copyWith(
        error: 'Failed to check authentication status',
        isLoading: false,
      );
    }
  }

  // Sign in with Google - v7.x uses authenticate()
  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Use authenticate() instead of signIn()
      final googleUser = await _googleSignIn.authenticate(
        scopeHint: [
          'email',
          'profile',
          'https://www.googleapis.com/auth/calendar',
          'https://www.googleapis.com/auth/gmail.send',
        ],
      );

      // In v7, authentication is now synchronous (no await needed)
      final googleAuth = googleUser.authentication;
      if (googleAuth.idToken == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to retrieve Google ID token',
        );
        return false;
      }

      // Send token to backend for verification
      final response = await _apiService.post(
        '${AppConfig.authEndpoint}/google/callback',
        data: {'id_token': googleAuth.idToken},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final token = data['token'] ?? data['access_token'];

        if (token != null) {
          final profile = await _apiService.get(
            '${AppConfig.authEndpoint}/profile',
            token: token,
          );

          if (profile.statusCode == 200) {
            final user = User.fromJson(jsonDecode(profile.body));
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(AppConfig.userTokenKey, token);
            await prefs.setString(
                AppConfig.userDataKey, jsonEncode(user.toJson()));

            state = state.copyWith(
              user: user,
              token: token,
              isAuthenticated: true,
              isLoading: false,
              error: null,
            );
            return true;
          } else {
            state = state.copyWith(
              isLoading: false,
              error: 'Failed to fetch user profile from backend',
            );
            return false;
          }
        }
      }

      state = state.copyWith(
        isLoading: false,
        error: 'Backend authentication failed',
      );
      return false;
    } on GoogleSignInException catch (e) {
      developer.log(
          'Google sign-in exception: ${e.code.name} - ${e.description}',
          name: 'AuthNotifier');
      state = state.copyWith(
        isLoading: false,
        error: _getErrorMessage(e),
      );
      return false;
    } catch (e, st) {
      developer.log('Google sign-in error: $e\n$st', name: 'AuthNotifier');
      state = state.copyWith(isLoading: false, error: 'Sign-in failed: $e');
      return false;
    }
  }

  // Convert GoogleSignInException to user-friendly message
  String _getErrorMessage(GoogleSignInException e) {
    switch (e.code.name) {
      case 'canceled':
        return 'Sign-in was cancelled';
      case 'interrupted':
        return 'Sign-in was interrupted';
      case 'clientConfigurationError':
        return 'Configuration issue with Google Sign-In';
      case 'providerConfigurationError':
        return 'Google Sign-In is currently unavailable';
      default:
        return 'Sign-in failed: ${e.description ?? 'Unknown error'}';
    }
  }

  // Sign-out
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _googleSignIn.signOut();
      if (state.token != null) {
        // optional: notify backend
        try {
          await _apiService.post('${AppConfig.authEndpoint}/logout',
              token: state.token);
        } catch (_) {
          // ignore backend logout failures
        }
      }
      await _clearLocalStorage();
      state = const AuthState();
    } catch (e, st) {
      developer.log('Sign-out error: $e\n$st', name: 'AuthNotifier');
      state = state.copyWith(isLoading: false, error: 'Sign-out failed: $e');
    }
  }

  Future<void> _clearLocalStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConfig.userTokenKey);
    await prefs.remove(AppConfig.userDataKey);
  }
}

final authTokenProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).when(
        data: (state) => state.token,
        loading: () => null,
        error: (_, __) => null,
      );
});

/// Main auth provider - use AsyncNotifierProvider to handle initialization
final authProvider = AsyncNotifierProvider<AuthNotifierAsync, AuthState>(() {
  return AuthNotifierAsync();
});

/// Async notifier wrapper to handle GoogleSignIn initialization
class AuthNotifierAsync extends AsyncNotifier<AuthState> {
  AuthNotifier? _authNotifier;

  @override
  Future<AuthState> build() async {
    // Wait for GoogleSignIn to initialize
    final googleSignIn = await ref.watch(googleSignInProvider.future);
    final apiService = ref.watch(apiServiceProvider);

    // Create the AuthNotifier
    _authNotifier = AuthNotifier(googleSignIn, apiService);

    // Listen to state changes and update
    _authNotifier!.addListener((state) {
      this.state = AsyncValue.data(state);
    });

    return _authNotifier!.state;
  }

  Future<bool> signInWithGoogle() async {
    if (_authNotifier == null) return false;
    return await _authNotifier!.signInWithGoogle();
  }

  Future<void> signOut() async {
    if (_authNotifier == null) return;
    await _authNotifier!.signOut();
  }
}

// Helper providers for easy access
final userProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).when(
        data: (state) => state.user,
        loading: () => null,
        error: (_, __) => null,
      );
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).when(
        data: (state) => state.isAuthenticated,
        loading: () => false,
        error: (_, __) => false,
      );
});

final authLoadingProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).when(
        data: (state) => state.isLoading,
        loading: () => true,
        error: (_, __) => false,
      );
});

final authErrorProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).when(
        data: (state) => state.error,
        loading: () => null,
        error: (error, _) => error.toString(),
      );
});
