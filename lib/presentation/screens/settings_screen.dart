import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/math_settings.dart';
import '../../core/theme/app_theme.dart';
import '../providers/game_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  DivisionSymbol _selectedSymbol = DivisionSymbol.obelus;
  bool _isDarkMode = true;

  @override
  Widget build(BuildContext context) {
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
            value: _isDarkMode,
            activeColor: AppTheme.primaryBlue,
            onChanged: (val) => setState(() => _isDarkMode = val),
          ),
          const Divider(),
          _buildSection('Símbolo de División'),
          _buildSymbolOption('Slash (/)', DivisionSymbol.slash),
          _buildSymbolOption('Obelus (÷)', DivisionSymbol.obelus),
          _buildSymbolOption('Colon (:)', DivisionSymbol.colon),
          const Divider(height: 40),
          _buildSection('Debug (Solo Desarrollo)'),
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

  Widget _buildSymbolOption(String title, DivisionSymbol symbol) {
    return RadioListTile<DivisionSymbol>(
      title: Text(title),
      value: symbol,
      groupValue: _selectedSymbol,
      activeColor: AppTheme.primaryBlue,
      onChanged: (val) {
        if (val != null) setState(() => _selectedSymbol = val);
      },
    );
  }
}
