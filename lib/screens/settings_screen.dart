import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'privacy_policy_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCardSection(context, 'Support & Feedback', [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.share_outlined, color: Colors.green),
              ),
              title: const Text('Share App'),
              subtitle: const Text('Tell your friends about us'),
              onTap: () => _shareApp(context),
            ),
            const Divider(indent: 56),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mail_outline, color: Colors.orange),
              ),
              title: const Text('Email Support'),
              subtitle: const Text('Need help? Contact us'),
              onTap: () => _emailSupport(context),
            ),
            const Divider(indent: 56),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.star_outline, color: Colors.amber),
              ),
              title: const Text('Rate App'),
              subtitle: const Text('Support our development'),
              onTap: () => _rateApp(context),
            ),
          ]),
          const SizedBox(height: 16),
          _buildCardSection(context, 'Legal & Info', [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.indigo.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.privacy_tip_outlined,
                  color: Colors.indigo,
                ),
              ),
              title: const Text('Privacy Policy'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PrivacyPolicyScreen(),
                  ),
                );
              },
            ),
            const Divider(indent: 56),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: Colors.grey,
                ),
              ),
              title: const Text('Licenses'),
              onTap: () => showLicensePage(context: context),
            ),
            const Divider(indent: 56),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('App Version'),
              trailing: Text(
                '1.0.0',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ]),
          const SizedBox(height: 24),
          _buildCardSection(context, 'Danger Zone', [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Clear Cache',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () => _showClearCacheDialog(context),
            ),
          ]),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildCardSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, title),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey[200]!, width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }

  void _shareApp(BuildContext context) {
    Share.share(
      'Check out this professional PDF Scanner & Editor! It processes everything locally for maximum privacy. Download it now!',
    );
  }

  void _emailSupport(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Support'),
        content: const Text(
          'Please send your feedback or issues to newm5811@gmail.com.\n\nWe typically respond within 24 hours.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Share.share(
                'Contact newm5811@gmail.com for help with the PDF Scanner App.',
              );
            },
            child: const Text('Copy Email'),
          ),
        ],
      ),
    );
  }

  void _rateApp(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Coming soon to App Store and Google Play!'),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache?'),
        content: const Text(
          'This will delete temporary preview files. Your documents will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Cache clearing logic could be added here
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Cache cleared')));
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
