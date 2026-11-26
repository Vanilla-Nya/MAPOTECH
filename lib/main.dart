import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapotech/features/landing/landing_page_layout.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/letter_models.dart';
import 'package:mapotech/shared/widgets/letter_verification_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  try {
    await dotenv.load(fileName: "env");
  } catch (e) {
    debugPrint("Warning: Could not load env file: $e");
  }

  await Supabase.initialize(
    url:
        dotenv.env['SUPABASE_URL'] ??
        'https://abdburxhqqwsobmzuwmz.supabase.co',
    publishableKey:
        dotenv.env['SUPABASE_ANON_KEY'] ??
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFiZGJ1cnhocXF3c29ibXp1d216Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY0OTMyNjYsImV4cCI6MjA5MjA2OTI2Nn0.mB3qIJAHjtWe5UKxE9Oj-RNLQCbQKFYHUZBLaF4nQwk',
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  MedicalLetterVerificationRequest? _initialVerifyRequest;

  @override
  void initState() {
    super.initState();
    _initialVerifyRequest = MedicalLetterVerificationRequest.parseUri(Uri.base);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);

    final primaryColor = notifier.getPrimaryColor();
    final secondaryColor = notifier.getSecondaryColor();
    final backgroundColor = notifier.getBackgroundColor();
    final cardColor = notifier.getCardColor();
    final textColor = notifier.getTextColor();
    final bodyTextColor = notifier.getBodyTextColor();

    final isDark = state.appearance == 'dark';

    return MaterialApp(
      title: 'MAPOTECH',
      debugShowCheckedModeBanner: false,
      locale: Locale(state.language),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: backgroundColor,
        cardColor: cardColor,
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.light,
          seedColor: state.appearance == 'rev' ? const Color(0xFFB577F2) : const Color(0xFF48C9B0),
          primary: primaryColor,
          secondary: secondaryColor,
          surface: cardColor,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.outfitTextTheme(Theme.of(context).textTheme).apply(
          bodyColor: bodyTextColor,
          displayColor: textColor,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: backgroundColor,
        cardColor: cardColor,
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: const Color(0xFFFAFAFA),
          primary: primaryColor,
          secondary: secondaryColor,
          surface: cardColor,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.outfitTextTheme(Theme.of(context).textTheme).apply(
          bodyColor: bodyTextColor,
          displayColor: textColor,
        ),
      ),
      onGenerateRoute: (settings) {
        final rawName = settings.name ?? '';
        final parsed = MedicalLetterVerificationRequest.parseUri(
          Uri.tryParse(rawName) ?? Uri(),
        );
        if (parsed != null) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => LetterVerificationPage(
              encounterId: parsed.encounterId,
              expectedType: parsed.expectedType,
              onBackToPortal: () {
                setState(() => _initialVerifyRequest = null);
              },
            ),
          );
        }
        return null;
      },
      home: _initialVerifyRequest != null
          ? LetterVerificationPage(
              encounterId: _initialVerifyRequest!.encounterId,
              expectedType: _initialVerifyRequest!.expectedType,
              onBackToPortal: () {
                setState(() => _initialVerifyRequest = null);
              },
            )
          : const LandingPageLayout(),
    );
  }
}

