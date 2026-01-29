import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../controllers/vault_controller.dart';
import '../../services/pin_service.dart';
import '../../services/biometric_service.dart';
import '../../services/secure_storage_service.dart';
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

  bool _isSecurityEnabled = false; // Either PIN or Biometric
  bool _isUnlocked = false;
  String _searchQuery = '';
  String? _selectedFolder;

  @override
  void initState() {
    super.initState();
    _checkSecurityStatus();
  }

  /// Check if ANY security method is enabled (PIN or Biometric)
  Future<void> _checkSecurityStatus() async {
    final pinEnabled = await PinService.isPinEnabled();
    final bioEnabled = await _isBiometricEnabled();

    setState(() {
      _isSecurityEnabled = pinEnabled || bioEnabled;
    });
  }

  Future<bool> _isBiometricEnabled() async {
    final value = await SecureStorageService.read('biometric_enabled');
    return value == 'true';
  }

  /// Verify security (PIN or Biometric) before accessing documents
  Future<bool> _verifySecurityIfNeeded() async {
    // Already unlocked
    if (_isUnlocked) return true;

    // No security enabled
    if (!_isSecurityEnabled) {
      setState(() => _isUnlocked = true);
      return true;
    }

    // Check if biometric is enabled first (faster)
    final bioEnabled = await _isBiometricEnabled();
    if (bioEnabled) {
      final canUseBio = await BiometricService.canAuthenticate();
      if (canUseBio) {
        final success = await BiometricService.authenticate();
        if (success) {
          setState(() => _isUnlocked = true);
          return true;
        }
      }
    }

    // Fallback to PIN or if biometric failed
    final pinEnabled = await PinService.isPinEnabled();
    if (pinEnabled) {
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

    return false;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Obx(() {
      final allFiles = controller.files;
      final documents = allFiles
          .map((item) => {
                'id': item.id,
                'filename': item.filename ?? 'Unknown',
                'size': item.size,
                'category': item.category,
                'created_at': item.createdAt.toIso8601String(),
              })
          .toList();

      final filteredDocs = _filterFiles(documents);
      final groupedDocs = _groupFilesByType(filteredDocs);

      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            Expanded(
              child: _selectedFolder == null
                  ? _buildFoldersView(groupedDocs)
                  : _buildFilesView(
                      groupedDocs[_selectedFolder] ?? [], _selectedFolder!),
            ),
          ],
        ),
        floatingActionButton: _buildFAB(),
      );
    });
  }

  Map<String, List<Map<String, dynamic>>> _groupFilesByType(
      List<Map<String, dynamic>> files) {
    final groups = <String, List<Map<String, dynamic>>>{
      'PDF': [],
      'Images': [], // jpg, png, jpeg
      'Documents': [], // doc, docx
      'Tableurs': [], // xls, xlsx
      'Textes': [], // txt
      'Autres': [],
    };

    for (final file in files) {
      final filename = (file['filename'] ?? '').toString().toLowerCase();

      if (filename.endsWith('.pdf')) {
        groups['PDF']!.add(file);
      } else if (filename.endsWith('.jpg') ||
          filename.endsWith('.jpeg') ||
          filename.endsWith('.png') ||
          filename.endsWith('.gif') ||
          filename.endsWith('.webp')) {
        groups['Images']!.add(file);
      } else if (filename.endsWith('.doc') || filename.endsWith('.docx')) {
        groups['Documents']!.add(file);
      } else if (filename.endsWith('.xls') || filename.endsWith('.xlsx')) {
        groups['Tableurs']!.add(file);
      } else if (filename.endsWith('.txt')) {
        groups['Textes']!.add(file);
      } else {
        groups['Autres']!.add(file);
      }
    }

    groups.removeWhere((key, value) => value.isEmpty);
    return groups;
  }

  List<Map<String, dynamic>> _filterFiles(List<Map<String, dynamic>> files) {
    if (_searchQuery.isEmpty) return files;
    return files.where((file) {
      final filename = (file['filename'] ?? '').toString().toLowerCase();
      return filename.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (_selectedFolder != null)
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _selectedFolder = null),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            if (_selectedFolder != null) const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedFolder ?? 'Mes Documents',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  if (_selectedFolder == null)
                    Text(
                      'Organisez vos fichiers',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
            if (_isSecurityEnabled)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isUnlocked
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _isUnlocked ? Icons.lock_open : Icons.lock,
                  color: _isUnlocked ? Colors.green : Colors.orange,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: Colors.white,
      child: TextField(
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Rechercher dans les documents...',
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () => setState(() => _searchQuery = ''),
                )
              : null,
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildFoldersView(Map<String, List<Map<String, dynamic>>> groups) {
    if (groups.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async => controller.loadFiles(),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Catégories',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 16),
          ...groups.entries.map((entry) =>
              _buildFolderCard(entry.key, entry.value.length, entry.value)),
        ],
      ),
    );
  }

  Widget _buildFolderCard(
      String folderName, int fileCount, List<Map<String, dynamic>> files) {
    final folderConfig = _getFolderConfig(folderName);

    return GestureDetector(
      onTap: () => setState(() => _selectedFolder = folderName),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: folderConfig['gradient'],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                folderConfig['icon'],
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    folderName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$fileCount fichier${fileCount > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (_isSecurityEnabled && !_isUnlocked)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock,
                              size: 12, color: Colors.orange.shade700),
                          const SizedBox(width: 4),
                          Text(
                            'Verrouillé',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getFolderConfig(String folderName) {
    switch (folderName) {
      case 'PDF':
        return {
          'icon': Icons.picture_as_pdf,
          'gradient': [Colors.red.shade400, Colors.red.shade600],
        };
      case 'Images':
        return {
          'icon': Icons.image,
          'gradient': [Colors.pink.shade400, Colors.pink.shade600],
        };
      case 'Documents':
        return {
          'icon': Icons.description,
          'gradient': [Colors.blue.shade400, Colors.blue.shade600],
        };
      case 'Tableurs':
        return {
          'icon': Icons.table_chart,
          'gradient': [Colors.green.shade400, Colors.green.shade600],
        };
      case 'Textes':
        return {
          'icon': Icons.text_snippet,
          'gradient': [Colors.purple.shade400, Colors.purple.shade600],
        };
      default:
        return {
          'icon': Icons.folder,
          'gradient': [Colors.orange.shade400, Colors.orange.shade600],
        };
    }
  }

  Widget _buildFilesView(List<Map<String, dynamic>> files, String folderName) {
    if (files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Aucun fichier dans $folderName',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => controller.loadFiles(),
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: files.length,
        itemBuilder: (context, index) {
          final file = files[index];

          if (_isSecurityEnabled && !_isUnlocked) {
            return _buildLockedFileCard(file);
          }

          return _buildFileCard(file);
        },
      ),
    );
  }

  Widget _buildFileCard(Map<String, dynamic> file) {
    final filename = (file['filename'] ?? '').toString();
    final size = file['size'] as int? ?? 0;
    final createdAt = file['created_at']?.toString();

    return Dismissible(
      key: Key(file['id'].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) => _confirmDelete(file),
      onDismissed: (direction) => _deleteDocument(file),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _viewDocument(file),
            onLongPress: () => _showDocumentActions(file),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _getDocumentIcon(filename),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          filename,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.storage,
                                size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(
                              _formatFileSize(size),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.calendar_today,
                                size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                    onPressed: () => _showDocumentActions(file),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLockedFileCard(Map<String, dynamic> file) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey.shade100, Colors.grey.shade200],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            if (await _verifySecurityIfNeeded()) {
              _viewDocument(file);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.lock, color: Colors.grey, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '• • • • • • • • • •',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Document verrouillé',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.lock, color: Colors.orange.shade700),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.folder_open,
                size: 80,
                color: Colors.blue.shade300,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Aucun document',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Commencez par ajouter votre premier document',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _showAddOptions,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un document'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Les images scannées apparaissent dans l\'onglet Images',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: _showAddOptions,
      backgroundColor: Colors.blue,
      icon: const Icon(Icons.add),
      label: const Text('Ajouter'),
      elevation: 4,
    );
  }

  Widget _getDocumentIcon(String filename) {
    final lower = filename.toLowerCase();
    IconData icon;
    Color color;

    if (lower.endsWith('.pdf')) {
      icon = Icons.picture_as_pdf;
      color = Colors.red.shade600;
    } else if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif')) {
      icon = Icons.image;
      color = Colors.pink.shade600;
    } else if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
      icon = Icons.description;
      color = Colors.blue.shade600;
    } else if (lower.endsWith('.xls') || lower.endsWith('.xlsx')) {
      icon = Icons.table_chart;
      color = Colors.green.shade600;
    } else if (lower.endsWith('.txt')) {
      icon = Icons.text_snippet;
      color = Colors.purple.shade600;
    } else {
      icon = Icons.insert_drive_file;
      color = Colors.orange.shade600;
    }

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 26),
    );
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Ajouter un document',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              _buildAddOption(
                icon: Icons.camera_alt,
                title: 'Scanner',
                subtitle: 'Prendre une photo (onglet Images)',
                color: Colors.blue,
                onTap: () {
                  Navigator.pop(context);
                  _scanDocument();
                },
              ),
              const SizedBox(height: 12),
              _buildAddOption(
                icon: Icons.photo_library,
                title: 'Galerie',
                subtitle: 'Choisir une image (onglet Images)',
                color: Colors.green,
                onTap: () {
                  Navigator.pop(context);
                  _pickFromGallery();
                },
              ),
              const SizedBox(height: 12),
              _buildAddOption(
                icon: Icons.insert_drive_file,
                title: 'Fichiers',
                subtitle: 'PDF, DOC, XLS, TXT...',
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  _pickFile();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
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
        await controller.addFile(filename: photo.name, data: bytes);
        Get.snackbar(
          '✅ Scan ajouté',
          'Visible dans l\'onglet Images',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
      }
    } catch (e) {
      Get.snackbar(
        '❌ Erreur',
        'Impossible de scanner: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
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
          '${images.length} image${images.length > 1 ? 's' : ''} ajoutée${images.length > 1 ? 's' : ''}',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
      }
    } catch (e) {
      Get.snackbar(
        '❌ Erreur',
        'Impossible d\'ajouter: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        int count = 0;
        for (final f in result.files) {
          if (f.bytes != null) {
            bool success =
                await controller.addFile(filename: f.name, data: f.bytes!);

            if (success) {
              count++;
            }
          }
        }

        if (count > 0) {
          Get.snackbar(
            '✅ Fichiers ajoutés',
            '$count fichier${count > 1 ? 's' : ''} ajouté${count > 1 ? 's' : ''}',
            backgroundColor: Colors.green,
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(16),
            borderRadius: 12,
          );

          await controller.loadFiles();
          controller.syncWithServer();
        }
      }
    } catch (e) {
      Get.snackbar(
        '❌ Erreur',
        'Impossible d\'ajouter: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  void _showDocumentActions(Map<String, dynamic> doc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                (doc['filename'] ?? '').toString(),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _buildActionTile(
                icon: Icons.visibility,
                title: 'Ouvrir',
                color: Colors.blue,
                onTap: () {
                  Navigator.pop(context);
                  _viewDocument(doc);
                },
              ),
              const SizedBox(height: 12),
              _buildActionTile(
                icon: Icons.download,
                title: 'Télécharger',
                color: Colors.green,
                onTap: () {
                  Navigator.pop(context);
                  _downloadDocument(doc);
                },
              ),
              const SizedBox(height: 12),
              _buildActionTile(
                icon: Icons.delete,
                title: 'Supprimer',
                color: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  _deleteDocument(doc);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(Map<String, dynamic> doc) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Confirmer la suppression'),
            content:
                Text('Supprimer "${(doc['filename'] ?? '').toString()}" ?'),
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
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Supprimer'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _viewDocument(Map<String, dynamic> doc) async {
    // Verify security before opening
    if (!await _verifySecurityIfNeeded()) {
      return;
    }

    try {
      final filename = (doc['filename'] ?? '').toString().toLowerCase();

      // Decrypt the file
      final decryptedData = controller.decryptItemBytesById(doc['id']);

      if (decryptedData == null) {
        throw Exception('Impossible de déchiffrer le fichier');
      }

      // Handle different file types
      if (filename.endsWith('.jpg') ||
          filename.endsWith('.jpeg') ||
          filename.endsWith('.png') ||
          filename.endsWith('.gif') ||
          filename.endsWith('.webp')) {
        _viewImage(decryptedData, filename);
      } else if (filename.endsWith('.pdf')) {
        _viewPDF(decryptedData, filename, doc['id']);
      } else if (filename.endsWith('.txt')) {
        _viewText(decryptedData, filename);
      } else {
        Get.snackbar(
          'Format non supporté',
          'Téléchargez le fichier pour l\'ouvrir avec une application externe',
          backgroundColor: Colors.blue,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Impossible de visualiser: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  void _viewImage(Uint8List imageData, String filename) {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      filename,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                ),
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: Image.memory(
                      imageData,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Fermer'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _viewPDF(Uint8List pdfData, String filename, dynamic originalId) {
    // For PDF viewing, we'll show a message since we need pdf_render package
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.picture_as_pdf, color: Colors.red),
            const SizedBox(width: 12),
            const Expanded(child: Text('Visualisation PDF')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'La visualisation PDF sera disponible dans la prochaine mise à jour.',
            ),
            const SizedBox(height: 16),
            Text(
              'En attendant, vous pouvez télécharger le fichier pour l\'ouvrir.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _downloadDocument({'filename': filename, 'id': originalId});
            },
            icon: const Icon(Icons.download),
            label: const Text('Télécharger'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _viewText(Uint8List textData, String filename) {
    final text = String.fromCharCodes(textData);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      filename,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    text,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadDocument(Map<String, dynamic> doc) async {
    // 1. Show immediate progress feedback
    Get.rawSnackbar(
      title: "Téléchargement",
      message: "Préparation de ${doc['filename']}...",
      backgroundColor: Colors.blue,
      showProgressIndicator: true,
      isDismissible: false,
      duration: const Duration(seconds: 2),
    );

    try {
      if (Platform.isAndroid) {
        // 2. Request correct permissions for Android 13+
        // This is needed to write to the public /Download folder
        PermissionStatus status =
            await Permission.manageExternalStorage.request();

        if (status.isDenied) {
          status = await Permission.storage.request();
        }

        if (!status.isGranted) {
          Get.closeAllSnackbars();
          Get.snackbar(
            'Permission refusée',
            'Accès au stockage nécessaire pour télécharger',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
          );
          return;
        }
      }

      // 3. Decrypt the file bytes
      final decryptedData = controller.decryptItemBytesById(doc['id']);
      if (decryptedData == null) {
        throw Exception('Impossible de déchiffrer le fichier');
      }

      // 4. Determine path and save file
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        // Fallback to internal storage if path is unreachable
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) throw Exception('Dossier introuvable');

      final filename = (doc['filename'] ?? 'document_vault').toString();
      final file = File('${directory.path}/$filename');

      // 5. Write the bytes to the disk
      await file.writeAsBytes(decryptedData);

      // 6. Success Feedback
      Get.closeAllSnackbars();
      Get.snackbar(
        '✅ Téléchargé',
        'Sauvegardé dans : ${file.path}',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 5),
        mainButton: TextButton(
          onPressed: () => Get.back(),
          child: const Text("OK", style: TextStyle(color: Colors.white)),
        ),
      );
    } catch (e) {
      Get.closeAllSnackbars();
      Get.snackbar(
        '❌ Erreur',
        'Impossible de télécharger : $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void _deleteDocument(Map<String, dynamic> doc) async {
    await controller.deleteFileById(doc['id']);
    Get.snackbar(
      '✅ Supprimé',
      'Document supprimé avec succès',
      backgroundColor: Colors.green,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
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
