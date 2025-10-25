// lib/features/settings/settings_page.dart
// Offline, sectioned UI + rounded/glassy cards + unified edit sheet (uses lib/ui/glass_sheet.dart)
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/theme_controller.dart';
import '../../ui/glass_sheet.dart'; // GlassStyle + GlassSheet
import '../../core/assets/assets.dart'; // <-- Added for placeholders

import 'about_page.dart';
import 'privacy_page.dart';
import 'terms_page.dart';

class SettingsPage extends StatefulWidget {
  final ThemeController themeCtrl;
  const SettingsPage({super.key, required this.themeCtrl});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late AppThemeMode _mode;
  late AppBrand _brand;
  bool _hapticEnabled = true;

  // Local profile
  String _profileName = 'FlickNest user';
  String? _profilePhoto; // file/asset path
  String? _coverPhoto;   // file/asset path

  @override
  void initState() {
    super.initState();
    _mode = widget.themeCtrl.appMode;
    _brand = widget.themeCtrl.brand;
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _hapticEnabled = p.getBool('haptic_enabled') ?? true;
      final n = p.getString('profile_name') ?? 'FlickNest user';
      _profileName = n.trim().isEmpty ? 'FlickNest user' : n.trim();
      _profilePhoto = p.getString('profile_photo');
      _coverPhoto = p.getString('profile_cover');
    });
  }

  Future<void> _setMode(AppThemeMode m) async {
    setState(() => _mode = m);
    await widget.themeCtrl.setMode(m);
    if (_hapticEnabled) HapticFeedback.selectionClick();
  }

  Future<void> _setBrand(AppBrand b) async {
    setState(() => _brand = b);
    await widget.themeCtrl.setBrand(b);
    if (_hapticEnabled) HapticFeedback.selectionClick();
  }

  // About-style helpers (same glass tone as About page)
  Color _glass(BuildContext ctx, [double a = 0.08]) =>
      (Theme.of(ctx).brightness == Brightness.dark ? Colors.white : Colors.black)
          .withValues(alpha: a);
  Color _border(BuildContext ctx, [double a = 0.12]) =>
      (Theme.of(ctx).brightness == Brightness.dark ? Colors.white : Colors.black)
          .withValues(alpha: a);

  // ---------------- File helpers ----------------
  Future<String?> _saveXFileToDocs(XFile x, {String prefix = 'media'}) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final destPath =
          '${dir.path}/${prefix}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(x.path).copy(destPath);
      return destPath;
    } catch (_) {
      return null;
    }
  }

  ImageProvider<Object>? _imageProviderFor(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('assets/')) return AssetImage(path);
    final f = File(path);
    if (f.existsSync()) return FileImage(f);
    return null;
  }

  // ---------------- Unified EDIT sheet: name + avatar + cover ----------------
  Future<void> _openUnifiedEditSheet() async {
    String tmpName = _profileName;
    String? tmpAvatar = _profilePhoto;
    String? tmpCover = _coverPhoto;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final style = GlassStyle.strong3D(cs);
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;

        return StatefulBuilder(
          builder: (ctx2, setSB) {
            Future<void> pickAvatarFromGallery() async {
              try {
                final x = await ImagePicker().pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 85,
                );
                if (x == null) return;
                final saved = await _saveXFileToDocs(x, prefix: 'avatar');
                if (saved != null) {
                  if (!ctx2.mounted) return;
                  setSB(() => tmpAvatar = saved);
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to pick avatar: $e')),
                );
              }
            }

            Future<void> takeAvatarPhoto() async {
              final status = await Permission.camera.request();
              if (!status.isGranted) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Camera permission denied')),
                );
                return;
              }
              try {
                final x = await ImagePicker().pickImage(
                  source: ImageSource.camera,
                  imageQuality: 85,
                );
                if (x == null) return;
                final saved = await _saveXFileToDocs(x, prefix: 'avatar');
                if (saved != null) {
                  if (!ctx2.mounted) return;
                  setSB(() => tmpAvatar = saved);
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to capture avatar: $e')),
                );
              }
            }

            Future<void> pickCoverFromGallery() async {
              try {
                final x = await ImagePicker().pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 90,
                );
                if (x == null) return;
                final saved = await _saveXFileToDocs(x, prefix: 'cover');
                if (saved != null) {
                  if (!ctx2.mounted) return;
                  setSB(() => tmpCover = saved);
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to pick cover: $e')),
                );
              }
            }

            Future<void> takeCoverPhoto() async {
              final status = await Permission.camera.request();
              if (!status.isGranted) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Camera permission denied')),
                );
                return;
              }
              try {
                final x = await ImagePicker().pickImage(
                  source: ImageSource.camera,
                  imageQuality: 90,
                );
                if (x == null) return;
                final saved = await _saveXFileToDocs(x, prefix: 'cover');
                if (saved != null) {
                  if (!ctx2.mounted) return;
                  setSB(() => tmpCover = saved);
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to capture cover: $e')),
                );
              }
            }

            void removeAvatar() => setSB(() => tmpAvatar = null);
            void removeCover() => setSB(() => tmpCover = null);

            // ==== Overflow-safe wrapper (only change) ====
            return SafeArea(
              child: LayoutBuilder(
                builder: (ctx3, cons) {
                  // সর্বোচ্চ উচ্চতা ভিউপোর্টের 96% — কেবল কনটেন্ট বড় হলে স্ক্রল হবে
                  final maxH = cons.maxHeight * 0.96;

                  return Padding(
                    padding: EdgeInsets.only(bottom: bottom),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: maxH),
                      child: GlassSheet(
                        style: style,
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                'Edit profile',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: cs.onSurface,
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Cover preview
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  height: 110,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        cs.surfaceContainerHighest.withValues(alpha: 0.35),
                                        cs.primary.withValues(alpha: 0.14),
                                        cs.surface.withValues(alpha: 0.20),
                                      ],
                                      stops: const [0.0, 0.6, 1.0],
                                    ),
                                  ),
                                  child: (tmpCover != null && _imageProviderFor(tmpCover) != null)
                                      ? Ink.image(
                                          image: _imageProviderFor(tmpCover!)!,
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: [
                                  FilledButton.icon(
                                    onPressed: pickCoverFromGallery,
                                    icon: const Icon(Icons.photo_library_rounded),
                                    label: const Text('Gallery'),
                                  ),
                                  FilledButton.tonalIcon(
                                    onPressed: takeCoverPhoto,
                                    icon: const Icon(Icons.photo_camera_rounded),
                                    label: const Text('Camera'),
                                  ),
                                  TextButton.icon(
                                    onPressed: removeCover,
                                    icon: const Icon(Icons.delete_outline_rounded),
                                    label: const Text('Remove'),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 14),

                              // Avatar preview (bigger) — always fallback to person placeholder
                              CircleAvatar(
                                radius: 56,
                                backgroundImage:
                                    _imageProviderFor(tmpAvatar) ??
                                    const AssetImage(AppAssets.personPlaceholder),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: [
                                  FilledButton.icon(
                                    onPressed: pickAvatarFromGallery,
                                    icon: const Icon(Icons.photo_library_rounded),
                                    label: const Text('Gallery'),
                                  ),
                                  FilledButton.tonalIcon(
                                    onPressed: takeAvatarPhoto,
                                    icon: const Icon(Icons.photo_camera_rounded),
                                    label: const Text('Camera'),
                                  ),
                                  TextButton.icon(
                                    onPressed: removeAvatar,
                                    icon: const Icon(Icons.delete_outline_rounded),
                                    label: const Text('Remove'),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 14),

                              // Name
                              TextField(
                                controller: TextEditingController(text: tmpName),
                                onChanged: (v) => tmpName = v,
                                textInputAction: TextInputAction.done,
                                decoration: const InputDecoration(
                                  labelText: 'Display name',
                                  hintText: 'Enter your name',
                                ),
                              ),

                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      if (!ctx.mounted) return;
                                      Navigator.pop(ctx);
                                    },
                                    child: const Text('Cancel'),
                                  ),
                                  const Spacer(),
                                  ElevatedButton(
                                    onPressed: () async {
                                      final finalName =
                                          (tmpName.trim().isEmpty) ? 'FlickNest user' : tmpName.trim();
                                      final p = await SharedPreferences.getInstance();
                                      await p.setString('profile_name', finalName);
                                      if (tmpAvatar == null) {
                                        await p.remove('profile_photo');
                                      } else {
                                        await p.setString('profile_photo', tmpAvatar!);
                                      }
                                      if (tmpCover == null) {
                                        await p.remove('profile_cover');
                                      } else {
                                        await p.setString('profile_cover', tmpCover!);
                                      }
                                      if (!mounted) return;
                                      setState(() {
                                        _profileName = finalName;
                                        _profilePhoto = tmpAvatar;
                                        _coverPhoto = tmpCover;
                                      });
                                      if (_hapticEnabled) HapticFeedback.lightImpact();
                                      if (!ctx.mounted) return;
                                      Navigator.pop(ctx);
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Profile updated')),
                                      );
                                    },
                                    child: const Text('Save'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  // ---------------- UI helpers ----------------
  String _themeLabel(AppThemeMode m) => switch (m) {
        AppThemeMode.light => 'Light',
        AppThemeMode.dark => 'Dark',
        AppThemeMode.system => 'System',
      };

  String _brandLabel(AppBrand b) => switch (b) {
        AppBrand.orange => 'Orange',
        AppBrand.blue => 'Blue',
        AppBrand.green => 'Green',
        AppBrand.red => 'Red',
        AppBrand.teal => 'Teal',
        AppBrand.cyan => 'Cyan',
        AppBrand.indigo => 'Indigo',
        AppBrand.pink => 'Pink',
        AppBrand.purple => 'Purple',
      };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.6);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // Section: Profile
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text('Profile', style: t.titleLarge),
          ),
          Card(
            elevation: 0,
            color: _glass(context, 0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: _border(context, 0.12)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // Cover + edit icon (top-right)
                SizedBox(
                  height: 180,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_coverPhoto != null &&
                          _imageProviderFor(_coverPhoto) != null)
                        Ink.image(
                          image: _imageProviderFor(_coverPhoto!)!,
                          fit: BoxFit.cover,
                        )
                      else
                        // Glassy 3D placeholder cover
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                cs.surfaceContainerHighest.withValues(alpha: 0.35),
                                cs.primary.withValues(alpha: 0.14),
                                cs.surface.withValues(alpha: 0.20),
                              ],
                              stops: const [0.0, 0.6, 1.0],
                            ),
                          ),
                        ),

                      // Top glare
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 26,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(alpha: 0.18),
                                  Colors.white.withValues(alpha: 0.00),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Bottom black fade (merge nicely)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 90,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.35),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Single edit icon (top-right)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Tooltip(
                          message: 'Edit profile',
                          child: Material(
                            color: Colors.black.withValues(alpha: 0.25),
                            shape: const CircleBorder(),
                            child: IconButton(
                              onPressed: _openUnifiedEditSheet,
                              icon: const Icon(Icons.edit_rounded),
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      // Avatar center (bigger) — always fallback to person placeholder
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Transform.translate(
                          offset: const Offset(0, 34),
                          child: CircleAvatar(
                            radius: 60,
                            backgroundImage:
                                _imageProviderFor(_profilePhoto) ??
                                const AssetImage(AppAssets.personPlaceholder),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 52), // space for avatar overlap

                // Username centered and bigger
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: [
                      Text(
                        _profileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 24, // bigger username
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // App Settings (only Theme)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6, top: 6),
            child: Text('App Settings', style: t.titleLarge),
          ),
          Card(
            elevation: 0,
            color: _glass(context, 0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: _border(context, 0.12)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.color_lens_outlined),
                  title: const Text('Theme'),
                  subtitle: Text('${_themeLabel(_mode)} • ${_brandLabel(_brand)}'),
                  onTap: _openThemePicker,
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Legal & About
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6, top: 6),
            child: Text('Legal & About', style: t.titleLarge),
          ),
          Card(
            elevation: 0,
            color: _glass(context, 0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: _border(context, 0.12)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AboutPage()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy Policy'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PrivacyPage()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Terms of Service'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TermsPage()),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),
          // App build at bottom
          Center(
            child: Text(
              'FlickNest • Build 1.0.0',
              style: TextStyle(color: muted),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Theme picker (GlassSheet-based) ----------------
  Future<void> _openThemePicker() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final style = GlassStyle.editSheet(cs);

        AppThemeMode temp = _mode;

        return GlassSheet(
          style: style,
          child: StatefulBuilder(
            builder: (ctx2, setSB) {
              Widget seg(String label, AppThemeMode m) {
                final bool sel = temp == m;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setSB(() => temp = m);
                      _setMode(m);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: sel
                            ? cs.primary.withValues(alpha: 0.18)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: sel ? cs.primary : cs.onSurface,
                        ),
                      ),
                    ),
                  ),
                );
              }

              final swatches = <_BrandSwatch>[
                _BrandSwatch('Purple', AppTheme.brandPurple, AppBrand.purple),
                _BrandSwatch('Orange', AppTheme.brandOrange, AppBrand.orange),
                _BrandSwatch('Blue', AppTheme.brandBlue, AppBrand.blue),
                _BrandSwatch('Green', AppTheme.brandGreen, AppBrand.green),
                _BrandSwatch('Red', AppTheme.brandRed, AppBrand.red),
                _BrandSwatch('Teal', AppTheme.brandTeal, AppBrand.teal),
                _BrandSwatch('Cyan', AppTheme.brandCyan, AppBrand.cyan),
                _BrandSwatch('Indigo', AppTheme.brandIndigo, AppBrand.indigo),
                _BrandSwatch('Pink', AppTheme.brandPink, AppBrand.pink),
              ];

              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Theme',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        seg('System', AppThemeMode.system),
                        const SizedBox(width: 6),
                        seg('Light', AppThemeMode.light),
                        const SizedBox(width: 6),
                        seg('Dark', AppThemeMode.dark),
                      ],
                    ),

                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Brand color',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    LayoutBuilder(
                      builder: (ctx3, c) {
                        const double circle = 50;
                        return Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: swatches.map((s) {
                            final bool selected = _brand == s.brand;
                            return GestureDetector(
                              onTap: () => _setBrand(s.brand),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Container(
                                        width: circle,
                                        height: circle,
                                        decoration: BoxDecoration(
                                          color: s.color,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.25),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (selected)
                                        const Icon(Icons.check, color: Colors.white),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    width: circle + 24,
                                    child: Text(
                                      s.label,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),

                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _BrandSwatch {
  final String label;
  final Color color;
  final AppBrand brand;
  _BrandSwatch(this.label, this.color, this.brand);
}