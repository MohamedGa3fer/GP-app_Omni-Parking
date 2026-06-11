import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:gp_app/core/l10n/app_translations.dart';
import 'package:gp_app/core/theme/app_theme.dart';
import 'package:gp_app/features/parking/data/repositories/parking_repository_impl.dart';
import 'package:gp_app/features/parking/presentation/providers/parking_provider.dart';
import 'package:gp_app/features/parking/presentation/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final localeService = LocaleService();
  await localeService.loadSavedLocale();

  final themeService = ThemeService();
  await themeService.loadSavedTheme();

  try {
    // Repository wires up SQLite + the on-device AI. The TFLite models are NOT
    // loaded here — they load lazily the first time the scanner opens, so app
    // startup stays fast. (Failures surface in the scanner, not at launch.)
    final repository = ParkingRepositoryImpl();

    final parkingProvider = ParkingProvider(repository);

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: localeService),
          ChangeNotifierProvider.value(value: themeService),
          ChangeNotifierProvider.value(value: parkingProvider),
        ],
        child: const GpApp(),
      ),
    );
  } catch (e, stack) {
    debugPrint('FATAL: app initialization failed: $e\n$stack');
    runApp(_InitErrorApp(message: e.toString()));
  }
}

/// Minimal fallback shown when startup initialization fails (e.g. a model
/// asset is missing/corrupt or the isolate can't spawn). Better than a blank
/// screen — tells the user what happened.
class _InitErrorApp extends StatelessWidget {
  final String message;
  const _InitErrorApp({required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0A0E1A),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    color: Colors.redAccent, size: 64),
                const SizedBox(height: 20),
                const Text(
                  'Failed to start',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GpApp extends StatelessWidget {
  const GpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeService, LocaleService>(
      builder: (context, themeService, localeService, _) {
        return MaterialApp(
          title: 'Omni Parking',
          debugShowCheckedModeBanner: false,
          theme: themeService.isDarkMode
              ? AppTheme.darkTheme
              : AppTheme.lightTheme,
          locale: localeService.currentLocale,
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            // Clamp OS text scaling so an extreme accessibility font size can't
            // overflow the fixed-size layouts (moderate scaling still honoured).
            Widget app = MediaQuery(
              data: mq.copyWith(
                textScaler: mq.textScaler
                    .clamp(minScaleFactor: 0.85, maxScaleFactor: 1.2),
              ),
              child: child!,
            );
            // On wide screens (tablets, landscape, foldables) centre the UI at a
            // comfortable phone-like width instead of stretching edge-to-edge.
            // Phones in portrait (width < 600) are unaffected.
            if (mq.size.width > 600) {
              app = ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: app,
                  ),
                ),
              );
            }
            return app;
          },
          home: const SplashScreen(),
        );
      },
    );
  }
}
