import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/vault_controller.dart';

class SetupPasswordView extends StatefulWidget {
  const SetupPasswordView({super.key});

  @override
  State<SetupPasswordView> createState() => _SetupPasswordViewState();
}

class _SetupPasswordViewState extends State<SetupPasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  // Indicateurs de force du mot de passe
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _checkPasswordStrength(String password) {
    setState(() {
      _hasMinLength = password.length >= 12;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  bool get _isPasswordStrong =>
      _hasMinLength &&
      _hasUppercase &&
      _hasLowercase &&
      _hasNumber &&
      _hasSpecialChar;

  Future<void> _createVault() async {
    if (_isLoading) return;

    if (!_formKey.currentState!.validate()) return;

    if (!_isPasswordStrong) {
      Get.snackbar(
        'Mot de passe faible',
        'Utilisez un mot de passe plus robuste',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final vaultController = Get.find<VaultController>();

      // ✅ CORRECTION : Récupérer les arguments SANS VALEURS PAR DÉFAUT
      final args = Get.arguments as Map<String, dynamic>?;
      
      if (args == null || args['userId'] == null || args['email'] == null) {
        Get.snackbar(
          '❌ Erreur',
          'Informations utilisateur manquantes. Veuillez vous reconnecter.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        Get.offAllNamed('/login');
        return;
      }

      final userId = args['userId'].toString();
      final email = args['email'].toString();

      debugPrint('➡️ createVault() start userId=$userId email=$email');

      final success = await vaultController
          .createVault(
            userId: userId,
            email: email,
            masterPassword: _passwordController.text,
          )
          .timeout(const Duration(seconds: 20));

      debugPrint('✅ createVault() returned: $success');

      if (success) {
        Get.snackbar(
          '✅ Vault créé',
          'Votre coffre-fort est prêt',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        Get.offAllNamed('/main');
      } else {
        Get.snackbar(
          '❌ Erreur',
          'Impossible de créer le vault',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      debugPrint('❌ createVault() error: $e');
      Get.snackbar(
        '❌ Erreur',
        'Création du vault échouée: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer votre mot de passe maître'),
        backgroundColor: Color(0xFFE3F2FD), // Bleu ciel clair
        foregroundColor: Color(0xFF1976D2), // Bleu plus foncé pour le texte
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF5FBFF), // Très clair
              Color(0xFFE3F2FD), // Bleu ciel
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Color(0xFFBBDEFB), // Bleu ciel moyen
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF90CAF9).withOpacity(0.5),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.lock_outline,
                    size: 50,
                    color: Color(0xFF1565C0), // Bleu foncé
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'Choisissez un mot de passe maître',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565C0), // Bleu foncé
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFFE1F5FE), // Bleu ciel très clair
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Color(0xFFB3E5FC), // Bordure bleu ciel
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'Ce mot de passe chiffrera toutes vos données. '
                    '⚠️ Il ne peut PAS être récupéré si vous l\'oubliez.',
                    style: TextStyle(
                      color: Color(0xFF0288D1), // Bleu moyen
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 32),

                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  onChanged: _checkPasswordStrength,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe maître',
                    hintText: 'Min. 12 caractères',
                    prefixIcon: Icon(Icons.vpn_key, color: Color(0xFF2196F3)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Color(0xFF2196F3),
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFFBBDEFB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFFBBDEFB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFF2196F3), width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Requis';
                    if (!_isPasswordStrong) return 'Mot de passe trop faible';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color(0xFFE8F4FD), // Bleu ciel clair
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Color(0xFFBBDEFB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Critères de sécurité :',
                        style: TextStyle(
                          color: Color(0xFF1976D2),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 8),
                      _buildStrengthIndicator('12+ caractères', _hasMinLength),
                      _buildStrengthIndicator('Majuscule (A-Z)', _hasUppercase),
                      _buildStrengthIndicator('Minuscule (a-z)', _hasLowercase),
                      _buildStrengthIndicator('Chiffre (0-9)', _hasNumber),
                      _buildStrengthIndicator('Caractère spécial (!@#...)', _hasSpecialChar),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                TextFormField(
                  controller: _confirmController,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirmer le mot de passe',
                    labelStyle: TextStyle(color: Color(0xFF1976D2)),
                    prefixIcon: Icon(Icons.lock_outline, color: Color(0xFF2196F3)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Color(0xFF2196F3),
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFFBBDEFB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFFBBDEFB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFF2196F3), width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'Les mots de passe ne correspondent pas';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF64B5F6).withOpacity(0.3),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createVault,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      backgroundColor: Color(0xFF42A5F5), // Bleu ciel vif
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Créer mon coffre-fort',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color(0xFFE1F5FE), // Bleu ciel clair
                    border: Border.all(color: Color(0xFF29B6F6)), // Bleu ciel
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Color(0xFF0288D1)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Notez ce mot de passe dans un endroit sûr. '
                          'Nous ne pouvons PAS le réinitialiser.',
                          style: TextStyle(
                            color: Color(0xFF01579B), // Bleu foncé
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStrengthIndicator(String label, bool isValid) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isValid ? Color(0xFF4FC3F7) : Color(0xFFE0F2F1),
              shape: BoxShape.circle,
              border: Border.all(
                color: isValid ? Color(0xFF0288D1) : Color(0xFFB0BEC5),
              ),
            ),
            child: Icon(
              isValid ? Icons.check : Icons.close,
              color: isValid ? Colors.white : Color(0xFF78909C),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isValid ? Color(0xFF0277BD) : Color(0xFF607D8B),
                fontWeight: isValid ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}