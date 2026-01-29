import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/pin_service.dart';
import '../services/biometric_service.dart';
import '../services/secure_storage_service.dart';

/// Dialog pour vérifier le code PIN avant d'accéder aux données
class PinVerificationDialog extends StatefulWidget {
  final String title;
  final String message;
  final VoidCallback? onSuccess;

  const PinVerificationDialog({
    super.key,
    this.title = 'Vérification requise',
    this.message = 'Entrez votre code PIN pour accéder à ces données',
    this.onSuccess,
  });

  /// Affiche le dialog et retourne true si le PIN est correct
  static Future<bool> show(
    BuildContext context, {
    String? title,
    String? message,
    VoidCallback? onSuccess,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PinVerificationDialog(
        title: title ?? 'Vérification requise',
        message: message ?? 'Entrez votre code PIN',
        onSuccess: onSuccess,
      ),
    );

    return result ?? false;
  }

  @override
  State<PinVerificationDialog> createState() => _PinVerificationDialogState();
}

class _PinVerificationDialogState extends State<PinVerificationDialog> {
  final _pinController = TextEditingController();
  final _focusNode = FocusNode();
  bool _canCheckBiometrics = false;
  bool _isBiometricEnabled = false;
  bool _isVerifying = false;
  String? _errorMessage;
  int _remainingAttempts = 3;
  bool _isLocked = false;
  Duration? _lockDuration;

  @override
  void initState() {
    super.initState();
    _checkLockStatus();
    _loadRemainingAttempts();
    _checkBiometrics();
    // Auto-focus après un petit délai
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    final canBio = await BiometricService.canAuthenticate();
    final bioEnabled = await _isBiometricSetup();

    setState(() {
      _canCheckBiometrics = canBio;
      _isBiometricEnabled = bioEnabled;
    });

    // Only auto-trigger if biometric is both available AND enabled by user
    if (canBio && bioEnabled && !_isLocked) {
      _authenticateWithBiometrics();
    }
  }

  Future<bool> _isBiometricSetup() async {
    final value = await SecureStorageService.read('biometric_enabled');
    return value == 'true';
  }

  Future<void> _authenticateWithBiometrics() async {
    final success = await BiometricService.authenticate();
    if (success && mounted) {
      widget.onSuccess?.call();
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _checkLockStatus() async {
    final duration = await PinService.getRemainingLockDuration();
    if (duration != null) {
      setState(() {
        _isLocked = true;
        _lockDuration = duration;
      });

      // Démarrer un timer pour déverrouiller automatiquement
      Future.delayed(duration, () {
        if (mounted) {
          setState(() {
            _isLocked = false;
            _lockDuration = null;
            _errorMessage = null;
          });
          _loadRemainingAttempts();
        }
      });
    }
  }

  Future<void> _loadRemainingAttempts() async {
    final remaining = await PinService.getRemainingAttempts();
    setState(() => _remainingAttempts = remaining);
  }

  Future<void> _verifyPin() async {
    if (_pinController.text.isEmpty) {
      setState(() => _errorMessage = 'Veuillez entrer votre code PIN');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final isValid = await PinService.verifyPin(_pinController.text);

      if (isValid) {
        // Succès
        widget.onSuccess?.call();
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        // PIN incorrect
        await _loadRemainingAttempts();
        setState(() {
          _errorMessage =
              'Code PIN incorrect ($_remainingAttempts tentatives restantes)';
        });
        _pinController.clear();
      }
    } on PinLockedException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLocked = true;
      });
      await _checkLockStatus();
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur: $e';
      });
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.lock_outline, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Message
          Text(
            widget.message,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),

          // Champ PIN
          if (!_isLocked) ...[
            TextField(
              controller: _pinController,
              focusNode: _focusNode,
              enabled: !_isVerifying,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                hintText: '• • • •',
                counterText: '',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
              ),
              onSubmitted: (_) => _verifyPin(),
            ),
            const SizedBox(height: 12),

            // Tentatives restantes
            if (_remainingAttempts < 3)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber,
                        color: Colors.orange[900], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$_remainingAttempts tentative(s) restante(s)',
                        style: TextStyle(
                          color: Colors.orange[900],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],

          // Message de verrouillage
          if (_isLocked)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red),
              ),
              child: Column(
                children: [
                  const Icon(Icons.lock_clock, color: Colors.red, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Trop de tentatives',
                    style: TextStyle(
                      color: Colors.red[900],
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Verrouillé pendant ${_formatDuration(_lockDuration)}',
                    style: TextStyle(
                      color: Colors.red[700],
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

          // Message d'erreur
          if (_errorMessage != null && !_isLocked)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
      actions: [
        // Bouton Annuler
        TextButton(
          onPressed:
              _isVerifying ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        // Bouton Biométrie (only if available AND enabled)
        if (_canCheckBiometrics && _isBiometricEnabled && !_isLocked)
          IconButton(
            icon: const Icon(Icons.fingerprint, color: Colors.blue, size: 28),
            onPressed: _authenticateWithBiometrics,
            tooltip: 'Utiliser la biométrie',
          ),
        // Bouton Vérifier
        if (!_isLocked)
          ElevatedButton(
            onPressed: _isVerifying ? null : _verifyPin,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: _isVerifying
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Vérifier'),
          ),
      ],
    );
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '0s';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}min ${seconds}s';
  }
}
