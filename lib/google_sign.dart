import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart'; // Import AuthService to access user profile check

final supabase = Supabase.instance.client;

Future<AuthResponse> googleSignIn() async {
  const webClientId =
      '54391127653-s3nsu1769f7mqo8srdhdhm2r7fnqso1a.apps.googleusercontent.com';

  final GoogleSignIn googleSignIn = GoogleSignIn(
    serverClientId: webClientId,
    signInOption: SignInOption.standard,
    scopes: ['email', 'profile'], // Explicitly request required scopes
  );

  // Disconnect previous session to force account picker
  try {
    await googleSignIn.disconnect();
  } catch (e) {
    print('Disconnect error (ignored): $e');
  }

  final googleUser = await googleSignIn.signIn();
  if (googleUser == null) {
    throw Exception('Google Sign-In was cancelled.');
  }

  final googleAuth = await googleUser.authentication;
  final accessToken = googleAuth.accessToken;
  final idToken = googleAuth.idToken;

  if (accessToken == null || idToken == null) {
    throw Exception(
        'Missing Google Auth tokens: accessToken=$accessToken, idToken=$idToken');
  }

  // Check if the Google account's email is registered in the users table
  // final authService = AuthService();
  final userProfile = await supabase
      .from('users')
      .select()
      .eq('email', googleUser.email)
      .maybeSingle();

  if (userProfile == null) {
    throw Exception(
        'This Google account is not registered. Please sign up first.');
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
