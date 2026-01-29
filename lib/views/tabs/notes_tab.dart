import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/vault_controller.dart';
import '../../services/crypto_service.dart';
import '../../services/db_service.dart';

class NotesTab extends StatefulWidget {
  const NotesTab({super.key});

  @override
  State<NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<NotesTab> {
  final VaultController vaultController = Get.find<VaultController>();

  // ✅ Notes chargées depuis DB (décryptées)
  final List<Map<String, dynamic>> _notes = [];

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadNotesFromDb();
  }

  Future<void> _loadNotesFromDb() async {
    try {
      setState(() => _loading = true);

      final rows = await DBService.query('notes', orderBy: 'created_at DESC');

      _notes.clear();

      for (final row in rows) {
        final id = row['id'];

        // On stocke en priorité dans "data" chiffré
        final encryptedData = row['data']?.toString();

        if (encryptedData != null && encryptedData.isNotEmpty) {
          if (vaultController.encryptionKey == null) {
            // coffre verrouillé => on ne peut pas déchiffrer
            continue;
          }

          final jsonText = await CryptoService.decryptText(
            encryptedData,
            vaultController.encryptionKey!,
          );

          final note = jsonDecode(jsonText) as Map<String, dynamic>;
          note['id'] ??= id;

          _notes.add(note);
        } else {
          // fallback (si jamais tu avais des anciennes colonnes en clair)
          _notes.add({
            'id': id,
            'title': row['title'] ?? 'Sans titre',
            'content': row['content'] ?? '',
            'category': row['category'],
            'date': row['date'] ?? DateTime.now().toString().split(' ')[0],
          });
        }
      }

      setState(() {});
    } catch (e) {
      Get.snackbar(
        '❌ Erreur',
        'Impossible de charger les notes: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : (_notes.isEmpty ? _buildEmptyState() : _buildNotesList()),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher une note...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          SizedBox(width: 12),
          IconButton(
            icon: Icon(Icons.grid_view, color: Colors.blue),
            onPressed: () {
              Get.snackbar('Vue', 'Changement de vue à venir');
            },
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
          Icon(
            Icons.note_alt_outlined,
            size: 100,
            color: Colors.grey.shade300,
          ),
          SizedBox(height: 20),
          Text(
            'Aucune note',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Créez votre première note sécurisée',
            style: TextStyle(color: Colors.grey),
          ),
          SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _createNote,
            icon: Icon(Icons.add),
            label: Text('Nouvelle note'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesList() {
    return RefreshIndicator(
      onRefresh: _loadNotesFromDb,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _notes.length,
        itemBuilder: (context, index) {
          final note = _notes[index];
          return _buildNoteCard(note, index);
        },
      ),
    );
  }

  Widget _buildNoteCard(Map<String, dynamic> note, int index) {
    final colors = [
      Colors.yellow.shade100,
      Colors.blue.shade100,
      Colors.green.shade100,
      Colors.pink.shade100,
      Colors.purple.shade100,
    ];
    final color = colors[index % colors.length];

    final title = (note['title'] ?? 'Sans titre').toString();
    final content = (note['content'] ?? '').toString();

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _editNote(note, index),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.more_vert),
                    onPressed: () => _showNoteActions(note, index),
                  ),
                ],
              ),
              if (content.isNotEmpty) ...[
                SizedBox(height: 8),
                Text(
                  content,
                  style: TextStyle(fontSize: 14),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time,
                      size: 12, color: Colors.grey.shade700),
                  SizedBox(width: 4),
                  Text(
                    (note['date'] ?? DateTime.now().toString().split(' ')[0])
                        .toString(),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                  if (note['category'] != null &&
                      note['category'].toString().isNotEmpty) ...[
                    SizedBox(width: 16),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        note['category'].toString(),
                        style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _createNote() {
    if (vaultController.encryptionKey == null) {
      Get.snackbar(
        'Coffre verrouillé',
        'Déverrouillez le coffre pour créer une note',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String? selectedCategory;

    Get.dialog(
      AlertDialog(
        title: Text('Nouvelle note'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Titre',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: contentController,
                decoration: InputDecoration(
                  labelText: 'Contenu',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                  alignLabelWithHint: true,
                ),
                maxLines: 10,
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Catégorie',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: ['Personnel', 'Travail', 'Idées', 'Important']
                    .map((cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(cat),
                        ))
                    .toList(),
                onChanged: (value) => selectedCategory = value,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty) return;

              final note = <String, dynamic>{
                'title': titleController.text.trim(),
                'content': contentController.text.trim(),
                'category': selectedCategory ?? '',
                'date': DateTime.now().toString().split(' ')[0],
              };

              // Inside _createNote -> ElevatedButton.onPressed
              try {
                // Use the controller method
                final success = await vaultController.addNote(
                  title: titleController.text.trim(),
                  content: contentController.text.trim(),
                );

                if (success) {
                  Get.back();
                  Get.snackbar(
                    '✅ Note créée',
                    titleController.text.trim(),
                    backgroundColor: Colors.green,
                    colorText: Colors.white,
                  );
                  await _loadNotesFromDb();
                }
              } catch (e) {
                Get.snackbar(
                  '❌ Erreur',
                  'Impossible de créer la note: $e',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            child: Text('Créer'),
          ),
        ],
      ),
    );
  }

  void _editNote(Map<String, dynamic> note, int index) {
    if (vaultController.encryptionKey == null) {
      Get.snackbar(
        'Coffre verrouillé',
        'Déverrouillez le coffre pour modifier une note',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    final titleController =
        TextEditingController(text: (note['title'] ?? '').toString());
    final contentController =
        TextEditingController(text: (note['content'] ?? '').toString());
    String? selectedCategory = (note['category'] ?? '').toString().isEmpty
        ? null
        : note['category'].toString();

    Get.dialog(
      AlertDialog(
        title: Text('Modifier la note'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Titre',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: contentController,
                decoration: InputDecoration(
                  labelText: 'Contenu',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                  alignLabelWithHint: true,
                ),
                maxLines: 10,
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Catégorie',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: ['Personnel', 'Travail', 'Idées', 'Important']
                    .map((cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(cat),
                        ))
                    .toList(),
                onChanged: (value) => selectedCategory = value,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty) return;

              final id = note['id'];
              if (id is! int) {
                Get.snackbar(
                  'Erreur',
                  'ID note invalide',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
                return;
              }

              final updated = <String, dynamic>{
                'id': id,
                'title': titleController.text.trim(),
                'content': contentController.text.trim(),
                'category': selectedCategory ?? '',
                'date': note['date'] ?? DateTime.now().toString().split(' ')[0],
              };

              try {
                final encrypted = await CryptoService.encryptText(
                  jsonEncode(updated..remove('id')),
                  vaultController.encryptionKey!,
                );

                await DBService.update(
                  'notes',
                  {'data': encrypted},
                  where: 'id = ?',
                  whereArgs: [id],
                );

                Get.back();

                Get.snackbar(
                  '✅ Note modifiée',
                  updated['title'],
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );

                await _loadNotesFromDb();
              } catch (e) {
                Get.snackbar(
                  '❌ Erreur',
                  'Impossible de modifier: $e',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            child: Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _showNoteActions(Map<String, dynamic> note, int index) {
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
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
              (note['title'] ?? '').toString(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.edit, color: Colors.blue),
              title: Text('Modifier'),
              onTap: () {
                Get.back();
                _editNote(note, index);
              },
            ),
            ListTile(
              leading: Icon(Icons.share, color: Colors.green),
              title: Text('Partager'),
              onTap: () {
                Get.back();
                Get.snackbar('Partage', 'Fonctionnalité à venir');
              },
            ),
            ListTile(
              leading: Icon(Icons.copy, color: Colors.orange),
              title: Text('Dupliquer'),
              onTap: () async {
                Get.back();

                if (vaultController.encryptionKey == null) return;

                final duplicate = <String, dynamic>{
                  'title': (note['title'] ?? '').toString(),
                  'content': (note['content'] ?? '').toString(),
                  'category': (note['category'] ?? '').toString(),
                  'date': DateTime.now().toString().split(' ')[0],
                };

                try {
                  final encrypted = await CryptoService.encryptText(
                    jsonEncode(duplicate),
                    vaultController.encryptionKey!,
                  );

                  await DBService.insert('notes', {
                    'created_at': DateTime.now().toIso8601String(),
                    'data': encrypted,
                  });

                  Get.snackbar(
                    '✅ Dupliquée',
                    'Note dupliquée',
                    backgroundColor: Colors.green,
                    colorText: Colors.white,
                  );

                  await _loadNotesFromDb();
                } catch (e) {
                  Get.snackbar(
                    '❌ Erreur',
                    'Impossible de dupliquer: $e',
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                  );
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Supprimer'),
              onTap: () {
                Get.back();
                _confirmDelete(index);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(int index) {
    Get.dialog(
      AlertDialog(
        title: Text('Confirmer la suppression'),
        content: Text('Voulez-vous vraiment supprimer cette note ?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final id = _notes[index]['id'];
              if (id is int) {
                await DBService.delete('notes',
                    where: 'id = ?', whereArgs: [id]);
              }

              setState(() {
                _notes.removeAt(index);
              });

              Get.back();
              Get.snackbar(
                '✅ Supprimée',
                'Note supprimée',
                backgroundColor: Colors.orange,
                colorText: Colors.white,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
