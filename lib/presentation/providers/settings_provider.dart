import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    if (name.isNotEmpty) {
      state = state.copyWith(playerName: name);
    }
  }

  void toggleTheme() {
    state = state.copyWith(
      themeMode: state.themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }

  void setLocale(Locale locale) {
    state = state.copyWith(locale: locale);
  }

  void setTileScale(double scale) {
    state = state.copyWith(tileScale: scale);
  }

  void setGeography(String geo) {
    state = state.copyWith(geography: geo);
  }

  void setConsent(bool accepted) {
    state = state.copyWith(consentAccepted: accepted);
  }

  void resetConsent() {
    state = state.copyWith(clearConsent: true);
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
  final settings = ref.watch(settingsProvider);
  return Translations(settings.locale);
});
