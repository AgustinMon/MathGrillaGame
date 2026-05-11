import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class ConsentManager {
  static Future<void> gatherConsent(String geography, String testDeviceId) async {
    if (kIsWeb) return;

    ConsentDebugSettings? debugSettings;
    
    if (kDebugMode) {
      DebugGeography debugGeography = DebugGeography.debugGeographyDisabled;
      if (geography == 'ue') {
        debugGeography = DebugGeography.debugGeographyEea;
      } else if (geography == 'usa') {
        // En UMP, no hay debugGeography específico para CCPA/USA, pero EEA sirve para probar los diálogos.
        debugGeography = DebugGeography.debugGeographyDisabled; 
        // Nota: Las opciones de CCPA no suelen tener un simulador geográfico tan estricto en UMP como el GDPR,
        // pero podemos probar el flujo de todas formas.
      }
      
      debugSettings = ConsentDebugSettings(
        debugGeography: debugGeography,
        testIdentifiers: [testDeviceId],
      );
    }

    ConsentRequestParameters params = ConsentRequestParameters(
      consentDebugSettings: debugSettings,
    );

    // Solicitar actualización de información de consentimiento
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        // La información de consentimiento se actualizó correctamente.
        if (await ConsentInformation.instance.isConsentFormAvailable()) {
          _loadForm();
        } else {
          // Si no hay formulario disponible, inicializar anuncios si corresponde
          _initializeAds();
        }
      },
      (FormError error) {
        // Falló la actualización
        debugPrint('Consent gathering failed: ${error.message}');
        // Inicializamos igual (con el estado de consentimiento anterior o por defecto)
        _initializeAds();
      },
    );
  }

  static void _loadForm() {
    ConsentForm.loadConsentForm(
      (ConsentForm consentForm) async {
        var status = await ConsentInformation.instance.getConsentStatus();
        if (status == ConsentStatus.required) {
          consentForm.show(
            (FormError? formError) {
              if (formError != null) {
                debugPrint('Error showing consent form: ${formError.message}');
              }
              _loadForm(); // Intentar cargar de nuevo por si cambió el estado
            },
          );
        } else {
          // Ya se obtuvo el consentimiento o no es requerido
          _initializeAds();
        }
      },
      (FormError formError) {
        // Falló la carga del formulario
        debugPrint('Consent form load failed: ${formError.message}');
        _initializeAds();
      },
    );
  }

  static void _initializeAds() {
    MobileAds.instance.initialize();
  }

  /// Mostrar formulario de privacidad desde la configuración
  static Future<void> showPrivacyOptionsForm() async {
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        if (await ConsentInformation.instance.isConsentFormAvailable()) {
          ConsentForm.loadConsentForm((ConsentForm consentForm) {
            consentForm.show((FormError? formError) {
              // Manejo post-formulario si es necesario
            });
          }, (FormError formError) {
            debugPrint('Privacy Options form load failed: ${formError.message}');
          });
        }
      },
      (FormError formError) {
        debugPrint('Consent gathering failed: ${formError.message}');
      },
    );
  }
}
