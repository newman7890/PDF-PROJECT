import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/storage_service.dart';
import 'services/pdf_service.dart';
import 'services/ocr_service.dart';
import 'services/permission_service.dart';
import 'services/image_processing_service.dart';
import 'services/pdf_editor_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'services/settings_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsService>(
          create: (_) => SettingsService(),
        ),
        ChangeNotifierProvider<PdfEditorService>(
          create: (_) => PdfEditorService(),
        ),
        Provider<StorageService>(create: (_) => StorageService()),
        Provider<PDFService>(create: (_) => PDFService()),
        Provider<OCRService>(create: (_) => OCRService()),
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
    return Consumer<SettingsService>(
      builder: (context, settings, _) {
        return MaterialApp(
          title: 'PDF SCANNER & VIEWER',
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,
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
      },
    );
  }
}
