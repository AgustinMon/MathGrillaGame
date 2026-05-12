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
      'challenge_your_mind': 'CHALLENGE YOUR MIND',
      'play_now': 'PLAY NOW',
      'game_of_the_day': 'GAME OF THE DAY',
      'my_grids': 'MY GRIDS',
      'explain_me': 'Explain Me',
      'editor': 'Editor',
      'no_saved_grids': 'No saved grids found.',
      'grid_label': 'Grid',
      'privacy_title': 'Privacy',
      'privacy_content': 'Please read our privacy policy carefully.',
      'reject': 'REJECT',
      'accept': 'ACCEPT',
      'select_tool_instruction': 'Select number / operator / = below and touch the grid to insert',
      'empty_grid_error': 'The grid is empty.',
      'grid_saved_success': 'Grid saved!',
      'calculator_title': 'Calculator',
      'no_grids_yet': 'No grids saved yet.',
      'date_label': 'Date',
      'custom_level_title': 'Custom Level',
      'solve_this_puzzle': 'Solve this math puzzle!',
      'settings_title': 'Settings',
      'profile_section': 'Profile',
      'player_name_label': 'Player Name',
      'player_name_hint': 'Your name',
      'stats_appearance': 'It will show in your stats',
      'appearance_section': 'Appearance',
      'dark_mode_label': 'Dark Mode',
      'number_size_section': 'Number Size',
      'small_label': 'Small',
      'normal_label': 'Normal',
      'large_label': 'Large',
      'accessibility_section': 'Accessibility',
      'scrollbar_left_label': 'Scrollbar on the left',
      'scrollbar_left_subtitle': 'Useful for left-handed users',
      'privacy_compliance_section': 'Privacy & Compliance',
      'consent_status_label': 'Consent Status',
      'pending_status': 'Pending',
      'accepted_status': 'Accepted',
      'rejected_status': 'Rejected',
      'reset_button': 'RESET',
      'debug_section': 'Debug (Dev Only)',
      'simulate_geo_label': 'Simulate Geography for Consent:',
      'jump_to_level_label': 'Jump to Level',
      'jump_to_level_hint': 'Level',
      'jumping_to_level_msg': 'Jumping to level {level}',
      'language_label': 'Language',
      'explain_me_title': 'Explain Me Mode',
      'next_button': 'Next',
      'understood_button': 'Understood!',
      'explanation_0': "Welcome to 'Explain Me' mode! Let's learn how to deduce the pieces.",
      'explanation_1': "Look at this row: '_ + 4 = 5'. What number added to 4 gives 5?",
      'explanation_2': "Exactly! It's 1. We place 1 here.",
      'explanation_3': "Now look at this column crossing the 1: '1 * _ = 3'.",
      'explanation_4': "If we have 1 and the result is 3, the number must be 3. 1 * 3 = 3.",
      'explanation_5': "When crossing equations, the numbers must work for both. That's the key!",
      'privacy_policy_title': 'Privacy Policy',
      'privacy_policy_button': 'Privacy Policy',
      'privacy_policy_url': 'https://aamforge.com/crucimath/privacy',
      'privacy_policy_content': '''Last Updated: May 11, 2026

This Privacy Policy describes how information is handled in our Mathematical Crossword application (the "App"). By using the App, you agree to the practices described herein.

1. Information We Collect
Local Statistical Data: The App collects information regarding your gameplay activity (playtime, chosen username, games won, progress). This data is stored exclusively on your device. We (the developer) do not have access to this data, it is not sent to external servers, and it is not processed remotely.

Third-Party Information (AdMob): We use Google AdMob to display advertisements. The Google Mobile Ads SDK automatically collects certain identifiers (such as Android Advertising ID and IP address) for ad delivery and fraud prevention purposes.

2. How We Use Information
Local data is used solely to enhance the user's gameplay experience. Data collected by AdMob is used to serve ads, personalize them (if consent is granted), and analyze advertising performance.

3. Service Providers
We do not share personal information with third parties, except for Google AdMob. You may review Google’s Privacy Policy for more details.

4. User Control and Rights
Revoking Consent: Users in the European Union (EU) and the USA can revoke or modify their advertising preferences at any time through the App's settings menu.

Data Deletion: Since data is stored locally, you can delete your information by uninstalling the App or clearing the app data in your device settings. The developer cannot remotely delete this data as we do not have access to it.

5. Children's Privacy
The App is intended for users aged 15 and older. We do not knowingly collect information from minors.

6. Contact Us
If you have any questions regarding this policy, you may contact us at:
Email: contactaamforge@gmail.com''',
      'trophies': 'Trophies',
      'your_profile': 'Your Profile',
      'medals': 'Medals',
      'error_no_valid_equations': 'Grid must have at least one valid equation.',
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
      'challenge_your_mind': 'DESAFÍA TU MENTE',
      'play_now': 'JUGAR AHORA',
      'game_of_the_day': 'JUEGO DEL DÍA',
      'my_grids': 'MIS GRILLAS',
      'explain_me': 'Explícame',
      'editor': 'Editor',
      'no_saved_grids': 'No tienes grillas guardadas.',
      'grid_label': 'Grilla',
      'privacy_title': 'Privacidad',
      'privacy_content': 'Lea atentamente nuestra política de privacidad.',
      'reject': 'RECHAZAR',
      'accept': 'ACEPTAR',
      'select_tool_instruction': 'Selecciona numero / operador / = abajo y toca la grilla para insertar',
      'empty_grid_error': 'La grilla está vacía.',
      'grid_saved_success': '¡Grilla guardada!',
      'calculator_title': 'Calculadora',
      'no_grids_yet': 'No has guardado grillas aún.',
      'date_label': 'Fecha',
      'custom_level_title': 'Nivel Personalizado',
      'solve_this_puzzle': '¡Resuelve este crucigrama matemático!',
      'settings_title': 'Configuración',
      'profile_section': 'Perfil',
      'player_name_label': 'Nombre de Jugador',
      'player_name_hint': 'Tu nombre',
      'stats_appearance': 'Se mostrará en tus estadísticas',
      'appearance_section': 'Apariencia',
      'dark_mode_label': 'Modo Oscuro',
      'number_size_section': 'Tamaño de Números',
      'small_label': 'Chico',
      'normal_label': 'Normal',
      'large_label': 'Grande',
      'accessibility_section': 'Accesibilidad',
      'scrollbar_left_label': 'Barra de scroll a la izquierda',
      'scrollbar_left_subtitle': 'Útil para usuarios zurdos',
      'privacy_compliance_section': 'Privacidad y Cumplimiento',
      'consent_status_label': 'Estado de Consentimiento',
      'pending_status': 'Pendiente',
      'accepted_status': 'Aceptado',
      'rejected_status': 'Rechazado',
      'reset_button': 'RESETEAR',
      'debug_section': 'Debug (Solo Desarrollo)',
      'simulate_geo_label': 'Simular Geografía para Consentimiento:',
      'jump_to_level_label': 'Saltar a Nivel',
      'jump_to_level_hint': 'Nivel',
      'jumping_to_level_msg': 'Saltando al nivel {level}',
      'language_label': 'Idioma',
      'explain_me_title': 'Modo Explícame',
      'next_button': 'Siguiente',
      'understood_button': '¡Entendido!',
      'explanation_0': "¡Bienvenido al modo 'Explícame'! Vamos a aprender cómo deducir las piezas.",
      'explanation_1': "Mira esta fila: '_ + 4 = 5'. ¿Qué número sumado a 4 da 5?",
      'explanation_2': "¡Exacto! Es el 1. Colocamos el 1 aquí.",
      'explanation_3': "Ahora mira esta columna que cruza el 1: '1 * _ = 3'.",
      'explanation_4': "Si tenemos 1 y el resultado es 3, el número debe ser 3. 1 * 3 = 3.",
      'explanation_5': "Al cruzar ecuaciones, los números deben servir para ambas. ¡Esa es la clave!",
      'privacy_policy_title': 'Política de Privacidad',
      'privacy_policy_button': 'Ver Política de Privacidad',
      'privacy_policy_url': 'https://aamforge.com/crucimath/privacy',
      'privacy_policy_content': '''Última actualización: 11 de mayo de 2026

Esta Política de Privacidad describe cómo se maneja la información en nuestra aplicación de Crucigrama Matemático (la "App"). Al utilizar la App, usted acepta las prácticas descritas aquí.

1. Información que recopilamos
Datos Estadísticos Locales: La App recopila información sobre su actividad de juego (tiempo de juego, nombre de usuario elegido, partidas ganadas, progreso). Estos datos se almacenan exclusivamente de forma local en su dispositivo. Nosotros (el desarrollador) no tenemos acceso a estos datos, no se envían a servidores externos ni se procesan de forma remota.

Información de Terceros (AdMob): Utilizamos Google AdMob para mostrar publicidad. El SDK de Google Mobile Ads recolecta automáticamente ciertos identificadores (como el ID de publicidad de Android e IP) para el funcionamiento de los anuncios y la prevención de fraudes.

2. Uso de la Información
Los datos locales se utilizan únicamente para la experiencia de juego del usuario. Los datos recolectados por AdMob se utilizan para servir anuncios, personalizarlos (si se otorga permiso) y analizar el rendimiento publicitario.

3. Proveedores de Servicios
No compartimos información personal con terceros, salvo con Google AdMob. Puede consultar la Política de Privacidad de Google para más detalles.

4. Control del Usuario y Derechos
Revocación de Consentimiento: Los usuarios en la Unión Europea (UE) y EE. UU. pueden revocar o cambiar sus preferencias de publicidad en cualquier momento desde el menú de configuración de la App.

Eliminación de Datos: Al ser almacenamiento local, usted puede borrar sus datos desinstalando la App o borrando el almacenamiento de la misma en los ajustes de su teléfono. El desarrollador no puede borrar estos datos remotamente ya que no tiene acceso a ellos.

5. Privacidad Infantil
La App está dirigida a personas mayores de 15 años. No recopilamos intencionadamente información de menores de edad.

6. Contacto
Si tiene preguntas sobre esta política, puede contactarnos en:
Email: contactaamforge@gmail.com''',
      'trophies': 'Trofeos',
      'your_profile': 'Tu Perfil',
      'medals': 'Medallas',
      'error_no_valid_equations': 'La grilla debe tener al menos una ecuación válida.',
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
