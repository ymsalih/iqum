import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'application/app_controller.dart';
import 'data/backend.dart';
import 'data/local_store.dart';
import 'ui/components.dart';
import 'ui/home_screen.dart';
import 'ui/responsive.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    for (final family in ['Baloo2', 'Nunito']) {
      final text = await rootBundle.loadString('assets/fonts/$family-OFL.txt');
      yield LicenseEntryWithLineBreaks([family], text);
    }
  });
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.ivory,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const Bootstrap());
}

class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});
  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  late Future<AppController> setup = _setup();
  Future<AppController> _setup() async {
    final store = await LocalStore.open();
    final backend = await FirebaseBackend.initialize();
    final controller = AppController(store, backend);
    await controller.restore();
    return controller;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AppController>(
    future: setup,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return ProviderScope(
          overrides: [appProvider.overrideWith((ref) => snapshot.data!)],
          child: const IqumApp(),
        );
      }
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppColors.theme,
        builder: (context, child) => AppFrame(child: child!),
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Brand(size: 65),
                    const SizedBox(height: 32),
                    if (snapshot.hasError) ...[
                      const Text(
                        'Kayıtların şu an açılamadı. Yeniden deneyebilirsin.',
                        textAlign: TextAlign.center,
                        style: AppColors.caption,
                      ),
                      const SizedBox(height: 20),
                      IqumButton(
                        'Yeniden dene',
                        onPressed: () => setState(() => setup = _setup()),
                      ),
                    ] else
                      const SizedBox(
                        width: 25,
                        height: 25,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class IqumApp extends StatelessWidget {
  const IqumApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'IQUM',
    debugShowCheckedModeBanner: false,
    theme: AppColors.theme,
    locale: const Locale('tr'),
    supportedLocales: const [Locale('tr')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, child) => AppFrame(child: child!),
    home: const HomeScreen(),
  );
}
