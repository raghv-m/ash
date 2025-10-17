import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateNotifier;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_api_availability/google_api_availability.dart';
import '../config/app_config.dart';
import '../models/user_model.dart';

Future<void> initializeFirebase() async {
  await Firebase.initializeApp();
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
}

class AuthState {
  final User? user;
  final String? token;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;
  final AuthMethod? signUpMethod;
  final String? phoneVerificationId;

  const AuthState({
    this.user,
    this.token,
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
    this.signUpMethod,
    this.phoneVerificationId,
  });

  AuthState copyWith({
    User? user,
    String? token,
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
    AuthMethod? signUpMethod,
    String? phoneVerificationId,
  }) {
    return AuthState(
      user: user ?? this.user,
      token: token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      signUpMethod: signUpMethod ?? this.signUpMethod,
      phoneVerificationId: phoneVerificationId ?? this.phoneVerificationId,
    );
  }
}

enum AuthMethod { email, phone, google }

final googleSignInProvider = FutureProvider<GoogleSignIn>((ref) async {
  final googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
      'https://www.googleapis.com/auth/calendar',
      'https://www.googleapis.com/auth/gmail.send',
    ],
    clientId:
        '417533035171-hq2rt5ltnd2rnpa0j1mo8f1ifh7pkhhn.apps.googleusercontent.com',
  );
  return googleSignIn;
});

final analyticsProvider =
    Provider<FirebaseAnalytics>((ref) => FirebaseAnalytics.instance);

final crashlyticsProvider =
    Provider<FirebaseCrashlytics>((ref) => FirebaseCrashlytics.instance);

class AuthNotifier extends StateNotifier<AuthState> {
  final GoogleSignIn _googleSignIn;
  final FirebaseAnalytics _analytics;
  final FirebaseCrashlytics _crashlytics;
  late firebase_auth.FirebaseAuth _firebaseAuth;

