import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/vault_controller.dart';
import '../services/pin_service.dart';
import '../widgets/pin_verification_dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data'; // <-- Add this line

/// Exemple d'onglet protégé par PIN
/// Affiche les données seulement après vérification
class ProtectedDataTab extends StatefulWidget {
  const ProtectedDataTab({super.key});

  @override
  State<ProtectedDataTab> createState() => _ProtectedDataTabState();
}

class _ProtectedDataTabState extends State<ProtectedDataTab>
    with AutomaticKeepAliveClientMixin {
  final vaultController = Get.find<VaultController>();

  bool _isVerified = false;
  bool _isPinEnabled = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _checkPinStatus();
  }

  Future<void> _checkPinStatus() async {
    final enabled = await PinService.isPinEnabled();
    setState(() => _isPinEnabled = enabled);

    // Si le PIN est désactivé, afficher directement les données
    if (!enabled) {
      setState(() => _isVerified = true);
    }
  }

  /// Demande le PIN avant d'afficher les données
  Future<void> _requestPinVerification() async {
    final success = await PinVerificationDialog.show(
      context,
      title: 'Accès aux documents',
      message: 'Entrez votre code PIN pour consulter vos documents',
    );

    if (success) {
      setState(() => _isVerified = true);

      Get.snackbar(
        '✅ Accès autorisé',
        'Vous pouvez maintenant consulter vos documents',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    }
  }

  /// Affiche un document après vérification PIN
  Future<void> _viewDocument(int index) async {
    // Si déjà vérifié, afficher directement
    if (_isVerified) {
      _showDocumentContent(index);
      return;
    }

    // Sinon, demander le PIN
    final success = await PinVerificationDialog.show(
      context,
      title: 'Consulter ce document',
      message: 'Entrez votre code PIN',
      onSuccess: () => _showDocumentContent(index),
    );

    if (success) {
      setState(() => _isVerified = true);
    }
  }

  void _showDocumentContent(int index) {
    final file = vaultController.files[index];

    try {
      // Déchiffrer le contenu
      final decrypted = vaultController.decryptItem(file);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(file.filename ?? 'Document'),
          content: SingleChildScrollView(
            child: Text(decrypted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
    } catch (e) {
      Get.snackbar('Erreur', 'Impossible de déchiffrer: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      body: Obx(() {
        if (vaultController.files.isEmpty) {
          return const Center(
            child: Text('Aucun document'),
          );
        }

        // Si PIN activé et pas encore vérifié
        if (_isPinEnabled && !_isVerified) {
          return _buildLockedView();
        }

        // Afficher les documents
        return _buildDocumentsList();
      }),
      // Import at the top of the file
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          print('🔵 Button Clicked');

          // 1. Check Encryption Key
          if (vaultController.encryptionKey == null) {
            print('🔴 Error: Vault Locked');
            Get.snackbar('Erreur', 'Le coffre est verrouillé.');
            return;
          }
          print('🟢 Vault is Unlocked. Opening File Picker...');

          try {
            // 2. Pick File
            FilePickerResult? result = await FilePicker.platform.pickFiles(
              type: FileType.any,
              withData: true, // IMPORTANT for Web
            );

            if (result == null) {
              print('🟡 User cancelled file picker');
              return;
            }

            print('🟢 File Picked: ${result.files.single.name}');

            // 3. Get Data
            Uint8List? fileBytes = result.files.single.bytes;

            if (fileBytes == null) {
              print('🔴 Error: File bytes are empty!');
              return;
            }
            print('🟢 File Size: ${fileBytes.length} bytes');

            // 4. Encrypt & Save
            print('🔵 Starting Encryption & Save...');
            bool success = await vaultController.addFile(
                filename: result.files.single.name, data: fileBytes);

            if (success) {
              print('✅ SUCCESS: File saved to DB');
              Get.snackbar('Succès', 'Document ajouté');

              print('🔵 Triggering Sync...');
              await vaultController.syncWithServer();
            } else {
              print('🔴 FAIL: Controller returned false');
              Get.snackbar('Erreur', 'Échec de la sauvegarde');
            }
          } catch (e) {
            print('🔴 EXCEPTION: $e');
            Get.snackbar('Erreur', e.toString());
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Vue verrouillée (PIN requis)
  Widget _buildLockedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icône cadenas
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.blue[50],
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_outline,
              size: 50,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 24),

          // Texte
          const Text(
            'Contenu protégé',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Entrez votre code PIN pour accéder à vos documents',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Bouton déverrouiller
          ElevatedButton.icon(
            onPressed: _requestPinVerification,
            icon: const Icon(Icons.lock_open),
            label: const Text('Déverrouiller'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),

          const SizedBox(height: 16),

          // Nombre de documents masqués
          Obx(() => Text(
                '${vaultController.files.length} document(s) masqué(s)',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              )),
        ],
      ),
    );
  }

  /// Liste des documents
  Widget _buildDocumentsList() {
    return Obx(() {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: vaultController.files.length,
        itemBuilder: (context, index) {
          final file = vaultController.files[index];

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue[100],
                child: Icon(
                  _getFileIcon(file.category),
                  color: Colors.blue,
                ),
              ),
              title: Text(
                file.filename ?? 'Sans nom',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${file.category} • ${_formatSize(file.size ?? 0)}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _viewDocument(index),
            ),
          );
        },
      );
    });
  }

  IconData _getFileIcon(String? category) {
    switch (category) {
      case 'Documents':
        return Icons.description;
      case 'Images':
        return Icons.image;
      case 'Videos':
        return Icons.video_library;
      case 'Audio':
        return Icons.audiotrack;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
