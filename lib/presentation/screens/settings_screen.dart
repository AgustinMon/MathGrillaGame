import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/math_settings.dart';
import '../../core/theme/app_theme.dart';
import '../providers/game_provider.dart';
import '../providers/settings_provider.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSection(context, 'Perfil'),
          ListTile(
            title: const Text('Nombre de Jugador'),
            subtitle: const Text('Se mostrará en tus estadísticas'),
            trailing: SizedBox(
              width: 150,
              child: TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Tu nombre',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                ),
                onChanged: (val) => notifier.setPlayerName(val),
              ),
            ),
          ),
          
          _buildSection(context, 'Apariencia'),
          SwitchListTile(
            title: const Text('Modo Oscuro'),
            value: settings.themeMode == ThemeMode.dark,
            activeThumbColor: AppTheme.primaryBlue,
            onChanged: (val) => notifier.toggleTheme(),
          ),
          
          
          _buildSection(context, 'Tamaño de Números'),
          Row(
            children: [
              _buildSizeOption(context, ref, 'Chico', 0.8, settings.tileScale),
              _buildSizeOption(context, ref, 'Normal', 1.0, settings.tileScale),
              _buildSizeOption(context, ref, 'Grande', 1.2, settings.tileScale),
            ],
          ),

          _buildSection(context, 'Accesibilidad'),
          SwitchListTile(
            title: const Text('Barra de scroll a la izquierda'),
            subtitle: const Text('Útil para usuarios zurdos'),
            value: settings.scrollbarOnLeft,
            activeColor: AppTheme.primaryBlue,
            onChanged: (val) => notifier.setScrollbarOnLeft(val),
          ),

          const Divider(height: 40),
          _buildSection(context, 'Privacidad y Cumplimiento'),
          ListTile(
            title: const Text('Estado de Consentimiento'),
            subtitle: Text(
              settings.consentAccepted == null 
                ? 'Pendiente' 
                : (settings.consentAccepted! ? 'Aceptado' : 'Rechazado')
            ),
            trailing: TextButton(
              onPressed: () => notifier.resetConsent(),
              child: const Text('RESETEAR'),
            ),
          ),
          
          const Divider(height: 40),
          _buildSection(context, 'Debug (Solo Desarrollo)'),
          
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Simular Geografía para Consentimiento:', style: TextStyle(fontSize: 12)),
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
            title: const Text('Saltar a Nivel'),
            subtitle: const Text('Introduce un número para probar niveles avanzados'),
            trailing: SizedBox(
              width: 80,
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'Nivel'),
                onSubmitted: (val) {
                  final level = int.tryParse(val);
                  if (level != null && level > 0) {
                    ref.read(gameProvider.notifier).startNewLevel(level);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Saltando al nivel $level')),
                    );
                  }
                },
              ),
            ),
          ),
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
