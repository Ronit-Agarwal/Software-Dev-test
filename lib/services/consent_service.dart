import 'package:flutter/foundation.dart';
import 'package:signsync/services/storage_service.dart';

/// Service for managing user consent and privacy policy acceptance.
class ConsentService with ChangeNotifier {
  final StorageService _storageService;
  bool _hasConsented = false;
  
  static const String _consentKey = 'user_consent_accepted';

  ConsentService(this._storageService);

  bool get hasConsented => _hasConsented;

  /// Initializes the consent service.
  Future<void> initialize() async {
    final consent = await _storageService.getPreference(_consentKey);
    _hasConsented = consent == 'true';
    notifyListeners();
  }

  /// Sets the user consent status.
  Future<void> setConsent(bool consented) async {
    _hasConsented = consented;
    await _storageService.setPreference(_consentKey, consented.toString());
    await _storageService.logEvent('user_consent_updated', details: 'Consented: $consented');
    notifyListeners();
  }
}
