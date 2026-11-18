import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_strings.dart';
import 'core/database/database_helper.dart';
import 'core/database/database_tables.dart';
import 'core/security/pin_service.dart';
import 'core/security/auth_service.dart';
import 'core/security/privacy_provider.dart';
import 'core/localization/language_provider.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure edge-to-edge system bars immediately so status bar and navigation bar match the dark theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFF03050B),
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  // Only lock orientation on Android mobile; allow free resize on Web/Desktop
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // Initialize Language preference
  final languageProvider = LanguageProvider();
  await languageProvider.init();

  // Initialize Auth state
  try {
    await AuthService.init();
  } catch (_) {}

  // Check stored PIN settings:
  // ONLY ask for password IF the owner explicitly set a PIN in Settings!
  bool hasPin = false;
  try {
    final db = await DatabaseHelper.instance.database.timeout(const Duration(milliseconds: 350));

    final userConfiguredRow = await db.query(
      DatabaseTables.tableAppSettings,
      where: 'setting_key = ?',
      whereArgs: ['app_pin_user_configured'],
      limit: 1,
    ).timeout(const Duration(milliseconds: 200));

    final enabledRow = await db.query(
      DatabaseTables.tableAppSettings,
      where: 'setting_key = ?',
      whereArgs: ['app_pin_enabled'],
      limit: 1,
    ).timeout(const Duration(milliseconds: 200));

    final isUserConfigured = userConfiguredRow.isNotEmpty && userConfiguredRow.first['setting_value'] == 'true';
    final isEnabled = enabledRow.isNotEmpty && enabledRow.first['setting_value'] == 'true';

    if (isUserConfigured && isEnabled) {
      final pinRow = await db.query(
        DatabaseTables.tableAppSettings,
        where: 'setting_key = ?',
        whereArgs: ['app_pin_hash'],
        limit: 1,
      ).timeout(const Duration(milliseconds: 200));

      if (pinRow.isNotEmpty) {
        final hash = pinRow.first['setting_value'] as String?;
        if (hash != null && hash.isNotEmpty) {
          PinService.initialize(hash);
          hasPin = true;
        } else {
          hasPin = false;
          PinService.initialize(null);
        }
      } else {
        hasPin = false;
        PinService.initialize(null);
      }
    } else {
      hasPin = false;
      PinService.initialize(null);
    }
  } catch (_) {
    hasPin = false;
    PinService.initialize(null);
  }

  runApp(
    DmLaceApp(hasPin: hasPin, languageProvider: languageProvider),
  );
}

class DmLaceApp extends StatelessWidget {
  final bool hasPin;
  final LanguageProvider? languageProvider;

  const DmLaceApp({
    super.key,
    this.hasPin = false,
    this.languageProvider,
  });

  @override
  Widget build(BuildContext context) {
    final lang = languageProvider ?? LanguageProvider();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LanguageProvider>.value(value: lang),
        ChangeNotifierProvider<PrivacyProvider>(create: (_) => PrivacyProvider()),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, langProvider, _) {
          return MaterialApp(
            title: AppStrings.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: SplashScreen(hasPinConfigured: hasPin),
          );
        },
      ),
    );
  }
}
