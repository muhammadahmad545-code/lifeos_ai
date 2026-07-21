import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../domain/auth_user.dart';
import 'auth_remote_data_source.dart';

class FirebaseAuthRemoteDataSource implements AuthRemoteDataSource {
  FirebaseAuthRemoteDataSource({FirebaseAuth? firebaseAuth, GoogleSignIn? googleSignIn})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  @override
  Future<AuthUser> signInWithEmail({required String email, required String password}) async {
    final UserCredential credential = await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
    final User user = credential.user ?? (throw StateError('Firebase returned no user for email sign-in.'));
    return _mapUser(user);
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    final GoogleSignInAccount? googleAccount = await _googleSignIn.signIn();
    if (googleAccount == null) {
      throw StateError('Google sign-in was cancelled.');
    }

    final GoogleSignInAuthentication googleAuth = await googleAccount.authentication;
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
    final User user = userCredential.user ?? (throw StateError('Firebase returned no user for Google sign-in.'));
    return _mapUser(user);
  }

  @override
  Future<AuthUser> signInWithApple() async {
    final AuthorizationCredentialAppleID appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: <AppleIDAuthorizationScopes>[
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final OAuthProvider provider = OAuthProvider('apple.com');
    final OAuthCredential credential = provider.credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );
    final UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
    final User user = userCredential.user ?? (throw StateError('Firebase returned no user for Apple sign-in.'));
    return _mapUser(user);
  }

  @override
  Future<String> sendPasswordReset({required String email}) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
    return '';
  }

  @override
  Future<void> verifyOtp({required String code}) async {
    throw UnimplementedError('OTP verification should be handled by the selected backend provider.');
  }

  @override
  Future<void> enableTwoFactor() async {
    throw UnimplementedError('Two-factor enrollment should be handled by the selected backend provider.');
  }

  @override
  Future<void> enableBiometricLogin() async {
    throw UnimplementedError('Biometric enrollment should be handled through local_auth and secure storage.');
  }

  AuthUser _mapUser(User user) {
    return AuthUser(
      id: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? 'LifeOS User',
      photoUrl: user.photoURL,
    );
  }
}