import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme/app_theme.dart';
import '../../app/widgets/gradient_text.dart';
import 'privacy_page.dart';
import 'terms_page.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  // ---------- Update these constants with your info ----------
  static const String devName = 'miqdad23'; // ← তোমার নাম
  static const String githubUrl = 'https://github.com/miqdad23';
  static const String facebookUrl = 'https://facebook.com/miqdad23.bd';
  static const String telegramUrl = 'https://t.me/flicknest_app';
  static const String kofiUrl = 'https://ko-fi.com/miqdad23';
  static const String feedbackEmail = 'mikdad23.bd@gmail.com'; // ← আপডেট করো
  // ----------------------------------------------------------

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // Build a mailto URI with percent-encoded subject/body (no '+' issue)
  Uri _mailtoUri({
    required String email,
    required String subject,
    required String body,
  }) {
    final encSub = Uri.encodeComponent(subject);
    final encBody = Uri.encodeComponent(body);
    // Manual query string so space => %20 (not '+')
    return Uri.parse('mailto:$email?subject=$encSub&body=$encBody');
  }

  Future<void> _sendFeedbackEmail() async {
    const subject = 'FlickNest - Feedback/Review';
    const body = 'Hi,\n\n'
        'I want to share a review/feedback about FlickNest:\n\n'
        '• What I liked:\n'
        '• What can be improved:\n\n'
        'Thanks!';
    final uri = _mailtoUri(
      email: feedbackEmail,
      subject: subject,
      body: body,
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Home-এর মতো ব্র্যান্ড-ডাইনামিক টাইটেল গ্রেডিয়েন্ট
    final titleGradient = AppTheme.titleGradientFrom(cs.primary);

    Color glass([double a = 0.08]) =>
        (Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black)
            .withValues(alpha: a);
    Color border([double a = 0.12]) =>
        (Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black)
            .withValues(alpha: a);

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // Brand-dynamic gradient title (Home-style)
          Center(
            child: GradientText(
              'FlickNest',
              gradient: titleGradient,
              style: GoogleFonts.quicksand(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Movie & TV explorer',
              style: TextStyle(color: const Color.fromARGB(255, 153, 152, 152).withValues(alpha: 0.6)),
            ),
          ),
          const SizedBox(height: 16),

          // Attribution card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: glass(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border(0.12)),
            ),
            child: const Text(
              'This product uses the TMDB API but is not endorsed or certified by TMDB.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),

          // Links (TMDB + licenses)
          Card(
            elevation: 0,
            color: glass(0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: border(0.12)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.public),
                  title: const Text('Visit TMDB'),
                  subtitle: const Text('themoviedb.org'),
                  onTap: () => _openUrl('https://www.themoviedb.org/'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('TMDB API Terms of Use'),
                  onTap: () => _openUrl(
                    'https://www.themoviedb.org/documentation/api/terms-of-use',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.balance_outlined),
                  title: const Text('Open source licenses'),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'FlickNest',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Developer + Social + Support
          Card(
            elevation: 0,
            color: glass(0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: border(0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: const Text('Developer'),
                  subtitle: Text(devName),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code_rounded),
                  title: const Text('GitHub'),
                  subtitle: Text(
                    githubUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _openUrl(githubUrl),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.facebook_rounded),
                  title: const Text('Facebook'),
                  subtitle: Text(
                    facebookUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _openUrl(facebookUrl),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.telegram_rounded),
                  title: const Text('Telegram Channel'),
                  subtitle: Text(
                    telegramUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _openUrl(telegramUrl),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.local_cafe_rounded),
                  title: const Text('Support on Ko‑fi'),
                  subtitle: Text(
                    kofiUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _openUrl(kofiUrl),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Feedback (Rate hidden, only Send feedback)
          Card(
            elevation: 0,
            color: glass(0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: border(0.12)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('Send feedback'),
                  subtitle: Text(feedbackEmail),
                  onTap: _sendFeedbackEmail,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // App legal
          Card(
            elevation: 0,
            color: glass(0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: border(0.12)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.rule_folder_outlined),
                  title: const Text('Terms & Conditions'),
                  onTap: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const TermsPage())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy Policy'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PrivacyPage()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}