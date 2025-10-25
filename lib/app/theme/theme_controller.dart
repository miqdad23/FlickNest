import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

enum AppThemeMode { system, light, dark }

// Brand swatches: Purple, Orange, Blue, Green, Red, Teal, Cyan, Indigo, Pink
enum AppBrand { purple, orange, blue, green, red, teal, cyan, indigo, pink }

class ThemeController extends ChangeNotifier {
  static const _keyMode = 'theme_mode';
  static const _keyBrand = 'brand_color';

  AppThemeMode _mode = AppThemeMode.dark;
  AppBrand _brand = AppBrand.purple;

  AppThemeMode get appMode => _mode;
  AppBrand get brand => _brand;

  Color get brandPrimary => switch (_brand) {
        AppBrand.purple => AppTheme.brandPurple,
        AppBrand.orange => AppTheme.brandOrange,
        AppBrand.blue => AppTheme.brandBlue,
        AppBrand.green => AppTheme.brandGreen,
        AppBrand.red => AppTheme.brandRed,
        AppBrand.teal => AppTheme.brandTeal,
        AppBrand.cyan => AppTheme.brandCyan,
        AppBrand.indigo => AppTheme.brandIndigo,
        AppBrand.pink => AppTheme.brandPink,
      };

  ThemeMode get themeMode => switch (_mode) {
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
        AppThemeMode.system => ThemeMode.system,
      };

  ThemeData get lightTheme => AppTheme.light(brandPrimary);
  ThemeData get darkTheme => AppTheme.dark(brandPrimary);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // theme mode
    final vm = prefs.getString(_keyMode);
    switch (vm) {
      case 'light':
        _mode = AppThemeMode.light;
        break;
      case 'dark':
        _mode = AppThemeMode.dark;
        break;
      case 'system':
        _mode = AppThemeMode.system;
        break;
      default:
        _mode = AppThemeMode.dark;
    }

    // brand color
    final vb = prefs.getString(_keyBrand);
    switch (vb) {
      case 'orange':
        _brand = AppBrand.orange;
        break;
      case 'blue':
        _brand = AppBrand.blue;
        break;
      case 'green':
        _brand = AppBrand.green;
        break;
      case 'red':
        _brand = AppBrand.red;
        break;
      case 'teal':
        _brand = AppBrand.teal;
        break;
      case 'cyan':
        _brand = AppBrand.cyan;
        break;
      case 'indigo':
        _brand = AppBrand.indigo;
        break;
      case 'pink':
        _brand = AppBrand.pink;
        break;
      default:
        _brand = AppBrand.purple;
    }

    notifyListeners();
  }

  Future<void> setMode(AppThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMode, switch (mode) {
      AppThemeMode.light => 'light',
      AppThemeMode.dark => 'dark',
      AppThemeMode.system => 'system',
    });
  }

  Future<void> setBrand(AppBrand brand) async {
    if (_brand == brand) return;
    _brand = brand;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBrand, switch (brand) {
      AppBrand.purple => 'purple',
      AppBrand.orange => 'orange',
      AppBrand.blue => 'blue',
      AppBrand.green => 'green',
      AppBrand.red => 'red',
      AppBrand.teal => 'teal',
      AppBrand.cyan => 'cyan',
      AppBrand.indigo => 'indigo',
      AppBrand.pink => 'pink',
    });
  }
}