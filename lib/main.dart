import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/utils/consent_manager.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/tutorial_screen.dart';
import 'domain/use_cases/math_engine.dart';
import 'presentation/providers/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bloquear orientación en vertical
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Cargamos los niveles pre-diseñados desde el JSON.
  await MathEngine.loadLevels();

  if (!kIsWeb) {
    try {
      final prefs = await SharedPreferences.getInstance();
      final geography = prefs.getString('geography') ?? 'global';

      // Pasar el testDeviceId del usuario
      await ConsentManager.gatherConsent(
        geography,
        '5dd73622-0e4d-457b-a1d1-99835fff45a5',
      );
    } catch (e) {
      debugPrint('Error initializing consent/ads: $e');
    }
  }

  runApp(const ProviderScope(child: CrucimathApp()));
}

class CrucimathApp extends ConsumerWidget {
  const CrucimathApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'Crucimath',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
      locale: settings.locale,
      home: const TutorialScreen(),
    );
  }
}
