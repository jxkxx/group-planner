import 'package:flutter/material.dart';

enum LegalDocument { privacy, terms }

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.document});
  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPrivacy = document == LegalDocument.privacy;
    final title = isPrivacy ? 'Privacy Policy' : 'Terms of Service';
    final sections = isPrivacy ? _privacySections : _termsSections;

    return Scaffold(
      appBar: AppBar(title: Text(title), centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: cs.onSurface)),
          const SizedBox(height: 4),
          Text('Effective date: November 2025',
              style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.5))),
          const SizedBox(height: 24),
          for (final section in sections) ...[
            if (section.heading != null) ...[
              const SizedBox(height: 16),
              Text(section.heading!,
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface)),
              const SizedBox(height: 8),
            ],
            ...section.paragraphs.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(p,
                    style: TextStyle(
                        fontSize: 15,
                        height: 1.55,
                        color: cs.onSurface.withValues(alpha: 0.85))),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Section {
  final String? heading;
  final List<String> paragraphs;
  const _Section({this.heading, required this.paragraphs});
}

// ─── PRIVACY POLICY ─────────────────────────────────────────────────────────

const _privacySections = <_Section>[
  _Section(paragraphs: [
    'Group Point ("we", "our", or "us") respects your privacy. This policy explains what data we collect and how we use it.',
  ]),
  _Section(heading: 'What we collect', paragraphs: [
    'When you use Group Point, we collect:',
    '• Account info — email address, name, and profile photo (from your sign-in provider: Google, Apple, or email/password)',
    '• Availability data — dates you mark as Available, Likely, Maybe, or Unavailable',
    '• Group data — groups you create or join, group names, invite codes, member lists',
    '• Preferences — chosen nickname, theme, first day of week',
  ]),
  _Section(heading: 'How we use your data', paragraphs: [
    'Your data is used solely to provide the app\'s functionality:',
    '• Showing your availability to other members of groups you\'re in',
    '• Finding optimal dates that work for your group',
    '• Maintaining your account and preferences',
    'We do NOT sell, rent, or share your data with advertisers or third parties.',
  ]),
  _Section(heading: 'Where your data is stored', paragraphs: [
    'All data is stored on Google Firebase (Firestore and Firebase Authentication), hosted on Google servers. Firebase may store data in the United States or European Union depending on the region.',
  ]),
  _Section(heading: 'Your rights', paragraphs: [
    'You can:',
    '• View all your data within the app',
    '• Edit your profile, group membership, and availability at any time',
    '• Delete your account entirely via Profile → Delete account. This permanently removes all your data.',
  ]),
  _Section(heading: 'Children', paragraphs: [
    'Group Point is not intended for children under 13. We do not knowingly collect data from children.',
  ]),
  _Section(heading: 'Changes to this policy', paragraphs: [
    'We may update this policy from time to time. The "Effective date" above shows the latest version.',
  ]),
  _Section(heading: 'Contact', paragraphs: [
    'For questions about this policy, visit our website or contact us through the email shown on the Group Point legal page.',
  ]),
];

// ─── TERMS OF SERVICE ───────────────────────────────────────────────────────

const _termsSections = <_Section>[
  _Section(paragraphs: [
    'By using Group Point, you agree to these terms.',
  ]),
  _Section(heading: 'Acceptable use', paragraphs: [
    'You agree not to:',
    '• Use the app for illegal activities',
    '• Harass or abuse other users',
    '• Attempt to access or modify other users\' data without permission',
    '• Reverse engineer, decompile, or tamper with the app',
  ]),
  _Section(heading: 'Accounts', paragraphs: [
    'You are responsible for keeping your account credentials secure. We reserve the right to suspend or terminate accounts that violate these terms.',
  ]),
  _Section(heading: 'Service availability', paragraphs: [
    'The app is provided "as is" without warranty. We do our best to keep it running but cannot guarantee uninterrupted service.',
  ]),
  _Section(heading: 'Limitation of liability', paragraphs: [
    'To the maximum extent permitted by law, Group Point is not liable for any indirect, incidental, or consequential damages arising from your use of the app.',
  ]),
  _Section(heading: 'Changes to these terms', paragraphs: [
    'We may update these terms. Continued use of the app after changes means you accept the new terms.',
  ]),
  _Section(heading: 'Governing law', paragraphs: [
    'These terms are governed by the laws of Slovakia. Any disputes will be resolved in the courts of Slovakia.',
  ]),
  _Section(heading: 'Contact', paragraphs: [
    'For questions about these terms, visit our website or contact us through the email shown on the Group Point legal page.',
  ]),
];