  AuthNotifier(this._googleSignIn, this._analytics, this._crashlytics)
      : super(const AuthState()) {
    _firebaseAuth = firebase_auth.FirebaseAuth.instance;
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    state = state.copyWith(isLoading: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConfig.userTokenKey);
      final userData = prefs.getString(AppConfig.userDataKey);
      final signUpMethod = prefs.getString('signUpMethod');

      if (token != null && userData != null) {
        final user = User.fromJson(jsonDecode(userData));
        final firebaseUser = _firebaseAuth.currentUser;

        if (firebaseUser != null && firebaseUser.uid == user.userId) {
          state = state.copyWith(
            user: user,
            token: token,
            isAuthenticated: true,
            isLoading: false,
            error: null,
            signUpMethod: signUpMethod != null
                ? AuthMethod.values.byName(signUpMethod)
                : null,
          );
          await _analytics.logEvent(
            name: 'auth_status_checked',
            parameters: {'status': 'success'},
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
      await _crashlytics.recordError(e, st, reason: 'Auth status check failed');
      state = state.copyWith(
        error: 'Failed to check authentication status',
        isLoading: false,
      );
    }
  }

  Future<bool> signUpWithEmail(
      String email, String password, String displayName) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = userCredential.user;
      if (firebaseUser != null) {
        await firebaseUser.updateDisplayName(displayName);
        await firebaseUser.reload();

        final token = await firebaseUser.getIdToken();
        final user = _createUserFromFirebase(firebaseUser, displayName);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConfig.userTokenKey, token!);
        await prefs.setString(AppConfig.userDataKey, jsonEncode(user.toJson()));
        await prefs.setString('signUpMethod', AuthMethod.email.name);

        state = state.copyWith(
          user: user,
          token: token,
          isAuthenticated: true,
          isLoading: false,
          error: null,
          signUpMethod: AuthMethod.email,
        );

        await _analytics.logSignUp(signUpMethod: 'email');
        await _crashlytics.setUserIdentifier(firebaseUser.uid);
        return true;
      }

      state = state.copyWith(
        isLoading: false,
        error: 'Failed to create user account',
      );
      return false;
    } on firebase_auth.FirebaseAuthException catch (e, st) {
      developer.log('Signup error: ${e.code} - ${e.message}',
          name: 'AuthNotifier');
      await _crashlytics.recordError(e, st, reason: 'Email signup failed');
      state = state.copyWith(
        isLoading: false,
        error: _getFirebaseErrorMessage(e),
      );
      return false;
    } catch (e, st) {
      developer.log('Unexpected error during signup: $e\n$st',
          name: 'AuthNotifier');
      await _crashlytics.recordError(e, st, reason: 'Unexpected signup error');
      state = state.copyWith(isLoading: false, error: 'Sign-up failed: $e');
      return false;
    }
  }

  Future<bool> loginWithEmail(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = userCredential.user;
      if (firebaseUser != null) {
        final token = await firebaseUser.getIdToken();
        final user = _createUserFromFirebase(
            firebaseUser, firebaseUser.displayName ?? 'User');

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConfig.userTokenKey, token!);
        await prefs.setString(AppConfig.userDataKey, jsonEncode(user.toJson()));
        await prefs.setString('signUpMethod', AuthMethod.email.name);

        state = state.copyWith(
          user: user,
          token: token,
          isAuthenticated: true,
          isLoading: false,
          error: null,
          signUpMethod: AuthMethod.email,
        );

        await _analytics.logLogin(loginMethod: 'email');
        await _crashlytics.setUserIdentifier(firebaseUser.uid);
        return true;
      }

      state = state.copyWith(
        isLoading: false,
        error: 'Failed to login',
      );
      return false;
    } on firebase_auth.FirebaseAuthException catch (e, st) {
      developer.log('Login error: ${e.code} - ${e.message}',
          name: 'AuthNotifier');
      await _crashlytics.recordError(e, st, reason: 'Email login failed');
      state = state.copyWith(
        isLoading: false,
        error: _getFirebaseErrorMessage(e),
      );
      return false;
    } catch (e, st) {
      developer.log('Unexpected error during login: $e\n$st',
          name: 'AuthNotifier');
      await _crashlytics.recordError(e, st, reason: 'Unexpected login error');
      state = state.copyWith(isLoading: false, error: 'Login failed: $e');
      return false;
    }
  }

  Future<bool> signUpWithPhone(String phoneNumber, String displayName) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      bool? codeSent = false;

      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted:
            (firebase_auth.PhoneAuthCredential credential) async {
          if (!codeSent!) {
            await _signInWithPhoneCredential(credential, displayName);
          }
        },
        verificationFailed: (firebase_auth.FirebaseAuthException e) {
          developer.log('Phone verification failed: ${e.code}',
              name: 'AuthNotifier');
          state = state.copyWith(
            isLoading: false,
            error: _getFirebaseErrorMessage(e),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          codeSent = true;
          state = state.copyWith(
            isLoading: false,
            error: null,
            phoneVerificationId: verificationId,
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          state = state.copyWith(phoneVerificationId: verificationId);
        },
        timeout: const Duration(seconds: 120),
      );
      return true;
    } catch (e, st) {
      developer.log('Phone signup error: $e\n$st', name: 'AuthNotifier');
      await _crashlytics.recordError(e, st, reason: 'Phone signup failed');
      state =
          state.copyWith(isLoading: false, error: 'Phone signup failed: $e');
      return false;
    }
  }

  Future<bool> verifyPhoneOTP(
      String verificationId, String otp, String displayName) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final credential = firebase_auth.PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );
      return await _signInWithPhoneCredential(credential, displayName);
    } catch (e, st) {
      developer.log('OTP verification error: $e\n$st', name: 'AuthNotifier');
      await _crashlytics.recordError(e, st, reason: 'OTP verification failed');
      state = state.copyWith(
          isLoading: false, error: 'Invalid OTP. Please try again.');
      return false;
    }
  }

  Future<bool> _signInWithPhoneCredential(
    firebase_auth.PhoneAuthCredential credential,
    String displayName,
  ) async {
    try {
      final userCredential =
          await _firebaseAuth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        if (firebaseUser.displayName == null) {
          await firebaseUser.updateDisplayName(displayName);
          await firebaseUser.reload();
        }

        final token = await firebaseUser.getIdToken();
        final user = _createUserFromFirebase(
            firebaseUser, firebaseUser.displayName ?? displayName);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConfig.userTokenKey, token!);
        await prefs.setString(AppConfig.userDataKey, jsonEncode(user.toJson()));
        await prefs.setString('signUpMethod', AuthMethod.phone.name);

        state = state.copyWith(
          user: user,
          token: token,
          isAuthenticated: true,
          isLoading: false,
          error: null,
          signUpMethod: AuthMethod.phone,
          phoneVerificationId: null,
        );

        await _analytics.logSignUp(signUpMethod: 'phone');
        await _crashlytics.setUserIdentifier(firebaseUser.uid);
        return true;
      }

      state = state.copyWith(
        isLoading: false,
        error: 'Failed to authenticate with phone',
      );
      return false;
    } catch (e, st) {
      developer.log('Phone sign-in error: $e\n$st', name: 'AuthNotifier');
      await _crashlytics.recordError(e, st, reason: 'Phone sign-in failed');
      state = state.copyWith(
          isLoading: false, error: 'Phone authentication failed: $e');
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final playServicesStatus = await GoogleApiAvailability.instance
          .checkGooglePlayServicesAvailability();
      if (playServicesStatus != GooglePlayServicesAvailability.success) {
        final errorMessage =
            'Google Play Services is not available. Status: $playServicesStatus';
        state = state.copyWith(isLoading: false, error: errorMessage);
        await _analytics.logEvent(
          name: 'login_error',
          parameters: {'error': errorMessage, 'method': 'google'},
        );
        return false;
      }

      await _googleSignIn.signOut();
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Google sign-in cancelled by user',
        );
        await _analytics.logEvent(
          name: 'login_cancelled',
          parameters: {'method': 'google'},
        );
        return false;
      }

      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to retrieve Google ID token',
        );
        return false;
      }

      final credential = firebase_auth.GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );
      final userCredential =
          await _firebaseAuth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        final token = await firebaseUser.getIdToken();
        final user = _createUserFromFirebase(
            firebaseUser, firebaseUser.displayName ?? 'User');

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConfig.userTokenKey, token!);
        await prefs.setString(AppConfig.userDataKey, jsonEncode(user.toJson()));
        await prefs.setString('signUpMethod', AuthMethod.google.name);

        state = state.copyWith(
          user: user,
          token: token,
          isAuthenticated: true,
          isLoading: false,
          error: null,
          signUpMethod: AuthMethod.google,
        );

        await _analytics.logLogin(loginMethod: 'google');
        await _crashlytics.setUserIdentifier(firebaseUser.uid);
        return true;
      }

      state = state.copyWith(
        isLoading: false,
        error: 'Failed to authenticate with Firebase',
      );
      return false;
    } on firebase_auth.FirebaseAuthException catch (e, st) {
      developer.log('Firebase auth error: ${e.code} - ${e.message}',
          name: 'AuthNotifier');
      await _crashlytics.recordError(e, st, reason: 'Google sign-in failed');
      state = state.copyWith(
        isLoading: false,
        error: _getFirebaseErrorMessage(e),
      );
      return false;
    } catch (e, st) {
      developer.log('Unexpected error during Google sign-in: $e\n$st',
          name: 'AuthNotifier');
      await _crashlytics.recordError(e, st,
          reason: 'Unexpected Google sign-in error');
      state = state.copyWith(isLoading: false, error: 'Sign-in failed: $e');
      return false;
    }
  }

  User _createUserFromFirebase(
      firebase_auth.User firebaseUser, String displayName) {
    return User(
      userId: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      name: displayName,
      picture: firebaseUser.photoURL,
      timeZone: 'UTC',
      preferences: const UserPreferences(
        voiceEnabled: true,
        ttsProvider: 'openai',
        reminderMinutes: 30,
        workingHours: WorkingHours(start: '09:00', end: '17:00'),
        workingDays: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
      ),
      hasValidGoogleTokens: false,
      lastLogin: DateTime.now(),
      createdAt: DateTime.now(),
    );
  }

  String _getFirebaseErrorMessage(firebase_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'account-exists-with-different-credential':
        return 'Account exists with different credentials';
      case 'invalid-credential':
        return 'Invalid authentication credentials';
      case 'operation-not-allowed':
        return 'Sign-in method is not enabled';
      case 'user-disabled':
        return 'User account is disabled';
      case 'user-not-found':
        return 'User account not found';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'Email is already in use';
      case 'invalid-email':
        return 'Invalid email address';
      case 'weak-password':
        return 'Password is too weak';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'invalid-phone-number':
        return 'Invalid phone number';
      case 'missing-phone-number':
        return 'Phone number is required';
      default:
        return 'Authentication failed: ${e.message ?? 'Unknown error'}';
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _googleSignIn.signOut();
      await _firebaseAuth.signOut();
      await _clearLocalStorage();
      state = const AuthState();
      await _analytics.logEvent(name: 'logout', parameters: {'method': 'all'});
    } catch (e, st) {
      developer.log('Sign-out error: $e\n$st', name: 'AuthNotifier');
      await _crashlytics.recordError(e, st, reason: 'Sign-out failed');
      state = state.copyWith(isLoading: false, error: 'Sign-out failed: $e');
    }
  }

  Future<void> _clearLocalStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConfig.userTokenKey);
    await prefs.remove(AppConfig.userDataKey);
    await prefs.remove('signUpMethod');
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifierAsync, AuthState>(() {
  return AuthNotifierAsync();
});

