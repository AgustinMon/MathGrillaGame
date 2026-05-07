import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/tutorial_screen.dart';
import 'domain/use_cases/math_engine.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Cargamos los niveles pre-diseñados desde el JSON.
  await MathEngine.loadLevels();
  
  if (!kIsWeb) {
    try {
      await MobileAds.instance.initialize();
    } catch (e) {
      debugPrint('Error initializing ads: $e');
    }
  }

  runApp(
    const ProviderScope(
      child: CrucimathApp(),
    ),
  );
}

class CrucimathApp extends StatelessWidget {
  const CrucimathApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crucimath',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark, // Default to dark as requested
      home: const TutorialScreen(),
    );
  }
}
