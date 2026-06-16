import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
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

  /// Generates a cryptographically secure random nonce.
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256ofString(String input) =>
      sha256.convert(utf8.encode(input)).toString();

  /// Decodes a JWT payload (middle segment) without verifying the signature.
  Map<String, dynamic> _decodeJwtPayload(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return {'_error': 'not a JWT (parts=${parts.length})'};
    var p = parts[1].replaceAll('-', '+').replaceAll('_', '/');
    while (p.length % 4 != 0) {
      p += '=';
    }
    return json.decode(utf8.decode(base64.decode(p))) as Map<String, dynamic>;
  }

  // TEMP DIAGNOSTIC build: surfaces the real Apple token claims + Firebase error
  // on screen so we can see exactly why sign-in is rejected. Revert after.
  Future<void> _signInWithApple(BuildContext context) async {
    final diag = StringBuffer();
    try {
      final rawNonce = _generateNonce();
      final hashedNonce = _sha256ofString(rawNonce);
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
      final idToken = appleCredential.identityToken;
      diag.writeln('idToken present: ${idToken != null}');
      if (idToken != null) {
        final c = _decodeJwtPayload(idToken);
        diag.writeln('aud: ${c['aud']}');
        diag.writeln('iss: ${c['iss']}');
        diag.writeln('token.nonce: ${c['nonce']}');
        diag.writeln('our hashed : $hashedNonce');
        diag.writeln('nonce match: ${c['nonce'] == hashedNonce}');
        diag.writeln('exp: ${c['exp']}  now: '
            '${DateTime.now().millisecondsSinceEpoch ~/ 1000}');
      }
      try {
        final oauthCredential = OAuthProvider('apple.com').credential(
          idToken: idToken,
          rawNonce: rawNonce,
        );
        final result =
            await FirebaseAuth.instance.signInWithCredential(oauthCredential);
        await _saveUserProfile(result.user);
        diag.writeln('FIREBASE: SUCCESS');
      } catch (e) {
        diag.writeln('FIREBASE ERROR: $e');
      }
    } catch (e) {
      diag.writeln('APPLE ERROR: $e');
    }
    debugPrint('=== APPLE DIAG START ===\n${diag.toString()}\n=== APPLE DIAG END ===');
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Apple Sign-In Diagnostic'),
          content: SingleChildScrollView(child: SelectableText(diag.toString())),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
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
