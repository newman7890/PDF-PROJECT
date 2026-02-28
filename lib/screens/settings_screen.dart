import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import 'privacy_policy_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsService = context.watch<SettingsService>();
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
        children: [
          _buildSectionHeader(context, 'Appearance'),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Theme Mode'),
            subtitle: Text(settingsService.themeName),
            onTap: () => _showThemeDialog(context, settingsService),
          ),
          const Divider(),
          _buildSectionHeader(context, 'About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('App Version'),
            trailing: Text('1.0.0', style: TextStyle(color: Colors.grey)),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Licenses'),
            onTap: () => showLicensePage(context: context),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
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
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text(
              'Clear Cache',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () => _showClearCacheDialog(context),
          ),
        ],
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

  void _showThemeDialog(BuildContext context, SettingsService settingsService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme'),
        content: RadioGroup<ThemeMode>(
          groupValue: settingsService.themeMode,
          onChanged: (value) {
            if (value != null) settingsService.setThemeMode(value);
            Navigator.pop(context);
          },
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ThemeMode>(
                title: Text('System Default'),
                value: ThemeMode.system,
              ),
              RadioListTile<ThemeMode>(
                title: Text('Light'),
                value: ThemeMode.light,
              ),
              RadioListTile<ThemeMode>(
                title: Text('Dark'),
                value: ThemeMode.dark,
              ),
            ],
          ),
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
