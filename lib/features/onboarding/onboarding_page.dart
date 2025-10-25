import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme/theme_controller.dart';
import '../home/home_page.dart';

class OnboardingPage extends StatefulWidget {
  final ThemeController themeCtrl;
  const OnboardingPage({super.key, required this.themeCtrl});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _step = 0;

  // Step 1: Profile
  final TextEditingController _nameCtrl = TextEditingController();
  String? _avatarPath;

  // Step 2: Notifications (চয়েস শুধু সেভ হবে; সিস্টেম পারমিশন পরে নেব)
  bool _notifWanted = true;

  // Step 3: Backup preference (Drive ইন্টেগ্রেশন পরে)
  bool _backupYes = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final XFile? x = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (x == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await x.saveTo(path);
    if (!mounted) return;
    setState(() => _avatarPath = path);
  }

  Future<void> _persistChoices() async {
    final prefs = await SharedPreferences.getInstance();

    // Profile
    final name = _nameCtrl.text.trim();
    await prefs.setString('profile_name', name.isEmpty ? 'Guest' : name);
    if (_avatarPath != null) {
      await prefs.setString('profile_avatar_path', _avatarPath!);
    }

    // Notifications choice (system permission পরে নেয়া হবে)
    await prefs.setBool('notifications_enabled', _notifWanted);

    // Backup preference
    await prefs.setBool('backup_pref_yes', _backupYes);

    // Onboarding done
    await prefs.setBool('onboarding_done', true);
  }

  Future<void> _finish() async {
    // 1) আগে ন্যাভিগেট করি → ইউজার সাথে সাথে Home দেখবে
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => HomePage(themeCtrl: widget.themeCtrl)),
      (_) => false,
    );

    // 2) তারপর পেছনে শান্তভাবে পছন্দগুলো সেভ করি
    // (কোনো এরর হলেও ইউজারের নেভিগেশন আটকে যাবে না)
    try {
      await _persistChoices();
    } catch (_) {
      // সাইলেন্ট
    }
  }

  void _next() {
    if (_step < 2) {
      setState(() => _step++);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final active = i == _step;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: active ? 20 : 8,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white24,
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }

  Widget _stepProfile(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 12),
        Text(
          'Create your profile',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _pickPhoto,
          child: CircleAvatar(
            radius: 44,
            backgroundColor: Colors.white10,
            backgroundImage: (_avatarPath != null)
                ? FileImage(File(_avatarPath!))
                : null,
            child: (_avatarPath == null)
                ? const Icon(Icons.camera_alt_outlined, color: Colors.white70)
                : null,
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TextField(
            controller: _nameCtrl,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Your Name',
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'You can change these later from Profile',
          style: TextStyle(color: Colors.white54),
        ),
      ],
    );
  }

  Widget _stepNotifications(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Text(
          'Notifications',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Enable push notifications to get reminders, weekly picks and updates.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Enable notifications'),
          value: _notifWanted,
          onChanged: (v) => setState(() => _notifWanted = v),
        ),
        const SizedBox(height: 6),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'We will ask for system permission later when needed.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54),
          ),
        ),
      ],
    );
  }

  Widget _stepBackup(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Text('Cloud Backup', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Keep your lists and data safe with cloud backup.\n'
            'You can enable it now (WhatsApp-style restore will appear on first login).',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
        ),
        const SizedBox(height: 16),
        ToggleButtons(
          isSelected: [_backupYes, !_backupYes],
          onPressed: (i) => setState(() => _backupYes = (i == 0)),
          borderRadius: BorderRadius.circular(12),
          selectedColor: Colors.white,
          fillColor: Colors.white10,
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text('Turn On'),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text('Not now'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'If enabled, we will link Google Drive later and restore if a backup exists.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final steps = [
      _stepProfile(context),
      _stepNotifications(context),
      _stepBackup(context),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup'),
        leading: _step > 0
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _back)
            : null,
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          _buildDots(),
          const SizedBox(height: 12),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: SingleChildScrollView(
                key: ValueKey(_step),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Center(child: steps[_step]),
              ),
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                if (_step < 2)
                  TextButton(
                    onPressed: _finish, // Skip → সঙ্গে সঙ্গে Home
                    child: const Text('Skip'),
                  ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _next,
                  child: Text(_step < 2 ? 'Next' : 'Finish'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
