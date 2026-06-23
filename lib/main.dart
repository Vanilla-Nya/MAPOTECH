import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mapotech/features/landing/landing_page_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://abdburxhqqwsobmzuwmz.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFiZGJ1cnhocXF3c29ibXp1d216Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY0OTMyNjYsImV4cCI6MjA5MjA2OTI2Nn0.mB3qIJAHjtWe5UKxE9Oj-RNLQCbQKFYHUZBLaF4nQwk',
  );

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final activeGreenColor = const Color(0xFF48C9B0);
    final darkGreenColor = const Color(0xFF1B4F42);

    return MaterialApp(
      title: 'MAPOTECH',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: activeGreenColor,
          primary: activeGreenColor,
          secondary: darkGreenColor,
          surface: const Color(0xFFFDFDFC),
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.outfitTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      home: const LandingPageLayout(),
    );
  }
}
