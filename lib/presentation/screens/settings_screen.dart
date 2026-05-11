import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/math_settings.dart';
import 'package:flutter/foundation.dart';
import '../../core/theme/app_theme.dart';
import '../providers/game_provider.dart';
import '../providers/settings_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: ref.read(settingsProvider).playerName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    final l10n = ref.watch(translationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.text('settings_title')),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSection(context, l10n.text('profile_section')),
          ListTile(
            title: Text(l10n.text('player_name_label')),
            subtitle: Text(l10n.text('stats_appearance')),
            trailing: SizedBox(
              width: 150,
              child: TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: l10n.text('player_name_hint'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                ),
                onChanged: (val) => notifier.setPlayerName(val),
              ),
            ),
          ),
          
          _buildSection(context, l10n.text('appearance_section')),
          ListTile(
            title: Text(l10n.text('language_label')),
            trailing: DropdownButton<String>(
              value: settings.locale.languageCode,
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'es', child: Text('Español')),
              ],
              onChanged: (val) {
                if (val != null) notifier.setLocale(Locale(val));
              },
            ),
          ),
          SwitchListTile(
            title: Text(l10n.text('dark_mode_label')),
            value: settings.themeMode == ThemeMode.dark,
            activeThumbColor: AppTheme.primaryBlue,
            onChanged: (val) => notifier.toggleTheme(),
          ),
          
          
          _buildSection(context, l10n.text('number_size_section')),
          Row(
            children: [
              _buildSizeOption(context, ref, l10n.text('small_label'), 0.8, settings.tileScale),
              _buildSizeOption(context, ref, l10n.text('normal_label'), 1.0, settings.tileScale),
              _buildSizeOption(context, ref, l10n.text('large_label'), 1.2, settings.tileScale),
            ],
          ),

          _buildSection(context, l10n.text('accessibility_section')),
          SwitchListTile(
            title: Text(l10n.text('scrollbar_left_label')),
            subtitle: Text(l10n.text('scrollbar_left_subtitle')),
            value: settings.scrollbarOnLeft,
            activeColor: AppTheme.primaryBlue,
            onChanged: (val) => notifier.setScrollbarOnLeft(val),
          ),

          const Divider(height: 40),
          _buildSection(context, l10n.text('privacy_compliance_section')),
          ListTile(
            title: Text(l10n.text('consent_status_label')),
            subtitle: Text(
              settings.consentAccepted == null 
                ? l10n.text('pending_status') 
                : (settings.consentAccepted! ? l10n.text('accepted_status') : l10n.text('rejected_status'))
            ),
            trailing: TextButton(
              onPressed: () => notifier.resetConsent(),
              child: Text(l10n.text('reset_button')),
            ),
          ),
          ListTile(
            title: Text(l10n.text('privacy_policy_title')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(l10n.text('privacy_policy_title')),
                  content: SingleChildScrollView(
                    child: Text(l10n.text('privacy_policy_content')),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => launchUrl(Uri.parse(l10n.text('privacy_policy_url'))),
                      child: Text(l10n.text('privacy_policy_button')),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l10n.text('understood_button')),
                    ),
                  ],
                ),
              );
            },
          ),
          
          if (kDebugMode) ...[
            const Divider(height: 40),
            _buildSection(context, l10n.text('debug_section')),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(l10n.text('simulate_geo_label'), style: const TextStyle(fontSize: 12)),
            ),
            Row(
              children: [
                _buildGeoOption(context, ref, 'Global', 'global', settings.geography),
                _buildGeoOption(context, ref, 'Europa (UE)', 'ue', settings.geography),
                _buildGeoOption(context, ref, 'USA (CCPA)', 'usa', settings.geography),
              ],
            ),

            const SizedBox(height: 20),
            ListTile(
              title: Text(l10n.text('jump_to_level_label')),
              subtitle: Text(l10n.text('jump_to_level_hint')),
              trailing: SizedBox(
                width: 80,
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(hintText: l10n.text('jump_to_level_hint')),
                  onSubmitted: (val) {
                    final level = int.tryParse(val);
                    if (level != null && level > 0) {
                      ref.read(gameProvider.notifier).startNewLevel(level);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.translate('jumping_to_level_msg', args: {'level': level.toString()}))),
                      );
                    }
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).brightness == Brightness.light ? Colors.black : AppTheme.primaryBlue,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildSizeOption(BuildContext context, WidgetRef ref, String label, double value, double current) {
    final isSelected = current == value;
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(settingsProvider.notifier).setTileScale(value),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryBlue : theme.colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.black : theme.colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGeoOption(BuildContext context, WidgetRef ref, String label, String value, String current) {
    final isSelected = current == value;
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(settingsProvider.notifier).setGeography(value),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.amberAccent : theme.colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.black : theme.colorScheme.onSurface,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
