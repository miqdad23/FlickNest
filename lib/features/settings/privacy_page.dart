// lib/features/settings/privacy_page.dart
// Professional Privacy Policy — glassy rounded cards (About-style)
import 'package:flutter/material.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

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
      appBar: AppBar(title: const Text('Privacy Policy')),
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

          _card(context, '1. Overview', [
            _p(
              'This Privacy Policy explains how $companyOrDevName (“we”, “us”, or “our”) collects, uses, and protects your information when you use $appName (the “App”).',
            ),
            _p(
              'We provide two variants: (a) Offline Build (no sign‑in), and (b) Online Build (sign‑in, cloud sync). Your data handling may vary across these variants as described below.',
            ),
          ]),

          _card(context, '2. Data We Collect', [
            _p('A) Offline Build (No Sign‑in):'),
            _bullets([
              'App preferences (e.g., theme/brand, notification preference, haptic toggle) stored on your device.',
              'Your lists, favorites, watched items, and cached metadata stored locally on your device.',
              'Optional profile name, avatar, and cover images you select; stored locally in app storage.',
              'We do not collect personal data on our servers in the Offline Build.',
            ]),
            const SizedBox(height: 8),
            _p('B) Online Build (Sign‑in & Sync, if enabled):'),
            _bullets([
              'Account data (e.g., email, display name, profile photo) for authentication purposes.',
              'App content data (e.g., lists, favorites, watched items, settings) that may sync to cloud storage.',
              'Basic device information (e.g., app version, device model) for diagnostics and security.',
              'We do not intentionally collect precise location or sensitive categories unless you explicitly provide them.',
            ]),
          ]),

          _card(context, '3. How We Use Your Data', [
            _bullets([
              'To provide core features (browsing titles, creating/saving lists, offline cache).',
              'To enable optional cloud backup/sync in Online Build.',
              'To improve stability, performance, and user experience.',
              'To communicate important information (e.g., policy updates).',
            ]),
          ]),

          _card(context, '4. Local Storage & Offline Cache', [
            _p(
              'In the Offline Build, your data primarily stays on your device. Clearing app data or uninstalling the App may permanently delete your local data.',
            ),
          ]),

          _card(context, '5. Cloud Services (Online Build)', [
            _p(
              'If you use the Online Build, some data may be stored with cloud providers (e.g., authentication, storage, database). These providers process data on our behalf under their policies.',
            ),
            _p(
              'Your data may be transferred to and processed in countries other than yours; by using the Online Build, you consent to such transfers as permitted by law.',
            ),
          ]),

          _card(context, '6. Third‑Party Services', [
            _bullets([
              'The Movie Database (TMDB) — to fetch metadata and images; governed by TMDB’s terms and privacy policy.',
              'Cloud providers (e.g., Firebase) in Online Build — authentication, storage, database.',
              'We do not control third‑party services and are not responsible for their practices.',
            ]),
          ]),

          _card(context, '7. Permissions We Use', [
            _bullets([
              'Camera — to capture an avatar or cover photo (optional).',
              'Photos/Media — to pick an image from your gallery (optional).',
              'Notifications — to show alerts if you enable them (optional).',
            ]),
          ]),

          _card(context, '8. Data Retention', [
            _p(
              'Offline Build: Data remains on your device until you delete it or uninstall the App.',
            ),
            _p(
              'Online Build: We retain data as long as your account is active or as needed to provide services, comply with legal obligations, resolve disputes, and enforce agreements.',
            ),
          ]),

          _card(context, '9. Security', [
            _p(
              'We implement reasonable technical and organizational measures to safeguard your data. However, no method of transmission or storage is 100% secure. You use the App at your own risk.',
            ),
          ]),

          _card(context, '10. Children’s Privacy', [
            _p(
              'The App is not directed to children under 13 (or the minimum age required by law in your region). If you are a parent/guardian and believe your child provided personal data, please contact us at $contactEmail.',
            ),
          ]),

          _card(context, '11. Your Rights', [
            _p(
              'Depending on your region, you may have rights to access, rectify, delete, or port your data, and to object/restrict certain processing (subject to legal limits). For requests, contact $contactEmail.',
            ),
          ]),

          _card(context, '12. International Users', [
            _p(
              'If you access the Online Build from outside $region, you consent to processing and transfer of your data as described in this Policy and permitted by applicable law.',
            ),
          ]),

          _card(context, '13. Changes to This Policy', [
            _p(
              'We may update this Policy from time to time. Material changes will be posted in the App. Continued use after changes become effective constitutes acceptance of the updated Policy.',
            ),
          ]),

          _card(context, '14. Contact', [
            _p(
              'For any privacy questions or requests, contact us at $contactEmail.',
            ),
          ]),
        ],
      ),
    );
  }
}
