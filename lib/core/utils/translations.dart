import 'package:flutter/material.dart';

class Translations {
  final Locale locale;
  Translations(this.locale);

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_title': 'CRUCIMATH',
      'hard_mode': 'HARD',
      'medium_mode': 'MEDIUM',
      'easy_mode': 'EASY',
      'fusion_machine': 'FUSION MACHINE',
      'fusion_button': 'FUSE',
      'undo_button': 'UNDO',
      'numbers_label': 'NUMBERS',
      'ingredients_label': 'INGREDIENTS (FOR MACHINE)',
      'lives_label': 'LIVES',
      'level_label': 'LVL',
      'time_label': 'TIME',
      'hints_label': 'HINTS',
      'fusion_success': 'FUSION SUCCESS! Result: {res}. Check your list!',
      'fusion_undo': 'Fusion undone.',
      'only_pink': 'You can only put ingredients (pink) in the machine',
      'negative_error': 'Machine does not accept negative results!',
      'game_over': 'GAME OVER',
      'victory': 'VICTORY!',
      'next_level': 'NEXT LEVEL',
      'try_again': 'TRY AGAIN',
    },
    'es': {
      'app_title': 'CRUCIMATH',
      'hard_mode': 'DIFÍCIL',
      'medium_mode': 'MEDIO',
      'easy_mode': 'FÁCIL',
      'fusion_machine': 'MÁQUINA DE FUSIÓN',
      'fusion_button': 'FUSIÓN',
      'undo_button': 'DESHACER',
      'numbers_label': 'NÚMEROS',
      'ingredients_label': 'INGREDIENTES (PARA MÁQUINA)',
      'lives_label': 'VIDAS',
      'level_label': 'LVL',
      'time_label': 'TIEMPO',
      'hints_label': 'PISTAS',
      'fusion_success': '¡FUSIÓN EXITOSA! Resultado: {res}. ¡Mira tu lista!',
      'fusion_undo': 'Fusión deshecha.',
      'only_pink': 'Solo puedes poner ingredientes (rosas) en la máquina',
      'negative_error': '¡La máquina no acepta resultados negativos!',
      'game_over': 'FIN DEL JUEGO',
      'victory': '¡VICTORIA!',
      'next_level': 'SIGUIENTE NIVEL',
      'try_again': 'REINTENTAR',
    },
  };

  String text(String key) {
    final lang = locale.languageCode == 'es' ? 'es' : 'en';
    return _localizedValues[lang]?[key] ?? key;
  }

  String translate(String key, {Map<String, String>? args}) {
    String t = text(key);
    if (args != null) {
      args.forEach((k, v) {
        t = t.replaceAll('{$k}', v);
      });
    }
    return t;
  }
}
