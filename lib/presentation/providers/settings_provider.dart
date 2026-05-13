import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../core/utils/translations.dart';

class SettingsState {
  final ThemeMode themeMode;
  final Locale locale;
  final double tileScale; // 0.8 para chico, 1.2 para grande
  final String geography; // 'global', 'ue', 'usa'
  final bool? consentAccepted; // null = pendiente, true = aceptado, false = rechazado
  final bool scrollbarOnLeft;
  final String playerName;

  SettingsState({
    required this.themeMode,
    required this.locale,
    this.tileScale = 1.0,
    this.geography = 'global',
    this.consentAccepted,
    this.scrollbarOnLeft = false,
    this.playerName = '',
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    double? tileScale,
    String? geography,
    bool? consentAccepted,
    bool? scrollbarOnLeft,
    String? playerName,
    bool clearConsent = false,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      tileScale: tileScale ?? this.tileScale,
      geography: geography ?? this.geography,
      consentAccepted: clearConsent ? null : (consentAccepted ?? this.consentAccepted),
      scrollbarOnLeft: scrollbarOnLeft ?? this.scrollbarOnLeft,
      playerName: playerName ?? this.playerName,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(SettingsState(
    themeMode: ThemeMode.dark,
    locale: PlatformDispatcher.instance.locale.languageCode == 'es' 
        ? const Locale('es') 
        : const Locale('en'),
  )) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('playerName') ?? '';
    final geo = prefs.getString('geography') ?? 'global';
    final hasConsent = prefs.containsKey('consentAccepted');
    final consent = hasConsent ? prefs.getBool('consentAccepted') : null;
    
    SettingsState newState = state;
    if (name.isNotEmpty) newState = newState.copyWith(playerName: name);
    if (geo != 'global') newState = newState.copyWith(geography: geo);
    if (hasConsent) newState = newState.copyWith(consentAccepted: consent);
    
    if (newState != state) {
      state = newState;
    }
  }

  void toggleTheme() {
    state = state.copyWith(
      themeMode: state.themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }

  void setTileScale(double scale) {
    state = state.copyWith(tileScale: scale);
  }

  void setGeography(String geo) async {
    state = state.copyWith(geography: geo);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('geography', geo);
  }

  void setConsent(bool accepted) async {
    state = state.copyWith(consentAccepted: accepted);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('consentAccepted', accepted);
  }

  void resetConsent() async {
    state = state.copyWith(clearConsent: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('consentAccepted');
    // Reiniciar también el SDK de UMP
    ConsentInformation.instance.reset();
  }

  void setScrollbarOnLeft(bool value) {
    state = state.copyWith(scrollbarOnLeft: value);
  }

  void setPlayerName(String name) async {
    state = state.copyWith(playerName: name);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('playerName', name);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});

final translationsProvider = Provider<Translations>((ref) {
  // Ignoramos el locale de settings y usamos directamente el del sistema
  final systemLocale = PlatformDispatcher.instance.locale;
  return Translations(systemLocale);
});
