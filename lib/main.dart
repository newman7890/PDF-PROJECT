import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/storage_service.dart';
import 'services/pdf_service.dart';
import 'services/permission_service.dart';
import 'services/image_processing_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        Provider<StorageService>(create: (_) => StorageService()),
        Provider<PDFService>(create: (_) => PDFService()),
        Provider<PermissionService>(create: (_) => PermissionService()),
        Provider<ImageProcessingService>(
          create: (_) => ImageProcessingService(),
        ),
      ],
      child: const PDFScannerApp(),
    ),
  );
}

class PDFScannerApp extends StatelessWidget {
  const PDFScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF EDITOR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto', // Default, but can be changed
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.black,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.indigo.shade600,
          foregroundColor: Colors.white,
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', 'US')],
      home: const HomeScreen(),
    );
  }
}
