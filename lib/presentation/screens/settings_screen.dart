import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/math_settings.dart';
import '../../core/theme/app_theme.dart';
import '../providers/game_provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          _buildSection('Tema'),
          SwitchListTile(
            title: const Text('Modo Oscuro'),
            value: settings.themeMode == ThemeMode.dark,
            activeThumbColor: AppTheme.primaryBlue,
            onChanged: (val) => notifier.toggleTheme(),
          ),
          const Divider(),
          _buildSection('Símbolo de División'),
          _buildSymbolOption(ref, 'Slash (/)', DivisionSymbol.slash),
          _buildSymbolOption(ref, 'Obelus (÷)', DivisionSymbol.obelus),
          _buildSymbolOption(ref, 'Colon (:)', DivisionSymbol.colon),
          const Divider(height: 40),
          _buildSection('Ayuda y Tutoriales'),
          ListTile(
            leading: const Icon(Icons.help_outline, color: AppTheme.primaryBlue),
            title: const Text('Restablecer Tutoriales'),
            subtitle: const Text('Volver a mostrar los carteles de ayuda al iniciar el Nivel 1'),
            onTap: () {
              ref.read(gameProvider.notifier).resetTutorials();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tutoriales restablecidos'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const Divider(height: 40),
          _buildSection('Debug (Solo Desarrollo)'),
          ListTile(
            title: const Text('Saltar a Nivel'),
            subtitle: const Text(
              'Introduce un número para probar niveles avanzados',
            ),
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

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryBlue,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildSymbolOption(WidgetRef ref, String title, DivisionSymbol symbol) {
    // Nota: El símbolo de división actualmente no está persistido en settingsProvider.
    // Lo dejamos como placeholder o lo implementamos si es necesario.
    return RadioListTile<DivisionSymbol>(
      title: Text(title),
      value: symbol,
      groupValue: DivisionSymbol.obelus, // Valor por defecto
      activeColor: AppTheme.primaryBlue,
      onChanged: (val) {
        // Implementar cambio si se añade al provider
      },
    );
  }
}
