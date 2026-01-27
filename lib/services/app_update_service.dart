import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

/// Service pro správu aktualizací aplikace z Google Play Store
class AppUpdateService {
  static bool _isCheckingForUpdate = false;
  
  /// Zkontroluje dostupnost aktualizace a zobrazí dialog pokud je k dispozici
  /// 
  /// [context] - BuildContext pro zobrazení dialogu
  /// [forceImmediate] - pokud true, vynutí okamžitou aktualizaci (vhodné pro kritické verze)
  static Future<void> checkForUpdate(
    BuildContext context, {
    bool forceImmediate = false,
  }) async {
    // In-app update funguje pouze na Android
    if (!Platform.isAndroid) {
      return;
    }
    
    // Zabránění duplicitním kontrolám
    if (_isCheckingForUpdate) {
      return;
    }
    
    _isCheckingForUpdate = true;
    
    try {
      // Zkontroluj dostupnost aktualizace
      final AppUpdateInfo updateInfo = await InAppUpdate.checkForUpdate();
      
      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        if (forceImmediate || updateInfo.immediateUpdateAllowed) {
          // Okamžitá aktualizace - uživatel musí aktualizovat hned
          await _performImmediateUpdate(context, updateInfo);
        } else if (updateInfo.flexibleUpdateAllowed) {
          // Flexibilní aktualizace - uživatel může pokračovat v používání aplikace
          await _showFlexibleUpdateDialog(context);
        }
      }
    } catch (e) {
      final errorStr = e.toString();
      if (!errorStr.contains('ERROR_APP_NOT_OWNED')) {
        debugPrint('Chyba při kontrole aktualizace: $e');
      }
    } finally {
      _isCheckingForUpdate = false;
    }
  }
  
  /// Provede okamžitou aktualizaci (blocking)
  static Future<void> _performImmediateUpdate(
    BuildContext context,
    AppUpdateInfo updateInfo,
  ) async {
    try {
      await InAppUpdate.performImmediateUpdate();
    } catch (e) {
      debugPrint('Chyba při okamžité aktualizaci: $e');
      if (context.mounted) {
        _showUpdateErrorDialog(context);
      }
    }
  }
  
  /// Zobrazí dialog s možností flexibilní aktualizace
  static Future<void> _showFlexibleUpdateDialog(BuildContext context) async {
    if (!context.mounted) return;
    
    final bool? shouldUpdate = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Aktualizace k dispozici'),
          content: const Text(
            'Je k dispozici nová verze aplikace Strakatá turistika. '
            'Doporučujeme aktualizovat pro získání nových funkcí a vylepšení.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Později'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Aktualizovat'),
            ),
          ],
        );
      },
    );
    
    if (shouldUpdate == true) {
      await _startFlexibleUpdate(context);
    }
  }
  
  /// Spustí flexibilní aktualizaci na pozadí
  static Future<void> _startFlexibleUpdate(BuildContext context) async {
    try {
      await InAppUpdate.startFlexibleUpdate();
      
      // Čekání na dokončení stahování
      await InAppUpdate.completeFlexibleUpdate();
      
      if (context.mounted) {
        _showUpdateCompletedDialog(context);
      }
    } catch (e) {
      debugPrint('Chyba při flexibilní aktualizaci: $e');
      if (context.mounted) {
        _showUpdateErrorDialog(context);
      }
    }
  }
  
  /// Zobrazí dialog po úspěšném dokončení aktualizace
  static void _showUpdateCompletedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Aktualizace dokončena'),
          content: const Text(
            'Aplikace byla úspěšně aktualizována. '
            'Pro aplikování změn bude aplikace restartována.',
          ),
          actions: <Widget>[
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Restart aplikace se provede automaticky
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
  
  /// Zobrazí dialog v případě chyby při aktualizaci
  static void _showUpdateErrorDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Chyba aktualizace'),
          content: const Text(
            'Při aktualizaci aplikace došlo k chybě. '
            'Zkuste to prosím později nebo aktualizujte manuálně z Google Play Store.',
          ),
          actions: <Widget>[
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
  
  /// Provede tichou kontrolu aktualizace (bez dialogu, pouze v pozadí)
  /// Vhodné pro kontrolu při startu aplikace
  static Future<bool> silentCheckForUpdate() async {
    if (!Platform.isAndroid) {
      return false;
    }
    
    try {
      final AppUpdateInfo updateInfo = await InAppUpdate.checkForUpdate();
      return updateInfo.updateAvailability == UpdateAvailability.updateAvailable;
    } catch (e) {
      final errorStr = e.toString();
      if (!errorStr.contains('ERROR_APP_NOT_OWNED')) {
        debugPrint('Chyba při tiché kontrole aktualizace: $e');
      }
      return false;
    }
  }
}

