import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../controllers/vault_controller.dart';
import '../../services/pin_service.dart';
import '../../widgets/pin_verification_dialog.dart';

class DocumentsTab extends StatefulWidget {
  const DocumentsTab({super.key});

  @override
  State<DocumentsTab> createState() => _DocumentsTabState();
}

class _DocumentsTabState extends State<DocumentsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final VaultController controller = Get.find();
  final ImagePicker _picker = ImagePicker();
  
  bool _isPinEnabled = false;
  bool _isUnlocked = false; // Session de lecture déverrouillée

  @override
  void initState() {
    super.initState();
    _checkPinStatus();
  }

  Future<void> _checkPinStatus() async {
    final enabled = await PinService.isPinEnabled();
    setState(() => _isPinEnabled = enabled);
  }

  /// Vérifie le PIN avant d'afficher un document
  Future<bool> _verifyPinIfNeeded() async {
    // Si déjà déverrouillé dans cette session
    if (_isUnlocked) return true;

    // Si PIN désactivé
    if (!_isPinEnabled) {
      setState(() => _isUnlocked = true);
      return true;
    }

    // Demander le PIN
    final success = await PinVerificationDialog.show(
      context,
      title: 'Accès aux documents',
      message: 'Entrez votre code PIN pour consulter vos documents',
    );

    if (success) {
      setState(() => _isUnlocked = true);
    }

    return success;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Obx(() {
      // Convertir VaultItem en Map pour compatibilité
      final allFiles = controller.files;
      final documents = allFiles
          .where((item) => controller.getFileCategory(item.filename ?? '') == 'Documents')
          .map((item) => {
                'id': item.id,
                'filename': item.filename,
                'size': item.size,
                'category': item.category,
                'created_at': item.createdAt.toIso8601String(),
              })
          .toList();

      return Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: documents.isEmpty
                ? _buildEmptyState()
                : _buildDocumentsList(documents),
          ),
        ],
      );
    });
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un document...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Bouton ajouter
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.blue, size: 28),
            onPressed: _showAddOptions,
            tooltip: 'Ajouter',
          ),

          // Indicateur PIN
          if (_isPinEnabled)
            IconButton(
              icon: Icon(
                _isUnlocked ? Icons.lock_open : Icons.lock,
                color: _isUnlocked ? Colors.green : Colors.orange,
              ),
              onPressed: () {
                if (_isUnlocked) {
                  setState(() => _isUnlocked = false);
                  Get.snackbar('🔒 Verrouillé', 'Documents verrouillés');
                } else {
                  _verifyPinIfNeeded();
                }
              },
              tooltip: _isUnlocked ? 'Verrouiller' : 'Déverrouiller',
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 100, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          Text(
            'Aucun document',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 10),
          const Text('Ajoutez votre premier document',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _showAddOptions,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un document'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              "NB: Un scan/galerie ajoute une IMAGE (.jpg/.png), donc ça apparaît dans l'onglet Images, pas Documents.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsList(List<Map<String, dynamic>> documents) {
    return RefreshIndicator(
      onRefresh: () async => controller.loadFiles(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: documents.length,
        itemBuilder: (context, index) {
          final doc = documents[index];
          
          // Afficher le document masqué si verrouillé
          if (_isPinEnabled && !_isUnlocked) {
            return _buildLockedDocumentCard(doc);
          }
          
          return _buildDocumentCard(doc);
        },
      ),
    );
  }

  /// Carte document normale
  Widget _buildDocumentCard(Map<String, dynamic> doc) {
    final filename = (doc['filename'] ?? '').toString();
    final size = doc['size'] as int? ?? 0;
    final createdAt = doc['created_at']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: _getDocumentIcon(filename),
        title: Text(
          filename,
          style: const TextStyle(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '${_formatFileSize(size)} • ${_formatDate(createdAt)}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () => _showDocumentActions(doc),
        ),
        onTap: () => _viewDocument(doc),
      ),
    );
  }

  /// Carte document verrouillée (floutée)
  Widget _buildLockedDocumentCard(Map<String, dynamic> doc) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.grey.shade200, Colors.grey.shade100],
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.lock, color: Colors.grey),
          ),
          title: Text(
            '• • • • • • • • • •',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Document masqué',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),
          trailing: const Icon(Icons.lock, color: Colors.orange),
          onTap: () async {
            final unlocked = await _verifyPinIfNeeded();
            if (unlocked) {
              _viewDocument(doc);
            }
          },
        ),
      ),
    );
  }

  Widget _getDocumentIcon(String filename) {
    final lower = filename.toLowerCase();
    IconData icon;
    Color color;

    if (lower.endsWith('.pdf')) {
      icon = Icons.picture_as_pdf;
      color = Colors.red;
    } else if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
      icon = Icons.description;
      color = Colors.blue;
    } else if (lower.endsWith('.xls') || lower.endsWith('.xlsx')) {
      icon = Icons.table_chart;
      color = Colors.green;
    } else if (lower.endsWith('.txt')) {
      icon = Icons.text_snippet;
      color = Colors.grey;
    } else {
      icon = Icons.insert_drive_file;
      color = Colors.orange;
    }

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 28),
    );
  }

  void _showAddOptions() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ajouter un document',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('Scanner un document'),
              subtitle: const Text('Ajoute une image (va dans Images)'),
              onTap: () {
                Get.back();
                _scanDocument();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: const Text('Depuis la galerie'),
              subtitle: const Text('Ajoute une image (va dans Images)'),
              onTap: () {
                Get.back();
                _pickFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder, color: Colors.orange),
              title: const Text('Parcourir les fichiers'),
              subtitle: const Text('PDF, DOC, XLS, TXT...'),
              onTap: () {
                Get.back();
                _pickFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanDocument() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (photo != null) {
        final bytes = await photo.readAsBytes();
        await controller.addFile(
          filename: photo.name,
          data: bytes,
        );
        Get.snackbar(
          '✅ Scan ajouté',
          'Ajouté dans Images (car fichier image)',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        '❌ Erreur',
        'Impossible de scanner: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final images = await _picker.pickMultiImage();

      if (images.isNotEmpty) {
        for (final img in images) {
          final bytes = await img.readAsBytes();
          await controller.addFile(filename: img.name, data: bytes);
        }
        Get.snackbar(
          '✅ Images ajoutées',
          '${images.length} ajoutée(s)',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar('❌ Erreur', 'Impossible d\'ajouter: $e');
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx'],
      );

      if (result != null && result.files.isNotEmpty) {
        int count = 0;
        for (final f in result.files) {
          if (f.bytes != null) {
            await controller.addFile(filename: f.name, data: f.bytes!);
            count++;
          }
        }
        if (count > 0) {
          Get.snackbar('✅ Fichiers ajoutés', '$count fichier(s) ajouté(s)');
        }
      }
    } catch (e) {
      Get.snackbar('❌ Erreur', 'Impossible d\'ajouter: $e');
    }
  }

  void _showDocumentActions(Map<String, dynamic> doc) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              (doc['filename'] ?? '').toString(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.visibility, color: Colors.blue),
              title: const Text('Ouvrir'),
              onTap: () {
                Get.back();
                _viewDocument(doc);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Supprimer'),
              onTap: () {
                Get.back();
                _deleteDocument(doc);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _viewDocument(Map<String, dynamic> doc) async {
    // Vérifier le PIN avant d'ouvrir
    if (!await _verifyPinIfNeeded()) {
      return;
    }

    try {
      // Déchiffrer et afficher
      final content = controller.decryptItemById(doc['id']);
      
      Get.dialog(
        AlertDialog(
          title: Text((doc['filename'] ?? '').toString()),
          content: SingleChildScrollView(
            child: Text(content),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
    } catch (e) {
      Get.snackbar('Erreur', 'Impossible de déchiffrer: $e');
    }
  }

  void _deleteDocument(Map<String, dynamic> doc) {
    Get.dialog(
      AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Supprimer "${(doc['filename'] ?? '').toString()}" ?'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              await controller.deleteFileById(doc['id']);
              Get.back();
              Get.snackbar('✅ Supprimé', 'Document supprimé');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Date inconnue';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return 'Date invalide';
    }
  }
}