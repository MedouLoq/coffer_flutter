import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/vault_controller.dart';

class UnlockVaultView extends StatefulWidget {
  const UnlockVaultView({super.key});

  @override
  State<UnlockVaultView> createState() => _UnlockVaultViewState();
}

class _UnlockVaultViewState extends State<UnlockVaultView> {
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  int _attemptCount = 0;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _unlockVault() async {
    if (_passwordController.text.trim().isEmpty) {
      Get.snackbar(
        'Erreur',
        'Veuillez entrer votre mot de passe',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    if (_attemptCount >= 5) {
      Get.snackbar(
        'Bloqué',
        'Trop de tentatives. Attendez 30 secondes.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final vaultController = Get.find<VaultController>();

      final success = await vaultController.unlockVault(
        _passwordController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (success) {
        // ✅ IMPORTANT: ne pas redemander unlock à chaque ajout
        // (ça se règle dans VaultController, mais au moins ici on sort proprement)
        Get.offAllNamed('/main');
      } else {
        if (!mounted) return;
        setState(() => _attemptCount++);

        _passwordController.clear();

        Get.snackbar(
          '❌ Échec',
          'Mot de passe incorrect',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );

        if (_attemptCount >= 5) {
          _showTooManyAttemptsDialog();
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      Get.snackbar(
        'Erreur',
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _showTooManyAttemptsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Trop de tentatives'),
          ],
        ),
        content: const Text(
          'Vous avez effectué 5 tentatives échouées.\n'
          'Veuillez attendre 30 secondes avant de réessayer.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();

              // Bloquer pendant 30 secondes
              Future.delayed(const Duration(seconds: 30), () {
                if (!mounted) return;
                setState(() => _attemptCount = 0);

                Get.snackbar(
                  'Info',
                  'Vous pouvez réessayer maintenant',
                  backgroundColor: Colors.blue,
                  colorText: Colors.white,
                );
              });
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mot de passe oublié'),
        content: const Text(
          'Malheureusement, il est IMPOSSIBLE de récupérer '
          'votre mot de passe maître.\n\n'
          'C\'est le principe du chiffrement zero-knowledge.\n\n'
          'Vous devrez réinitialiser votre vault et PERDRE '
          'toutes vos données.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showResetConfirmation();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Confirmation'),
        content: const Text(
          'Êtes-vous ABSOLUMENT sûr ?\n\n'
          'Cette action supprimera:\n'
          '• Tous vos fichiers\n'
          '• Tous vos contacts\n'
          '• Tous vos événements\n'
          '• Toutes vos notes\n\n'
          'Cette action est IRRÉVERSIBLE.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();

              final vaultController = Get.find<VaultController>();
              await vaultController.resetVault();

              Get.offAllNamed('/login');

              Get.snackbar(
                'Vault réinitialisé',
                'Vous pouvez créer un nouveau coffre',
                backgroundColor: Colors.orange,
                colorText: Colors.white,
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('TOUT SUPPRIMER'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<VaultController>(); // ✅ pas de Obx ici

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue[900]!,
              Colors.blue[700]!,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.lock, size: 60, color: Colors.blue),
                  ),
                  const SizedBox(height: 32),

                  const Text(
                    'Déverrouiller le vault',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ✅ Plus de Obx => plus de crash
                  Text(
                    controller.currentUserEmail ?? 'Utilisateur',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 48),

                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          autofocus: true,
                          onSubmitted: (_) => _unlockVault(),
                          decoration: InputDecoration(
                            labelText: 'Mot de passe maître',
                            prefixIcon: const Icon(Icons.vpn_key),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 24),

                        ElevatedButton(
                          onPressed: _isLoading ? null : _unlockVault,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Déverrouiller',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 16),

                        TextButton(
                          onPressed: _showForgotPasswordDialog,
                          child: const Text('Mot de passe oublié ?'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  if (_attemptCount > 0)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Tentatives échouées: $_attemptCount / 5',
                        style: TextStyle(
                          color: Colors.red[900],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
