import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/vault_controller.dart';
import '../../services/crypto_service.dart';
import '../../services/db_service.dart';

class ContactsTab extends StatefulWidget {
  const ContactsTab({super.key});

  @override
  State<ContactsTab> createState() => _ContactsTabState();
}

class _ContactsTabState extends State<ContactsTab> {
  final VaultController vaultController = Get.find<VaultController>();

  // ✅ Contacts chargés depuis DB (décryptés)
  final List<Map<String, dynamic>> _contacts = [];

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadContactsFromDb();
  }

  Future<void> _loadContactsFromDb() async {
    try {
      setState(() => _loading = true);

      final rows = await DBService.query('contacts', orderBy: 'created_at DESC');

      _contacts.clear();

      // Si coffre verrouillé, on ne peut pas déchiffrer -> afficher vide (ou message)
      if (vaultController.encryptionKey == null) {
        setState(() {});
        return;
      }

      for (final row in rows) {
        final encrypted = row['data']?.toString();
        if (encrypted == null || encrypted.isEmpty) continue;

        try {
          final jsonText = await CryptoService.decryptText(
            encrypted,
            vaultController.encryptionKey!,
          );

          final obj = jsonDecode(jsonText);
          if (obj is Map<String, dynamic>) {
            final contact = Map<String, dynamic>.from(obj);

            // garder id DB pour delete
            contact['id'] ??= row['id'];

            // normaliser champs attendus par l'UI
            contact['name'] ??= 'Sans nom';
            contact['phone'] = (contact['phone']?.toString().trim().isEmpty ?? true)
                ? null
                : contact['phone'].toString().trim();
            contact['email'] = (contact['email']?.toString().trim().isEmpty ?? true)
                ? null
                : contact['email'].toString().trim();
            contact['notes'] = (contact['notes']?.toString().trim().isEmpty ?? true)
                ? null
                : contact['notes'].toString().trim();

            _contacts.add(contact);
          }
        } catch (_) {
          // Si un contact est illisible (mauvaise clé, données corrompues), on ignore
          continue;
        }
      }

      setState(() {});
    } catch (e) {
      Get.snackbar(
        '❌ Erreur',
        'Impossible de charger les contacts: $e',
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
              : (vaultController.encryptionKey == null
                  ? _buildLockedState()
                  : (_contacts.isEmpty ? _buildEmptyState() : _buildContactsList())),
        ),
      ],
    );
  }

  Widget _buildLockedState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 90, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Coffre verrouillé',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Déverrouillez le coffre pour voir vos contacts',
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => Get.offAllNamed('/unlock_vault'),
            icon: const Icon(Icons.lock_open),
            label: const Text('Déverrouiller'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade100,
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Rechercher un contact...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        // Optionnel: tu peux ajouter un filtre ici plus tard
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.contacts, size: 100, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          Text(
            'Aucun contact',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Ajoutez votre premier contact sécurisé',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _addContact,
            icon: const Icon(Icons.person_add),
            label: const Text('Ajouter un contact'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactsList() {
    return RefreshIndicator(
      onRefresh: _loadContactsFromDb,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _contacts.length,
        itemBuilder: (context, index) {
          final contact = _contacts[index];
          return _buildContactCard(contact);
        },
      ),
    );
  }

  Widget _buildContactCard(Map<String, dynamic> contact) {
    final name = (contact['name'] ?? 'Sans nom').toString().trim();
    final phone = contact['phone']?.toString();
    final email = contact['email']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 30,
          backgroundColor: Colors.blue.shade100,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'U',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ),
        title: Text(
          name.isEmpty ? 'Sans nom' : name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (phone != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.phone, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(phone, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ],
            if (email != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.email, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(email, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () => _showContactActions(contact),
        ),
        onTap: () => _viewContact(contact),
      ),
    );
  }

  void _addContact() {
    if (vaultController.encryptionKey == null) {
      Get.snackbar(
        'Coffre verrouillé',
        'Déverrouillez le coffre pour ajouter un contact',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final notesController = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: const Text('Nouveau contact'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Téléphone',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  prefixIcon: Icon(Icons.note),
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
              final email = emailController.text.trim();
              final notes = notesController.text.trim();

              if (name.isEmpty) return;

              final contact = <String, dynamic>{
                'name': name,
                'phone': phone.isEmpty ? null : phone,
                'email': email.isEmpty ? null : email,
                'notes': notes.isEmpty ? null : notes,
              };

              try {
                final encrypted = await CryptoService.encryptText(
                  jsonEncode(contact),
                  vaultController.encryptionKey!,
                );

                await DBService.insert('contacts', {
                  'created_at': DateTime.now().toIso8601String(),
                  'data': encrypted,
                });

                Get.back();

                Get.snackbar(
                  '✅ Contact ajouté',
                  name,
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );

                await _loadContactsFromDb();
              } catch (e) {
                Get.snackbar(
                  '❌ Erreur',
                  'Impossible d\'ajouter le contact: $e',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _viewContact(Map<String, dynamic> contact) {
    final name = (contact['name'] ?? 'Sans nom').toString().trim();
    final phone = contact['phone']?.toString();
    final email = contact['email']?.toString();
    final notes = contact['notes']?.toString();

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
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.blue.shade100,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              name.isEmpty ? 'Sans nom' : name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (phone != null)
              ListTile(
                leading: const Icon(Icons.phone, color: Colors.blue),
                title: const Text('Téléphone'),
                subtitle: Text(phone),
                trailing: IconButton(
                  icon: const Icon(Icons.call, color: Colors.green),
                  onPressed: () => _makeCall(phone),
                ),
              ),
            if (email != null)
              ListTile(
                leading: const Icon(Icons.email, color: Colors.orange),
                title: const Text('Email'),
                subtitle: Text(email),
                trailing: IconButton(
                  icon: const Icon(Icons.mail, color: Colors.blue),
                  onPressed: () => _sendEmail(email),
                ),
              ),
            if (notes != null && notes.trim().isNotEmpty)
              ListTile(
                leading: const Icon(Icons.note, color: Colors.grey),
                title: const Text('Notes'),
                subtitle: Text(notes),
              ),
          ],
        ),
      ),
    );
  }

  void _showContactActions(Map<String, dynamic> contact) {
    final name = (contact['name'] ?? 'Sans nom').toString();

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
              name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (contact['phone'] != null)
              ListTile(
                leading: const Icon(Icons.call, color: Colors.green),
                title: const Text('Appeler'),
                onTap: () {
                  Get.back();
                  _makeCall(contact['phone'].toString());
                },
              ),
            if (contact['email'] != null)
              ListTile(
                leading: const Icon(Icons.mail, color: Colors.blue),
                title: const Text('Envoyer un email'),
                onTap: () {
                  Get.back();
                  _sendEmail(contact['email'].toString());
                },
              ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.orange),
              title: const Text('Modifier'),
              onTap: () {
                Get.back();
                Get.snackbar('Modifier', 'Fonctionnalité à venir');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Supprimer'),
              onTap: () async {
                Get.back();

                final id = contact['id'];
                if (id is! int) {
                  Get.snackbar(
                    'Erreur',
                    'ID contact invalide',
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                  );
                  return;
                }

                await DBService.delete('contacts', where: 'id = ?', whereArgs: [id]);

                Get.snackbar(
                  '✅ Supprimé',
                  'Contact supprimé',
                  backgroundColor: Colors.orange,
                  colorText: Colors.white,
                );

                await _loadContactsFromDb();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _makeCall(String phone) async {
    final Uri uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      Get.snackbar(
        '❌ Erreur',
        'Impossible d\'appeler ce numéro',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _sendEmail(String email) async {
    final Uri uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      Get.snackbar(
        '❌ Erreur',
        'Impossible d\'envoyer un email',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}
