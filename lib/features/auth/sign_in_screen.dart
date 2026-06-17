import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'email_sign_in_screen.dart';

class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result =
          await FirebaseAuth.instance.signInWithCredential(credential);
      await _saveUserProfile(result.user);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google sign in failed: $e')),
        );
      }
    }
  }

  Future<void> _signInWithApple(BuildContext context) async {
    try {
      // Use firebase_auth's managed Apple provider flow. It runs the native
      // Sign in with Apple and forwards the nonce to Firebase internally —
      // avoiding the manual-credential nonce bug that rejected valid tokens
      // with "invalid-credential / Invalid OAuth response from apple.com".
      final provider = AppleAuthProvider()
        ..addScope('email')
        ..addScope('name');
      final result =
          await FirebaseAuth.instance.signInWithProvider(provider);
      await _saveUserProfile(result.user);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Apple sign in failed: $e')),
        );
      }
    }
  }

  Future<void> _saveUserProfile(User? user) async {
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
      {'displayName': user.displayName ?? user.email ?? 'User'},
      SetOptions(merge: true),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 88, height: 88,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.group, size: 44, color: cs.primary),
              ),
              const SizedBox(height: 24),
              Text('Group Point',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface)),
              const SizedBox(height: 8),
              Text('Find the best date for everyone',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16,
                      color: cs.onSurface.withValues(alpha: 0.5))),
              const SizedBox(height: 48),

              // Google
              OutlinedButton.icon(
                onPressed: () => _signInWithGoogle(context),
                icon: const Icon(Icons.login),
                label: const Text('Continue with Google'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.onSurface,
                  padding: const EdgeInsets.all(16),
                  side: BorderSide(
                      color: cs.onSurface.withValues(alpha: 0.15)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),

              // Apple
              ElevatedButton.icon(
                onPressed: () => _signInWithApple(context),
                icon: const Icon(Icons.apple, color: Colors.white),
                label: const Text('Continue with Apple',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),

              // Email
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const EmailSignInScreen()),
                ),
                icon: const Icon(Icons.mail_outline),
                label: const Text('Continue with Email'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.onSurface,
                  padding: const EdgeInsets.all(16),
                  side: BorderSide(
                      color: cs.onSurface.withValues(alpha: 0.15)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
