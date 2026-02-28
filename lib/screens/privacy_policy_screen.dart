import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Privacy Policy',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Policy for PDF Scanner & Viewer',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Last Updated: February 2026',
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              '1. Information We Collect',
              'Our application is designed to respect your privacy. We do not collect, store, or transmit any of your personal data, documents, or scanned images to external servers. All processing (PDF generation and viewing) happens locally on your device.',
            ),
            _buildSection(
              context,
              '2. Permissions',
              'The app requires access to your Camera to scan documents and Storage to save and open PDF files. These permissions are used solely for the functionality of the app on your device.',
            ),
            _buildSection(
              context,
              '3. Third-Party Services',
              'We use Google ML Kit for on-device text recognition. This service operates entirely on your phone and does not send your data to Google servers for processing.',
            ),
            _buildSection(
              context,
              '4. Data Security',
              'As your data never leaves your device through our app, you are in full control of your documents. We recommend using device-level security (passcodes, biometrics) to protect your files.',
            ),
            _buildSection(
              context,
              '5. Changes to This Policy',
              'We may update our Privacy Policy from time to time. Any changes will be posted on this page with an updated "Last Updated" date.',
            ),
            _buildSection(
              context,
              '6. Contact Us',
              'If you have any questions about this Privacy Policy, please contact us at support@example.com.',
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}
