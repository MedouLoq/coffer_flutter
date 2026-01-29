import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../services/pin_service.dart';
import '../services/biometric_service.dart';
import '../services/secure_storage_service.dart';

class PinSetupView extends StatefulWidget {
  const PinSetupView({super.key});

  @override
  State<PinSetupView> createState() => _PinSetupViewState();
}

class _PinSetupViewState extends State<PinSetupView> {
  bool _isPinEnabled = false;
  bool _isBiometricAvailable = false;
  bool _isBiometricEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    final pinEnabled = await PinService.isPinEnabled();
    final bioAvailable = await BiometricService.canAuthenticate();
    final bioEnabled = await _isBiometricSetup();

    setState(() {
      _isPinEnabled = pinEnabled;
      _isBiometricAvailable = bioAvailable;
      _isBiometricEnabled = bioEnabled;
      _isLoading = false;
    });
  }

  Future<bool> _isBiometricSetup() async {
    final value = await SecureStorageService.read('biometric_enabled');
    return value == 'true';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sécurité'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildPinSection(),
                  const SizedBox(height: 16),
                  if (_isBiometricAvailable) _buildBiometricSection(),
                  const SizedBox(height: 24),
                  _buildInfoCard(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.security,
              size: 60,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Sécurité avancée',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Protégez vos données sensibles',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          SwitchListTile(
            value: _isPinEnabled,
            onChanged: (value) {
              if (value) {
                _setupPin();
              } else {
                _disablePin();
              }
            },
            title: const Text(
              'Code PIN',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              _isPinEnabled
                  ? 'PIN activé pour la lecture des documents'
                  : 'Configurer un code PIN de 4-6 chiffres',
              style: const TextStyle(fontSize: 13),
            ),
            secondary: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.pin,
                color: Colors.purple,
                size: 28,
              ),
            ),
            activeColor: Colors.purple,
          ),
          if (_isPinEnabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.edit, color: Colors.blue),
                    title: const Text('Changer le PIN'),
                    subtitle: const Text('Modifier votre code PIN'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _changePin,
                  ),
                  ListTile(
                    leading: const Icon(Icons.info_outline, color: Colors.grey),
                    title: const Text('Statistiques'),
                    subtitle: const Text('Voir les tentatives'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _showPinStats,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBiometricSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SwitchListTile(
        value: _isBiometricEnabled,
        onChanged: (value) {
          if (value) {
            _enableBiometric();
          } else {
            _disableBiometric();
          }
        },
        title: const Text(
          'Biométrie',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          _isBiometricEnabled
              ? 'Empreinte digitale / Face ID activé'
              : 'Utiliser l\'empreinte ou Face ID',
          style: const TextStyle(fontSize: 13),
        ),
        secondary: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.fingerprint,
            color: Colors.green,
            size: 28,
          ),
        ),
        activeColor: Colors.green,
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700),
              const SizedBox(width: 12),
              Text(
                'À propos de la sécurité',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoItem(
            '🔒',
            'Code PIN',
            'Protège l\'accès en lecture à vos documents sensibles',
          ),
          const SizedBox(height: 8),
          if (_isBiometricAvailable)
            _buildInfoItem(
              '👆',
              'Biométrie',
              'Déverrouillage rapide par empreinte ou Face ID',
            ),
          const SizedBox(height: 8),
          _buildInfoItem(
            '🔐',
            'Chiffrement',
            'Vos données restent toujours chiffrées de bout en bout',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String emoji, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade900,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _setupPin() async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _PinSetupDialog(),
    );

    if (result != null) {
      final success = await PinService.setupPin(result);
      if (success) {
        setState(() => _isPinEnabled = true);
        Get.snackbar(
          '✅ PIN configuré',
          'Votre code PIN a été activé avec succès',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
      }
    }
  }

  Future<void> _disablePin() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Désactiver le PIN'),
        content: const Text('Voulez-vous vraiment désactiver le code PIN ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Désactiver'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await PinService.disablePin();
      setState(() => _isPinEnabled = false);
      Get.snackbar(
        '🔓 PIN désactivé',
        'Le code PIN a été supprimé',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  Future<void> _changePin() async {
    final oldPin = await showDialog<String>(
      context: context,
      builder: (context) => const _PinVerifyDialog(
        title: 'Ancien PIN',
        message: 'Entrez votre code PIN actuel',
      ),
    );

    if (oldPin == null) return;

    // Verify old PIN
    try {
      final isValid = await PinService.verifyPin(oldPin);
      if (!isValid) {
        Get.snackbar(
          '❌ Erreur',
          'Code PIN incorrect',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }
    } catch (e) {
      Get.snackbar(
        '❌ Erreur',
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    final newPin = await showDialog<String>(
      context: context,
      builder: (context) => const _PinSetupDialog(),
    );

    if (newPin != null) {
      await PinService.setupPin(newPin);
      Get.snackbar(
        '✅ PIN modifié',
        'Votre nouveau code PIN a été enregistré',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  Future<void> _showPinStats() async {
    final stats = await PinService.getStats();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Statistiques PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatRow('État', stats['enabled'] ? 'Activé' : 'Désactivé'),
            _buildStatRow('Verrouillé', stats['locked'] ? 'Oui' : 'Non'),
            _buildStatRow('Tentatives', '${stats['attempts']}/3'),
            _buildStatRow(
                'Tentatives restantes', '${stats['remaining_attempts']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _enableBiometric() async {
    final success = await BiometricService.authenticate();

    if (success) {
      await SecureStorageService.write('biometric_enabled', 'true');
      setState(() => _isBiometricEnabled = true);
      Get.snackbar(
        '✅ Biométrie activée',
        'Vous pouvez maintenant utiliser votre empreinte ou Face ID',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } else {
      Get.snackbar(
        '❌ Échec',
        'Authentification biométrique échouée',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  Future<void> _disableBiometric() async {
    await SecureStorageService.deleteKey('biometric_enabled');
    setState(() => _isBiometricEnabled = false);
    Get.snackbar(
      '🔓 Biométrie désactivée',
      'L\'authentification biométrique a été supprimée',
      backgroundColor: Colors.orange,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }
}

// Dialog for setting up new PIN
class _PinSetupDialog extends StatefulWidget {
  const _PinSetupDialog();

  @override
  State<_PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<_PinSetupDialog> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  final _pinFocus = FocusNode();
  final _confirmFocus = FocusNode();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _pinFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    _pinFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  void _validateAndSubmit() {
    if (_pinController.text.length < 4) {
      setState(
          () => _errorMessage = 'Le PIN doit contenir au moins 4 chiffres');
      return;
    }

    if (_pinController.text != _confirmController.text) {
      setState(() => _errorMessage = 'Les codes ne correspondent pas');
      return;
    }

    Navigator.pop(context, _pinController.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.pin, color: Colors.purple),
          ),
          const SizedBox(width: 12),
          const Text('Nouveau code PIN'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Créez un code PIN de 4 à 6 chiffres',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _pinController,
            focusNode: _pinFocus,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                borderSide: const BorderSide(color: Colors.purple, width: 2),
              ),
            ),
            onSubmitted: (_) => _confirmFocus.requestFocus(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmController,
            focusNode: _confirmFocus,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                borderSide: const BorderSide(color: Colors.purple, width: 2),
              ),
            ),
            onSubmitted: (_) => _validateAndSubmit(),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _validateAndSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Confirmer'),
        ),
      ],
    );
  }
}

// Dialog for verifying existing PIN
class _PinVerifyDialog extends StatefulWidget {
  final String title;
  final String message;

  const _PinVerifyDialog({
    required this.title,
    required this.message,
  });

  @override
  State<_PinVerifyDialog> createState() => _PinVerifyDialogState();
}

class _PinVerifyDialogState extends State<_PinVerifyDialog> {
  final _pinController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.message,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _pinController,
            focusNode: _focusNode,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
            onSubmitted: (_) => Navigator.pop(context, _pinController.text),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _pinController.text),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Vérifier'),
        ),
      ],
    );
  }
}
