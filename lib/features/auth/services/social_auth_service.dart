import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class SocialAuthProfile {
  const SocialAuthProfile({
    required this.provider,
    required this.providerUserId,
    required this.email,
    required this.displayName,
    this.photoUrl,
  });

  final String provider;
  final String providerUserId;
  final String email;
  final String displayName;
  final String? photoUrl;
}

/// Real Google / Apple account pickers — never invents fake users.
class SocialAuthService {
  SocialAuthService({GoogleSignIn? googleSignIn})
      : _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: const <String>['email', 'profile'],
            );

  final GoogleSignIn _googleSignIn;

  Future<SocialAuthProfile> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        throw StateError('Google sign-in was cancelled.');
      }

      final String email = account.email.trim().toLowerCase();
      if (email.isEmpty) {
        throw StateError('Google did not return an email for this account.');
      }

      return SocialAuthProfile(
        provider: 'google',
        providerUserId: account.id,
        email: email,
        displayName: (account.displayName?.trim().isNotEmpty ?? false)
            ? account.displayName!.trim()
            : email.split('@').first,
        photoUrl: account.photoUrl,
      );
    } catch (error) {
      if (error is StateError) {
        rethrow;
      }
      throw StateError(_friendlyGoogleError(error));
    }
  }

  Future<SocialAuthProfile> signInWithApple() async {
    final bool isIos = !kIsWeb && Platform.isIOS;
    final bool isMacos = !kIsWeb && Platform.isMacOS;
    if (!isIos && !isMacos) {
      final bool available = await SignInWithApple.isAvailable();
      if (!available) {
        throw StateError('Sign in with Apple is only available on iPhone / iPad / Mac.');
      }
    }

    try {
      final AuthorizationCredentialAppleID credential = await SignInWithApple.getAppleIDCredential(
        scopes: const <AppleIDAuthorizationScopes>[
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final String? emailRaw = credential.email;
      final String userIdentifier = credential.userIdentifier ?? '';
      if (userIdentifier.isEmpty && (emailRaw == null || emailRaw.isEmpty)) {
        throw StateError('Apple did not return an account identity. Try again or use email sign-in.');
      }

      final String email = (emailRaw?.trim().toLowerCase().isNotEmpty ?? false)
          ? emailRaw!.trim().toLowerCase()
          : 'apple_${userIdentifier.substring(0, userIdentifier.length.clamp(0, 12))}@privaterelay.appleid.com';

      final String given = credential.givenName?.trim() ?? '';
      final String family = credential.familyName?.trim() ?? '';
      final String displayName = ('$given $family').trim().isEmpty
          ? email.split('@').first
          : ('$given $family').trim();

      return SocialAuthProfile(
        provider: 'apple',
        providerUserId: userIdentifier.isEmpty ? email : userIdentifier,
        email: email,
        displayName: displayName,
      );
    } catch (error) {
      if (error is StateError) {
        rethrow;
      }
      throw StateError('Apple sign-in failed: $error');
    }
  }

  Future<void> signOutGoogle() async {
    try {
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
    } catch (_) {
      // Best-effort cleanup.
    }
  }

  String _friendlyGoogleError(Object error) {
    final String text = error.toString();
    if (text.contains('ApiException: 10') || text.contains('DEVELOPER_ERROR')) {
      return 'Google Sign-In is not configured for this app build yet. '
          'Add a real Firebase / Google Cloud OAuth client (SHA-1 + package name), '
          'then rebuild. Until then, please use email sign-in.';
    }
    if (text.contains('network') || text.contains('Network')) {
      return 'Network error during Google Sign-In. Check your internet connection.';
    }
    if (text.contains('12501') || text.contains('canceled') || text.contains('cancelled')) {
      return 'Google sign-in was cancelled.';
    }
    return 'Google Sign-In failed. Use email sign-in, or finish Google/Firebase setup. ($error)';
  }
}
