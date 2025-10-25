// lib/features/settings/terms_page.dart
// Professional Terms & Conditions — glassy rounded cards (About-style)
import 'package:flutter/material.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  // Update these with your details
  static const String appName = 'FlickNest';
  static const String companyOrDevName = 'Miqdad23';
  static const String contactEmail = 'mikdad23.bd@gmail.com';
  static const String region = 'Bangladesh';
  static const String effectiveDate = '01 Oct 2025';

  Color _glass(BuildContext ctx, [double a = 0.08]) =>
      (Theme.of(ctx).brightness == Brightness.dark
              ? Colors.white
              : Colors.black)
          .withValues(alpha: a);

  Color _border(BuildContext ctx, [double a = 0.12]) =>
      (Theme.of(ctx).brightness == Brightness.dark
              ? Colors.white
              : Colors.black)
          .withValues(alpha: a);

  Widget _card(BuildContext context, String title, List<Widget> children) {
    return Card(
      elevation: 0,
      color: _glass(context, 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _border(context, 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _p(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, textAlign: TextAlign.start),
  );

  Widget _bullets(List<String> items) => Padding(
    padding: const EdgeInsets.only(left: 8, bottom: 4),
    child: Column(
      children: items
          .map(
            (s) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(child: Text(s)),
              ],
            ),
          )
          .toList(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.6);

    return Scaffold(
      appBar: AppBar(title: const Text('Terms & Conditions')),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Effective: $effectiveDate',
              style: TextStyle(color: muted),
            ),
          ),

          _card(context, '1. Agreement to Terms', [
            _p(
              'By downloading, installing, or using $appName (the “App”), you agree to be bound by these Terms & Conditions. If you do not agree, do not use the App.',
            ),
            _p(
              '$appName is published by $companyOrDevName (“we”, “us”, or “our”).',
            ),
          ]),

          _card(context, '2. Eligibility & Use', [
            _bullets([
              'You must be at least 13 years old (or the minimum age required by law in your jurisdiction). If you are between 13 and 18, you represent that you have parental/guardian consent.',
              'You agree to use the App only for lawful purposes and in accordance with these Terms.',
              'We may update, restrict, or discontinue features without notice.',
            ]),
          ]),

          _card(context, '3. Accounts & Sign‑in', [
            _p(
              'The App may be offered in two variants: (a) Offline Build (no sign‑in), and (b) Online Build (sign‑in required).',
            ),
            _bullets([
              'Offline Build: You can use features locally without creating an account.',
              'Online Build: If sign‑in is required, you must provide accurate information, keep your credentials secure, and promptly update any changes.',
              'You are responsible for all activities under your account.',
            ]),
          ]),

          _card(context, '4. Content & Intellectual Property', [
            _bullets([
              'App UI, design, and original assets are owned by $companyOrDevName and protected by applicable IP laws.',
              'Metadata, images, and other media may be sourced from third‑party APIs (e.g., TMDB). $appName is not endorsed or certified by TMDB.',
              'You may create lists or other user‑generated entries within the App; you retain rights to your original content, but grant us a non‑exclusive license to display it within the App where needed.',
              'You must not copy, redistribute, or commercialize any content from the App except as allowed by law or by the respective rights holder.',
            ]),
          ]),

          _card(context, '5. Acceptable Use', [
            _bullets([
              'Do not attempt to reverse engineer, decompile, or modify the App.',
              'Do not upload, post, or transmit any content that is unlawful, infringing, harmful, or violates others’ rights.',
              'Do not use automated scripts, scraping, or rate‑limit bypassing techniques.',
              'Do not misuse third‑party services integrated in the App (e.g., TMDB API).',
            ]),
          ]),

          _card(context, '6. Offline Cache & Sync', [
            _bullets([
              'Offline Build: Data (e.g., lists, covers/avatars, cached metadata) is stored locally on your device.',
              'Online Build: Certain data may sync to cloud services (e.g., for backup or multi‑device access). You are responsible for your internet connection and applicable data charges.',
            ]),
          ]),

          _card(context, '7. Third‑Party Services', [
            _bullets([
              'The App may integrate with third‑party services such as The Movie Database (TMDB) and, in the Online Build, cloud providers (e.g., Firebase).',
              'Your use of third‑party services is subject to their own terms and privacy policies.',
              'We are not responsible for third‑party content, availability, or actions.',
            ]),
          ]),

          _card(context, '8. Purchases & Fees', [
            _p(
              'The current version of the App does not include in‑app purchases or subscriptions. If we introduce paid features in the future, separate terms and pricing will apply.',
            ),
          ]),

          _card(context, '9. Termination', [
            _bullets([
              'We may suspend or terminate access to the App at any time for any reason, including breach of these Terms.',
              'You may stop using the App at any time and, if desired, uninstall it from your device.',
            ]),
          ]),

          _card(context, '10. Disclaimers', [
            _bullets([
              'THE APP IS PROVIDED “AS IS” AND “AS AVAILABLE” WITHOUT WARRANTIES OF ANY KIND, EXPRESS OR IMPLIED.',
              'WE DO NOT WARRANT THAT THE APP WILL BE UNINTERRUPTED, ERROR‑FREE, SECURE, OR FREE OF HARMFUL COMPONENTS.',
              'WE DO NOT CONTROL OR GUARANTEE THE ACCURACY OF THIRD‑PARTY CONTENT OR SERVICES.',
            ]),
          ]),

          _card(context, '11. Limitation of Liability', [
            _p(
              'To the maximum extent permitted by law, we will not be liable for any indirect, incidental, special, consequential, or punitive damages, or any loss of data, profits, or revenues, arising from your use of or inability to use the App.',
            ),
          ]),

          _card(context, '12. Changes to These Terms', [
            _p(
              'We may update these Terms from time to time. Continued use of the App after changes become effective constitutes acceptance of the revised Terms.',
            ),
          ]),

          _card(context, '13. Governing Law', [
            _p(
              'These Terms are governed by the laws of $region, without regard to conflict‑of‑law principles.',
            ),
          ]),

          _card(context, '14. Contact', [
            _p(
              'If you have any questions about these Terms, contact us at $contactEmail.',
            ),
          ]),
        ],
      ),
    );
  }
}
