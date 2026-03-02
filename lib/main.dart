import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/storage_service.dart';
import 'services/pdf_service.dart';
import 'services/ocr_service.dart';
import 'services/permission_service.dart';
import 'services/image_processing_service.dart';
import 'services/pdf_editor_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<PdfEditorService>(
          create: (_) => PdfEditorService(),
        ),
        Provider<StorageService>(create: (_) => StorageService()),
        Provider<PDFService>(create: (_) => PDFService()),
        Provider<OCRService>(
          create: (_) => OCRService(),
          dispose: (_, service) => service.dispose(),
        ),
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
      title: 'PDF SCANNER & VIEWER',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.black,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', 'US')],
      home: const HomeScreen(),
    );
  }
}
