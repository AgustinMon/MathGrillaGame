import 'package:flutter/material.dart';
import '../../domain/entities/math_settings.dart';
import '../../core/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