class AuthNotifierAsync extends AsyncNotifier<AuthState> {
  AuthNotifier? _authNotifier;

  @override
  Future<AuthState> build() async {
    final googleSignIn = await ref.watch(googleSignInProvider.future);
    final analytics = ref.watch(analyticsProvider);
    final crashlytics = ref.watch(crashlyticsProvider);

    _authNotifier = AuthNotifier(googleSignIn, analytics, crashlytics);

    _authNotifier!.addListener((state) {
      this.state = AsyncValue.data(state);
    });

    return _authNotifier!.state;
  }

  Future<bool> signUpWithEmail(
      String email, String password, String displayName) async {
    if (_authNotifier == null) return false;
    return await _authNotifier!.signUpWithEmail(email, password, displayName);
  }

  Future<bool> loginWithEmail(String email, String password) async {
    if (_authNotifier == null) return false;
    return await _authNotifier!.loginWithEmail(email, password);
  }

  Future<bool> signUpWithPhone(String phoneNumber, String displayName) async {
    if (_authNotifier == null) return false;
    return await _authNotifier!.signUpWithPhone(phoneNumber, displayName);
  }

  Future<bool> verifyPhoneOTP(
      String verificationId, String otp, String displayName) async {
    if (_authNotifier == null) return false;
    return await _authNotifier!
        .verifyPhoneOTP(verificationId, otp, displayName);
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

final authTokenProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).when(
        data: (state) => state.token,
        loading: () => null,
        error: (_, __) => null,
      );
});

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

final authMethodProvider = Provider<AuthMethod?>((ref) {
  return ref.watch(authProvider).when(
        data: (state) => state.signUpMethod,
        loading: () => null,
        error: (_, __) => null,
      );
});

final phoneVerificationIdProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).when(
        data: (state) => state.phoneVerificationId,
        loading: () => null,
        error: (_, __) => null,
      );
});
