import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../services/pin_service.dart';

/// Page de configuration du code PIN
class PinSetupView extends StatefulWidget {
  final bool isChange; // true = changer PIN, false = créer PIN

  const PinSetupView({
    super.key,
    this.isChange = false,
  });

  @override
  State<PinSetupView> createState() => _PinSetupViewState();
}

class _PinSetupViewState extends State<PinSetupView> {
  final _oldPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _oldPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _setupPin() async {
    // Validation
    if (widget.isChange && _oldPinController.text.isEmpty) {
      Get.snackbar('Erreur', 'Entrez votre ancien code PIN');
      return;
    }

    if (_newPinController.text.isEmpty) {
      Get.snackbar('Erreur', 'Entrez un nouveau code PIN');
      return;
    }

    if (_newPinController.text.length < 4) {
      Get.snackbar('Erreur', 'Le code doit contenir au moins 4 chiffres');
      return;
    }

    if (_newPinController.text != _confirmPinController.text) {
      Get.snackbar('Erreur', 'Les codes ne correspondent pas');
      return;
    }

    try {
      bool success;

      if (widget.isChange) {
        success = await PinService.changePin(
          oldPin: _oldPinController.text,
          newPin: _newPinController.text,
        );
      } else {
        success = await PinService.setupPin(_newPinController.text);
      }

      if (success) {
        Get.snackbar(
          '✅ Succès',
          widget.isChange ? 'Code PIN modifié' : 'Code PIN activé',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        Get.back();
      } else {
        Get.snackbar(
          '❌ Erreur',
          'Ancien code incorrect',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar('Erreur', e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isChange ? 'Changer le code PIN' : 'Configurer le code PIN'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icône
            const Icon(
              Icons.pin_outlined,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),

            // Description
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[900]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Le code PIN protège l\'accès en lecture à vos données sensibles. '
                      'Il doit contenir 4 à 6 chiffres.',
                      style: TextStyle(color: Colors.blue[900], fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Ancien PIN (si changement)
            if (widget.isChange) ...[
              TextField(
                controller: _oldPinController,
                obscureText: _obscureOld,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Ancien code PIN',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureOld ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureOld = !_obscureOld),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Nouveau PIN
            TextField(
              controller: _newPinController,
              obscureText: _obscureNew,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: widget.isChange ? 'Nouveau code PIN' : 'Code PIN',
                hintText: '4-6 chiffres',
                prefixIcon: const Icon(Icons.vpn_key),
                suffixIcon: IconButton(
                  icon: Icon(_obscureNew ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // Confirmation
            TextField(
              controller: _confirmPinController,
              obscureText: _obscureConfirm,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Confirmer le code PIN',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),

            // Bouton validation
            ElevatedButton(
              onPressed: _setupPin,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text(
                widget.isChange ? 'Modifier le code' : 'Activer le code PIN',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

            // Désactiver le PIN (si changement)
            if (widget.isChange) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Désactiver le code PIN ?'),
                      content: const Text(
                        'Vous ne serez plus protégé lors de l\'accès à vos données.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Annuler'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Désactiver'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await PinService.disablePin();
                    Get.snackbar('Code PIN désactivé', 'Protection désactivée');
                    Get.back();
                  }
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Désactiver le code PIN'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}