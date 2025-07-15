import 'dart:developer';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

Future<AuthResponse> googleSignIn() async {
  log("in ");
  const webClientId = '54391127653-s3nsu1769f7mqo8srdhdhm2r7fnqso1a.apps.googleusercontent.com';

  final GoogleSignIn googleSignIn = GoogleSignIn(
    serverClientId: webClientId,
    signInOption: SignInOption.standard,
    scopes: ['email', 'profile'], // Explicitly request required scopes
  );

  // Disconnect previous session to force account picker
  try {
    if (googleSignIn.currentUser != null) {
      await googleSignIn.disconnect();
    }
  } catch (e) {
    log("Erorr $e");
    print('Disconnect error (ignored): $e');
  }
  log("chekc ended");
  GoogleSignInAccount? googleUser;
 try {
   googleUser = await googleSignIn.signIn();
  log("googleUser: $googleUser");
  if (googleUser == null) {
    log("Google Sign-In was cancelled.");
    throw Exception('Google Sign-In was cancelled.');
  }
} catch (e) {
  log("Google Sign-In failed: $e");
  rethrow;
}
  log("message");
  final googleAuth = await googleUser.authentication;
  final accessToken = googleAuth.accessToken;
  final idToken = googleAuth.idToken;
  log("$googleAuth      \n$accessToken \n $idToken");
  if (accessToken == null || idToken == null) {
    throw Exception('Missing Google Auth tokens: accessToken=$accessToken, idToken=$idToken');
  }

  // Check if the Google account's email is registered in the users table
  // final authService = AuthService();
  final userProfile = await supabase.from('users').select().eq('email', googleUser.email).maybeSingle();
  log("${userProfile?.entries.first}");
  if (userProfile == null) {
    throw Exception('This Google account is not registered. Please sign up first.');
  }

  try {
    final response = await supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
    print('Signed in: ${response.user?.email}');
    return response;
  } catch (e) {
    print('Supabase auth error: $e');
    rethrow;
  }
}
