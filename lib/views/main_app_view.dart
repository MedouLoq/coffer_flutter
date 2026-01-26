import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/main_controller.dart';
import '../controllers/vault_controller.dart';

// Import des 5 onglets
import 'tabs/documents_tab.dart';
import 'tabs/events_tab.dart';
import 'tabs/contacts_tab.dart';
import 'tabs/notes_tab.dart';
import 'tabs/profile_tab.dart';

class MainAppView extends StatelessWidget {
  final MainController mainController = Get.find();
  final VaultController vaultController = Get.find();

  final List<Widget> _tabs = [
    DocumentsTab(),
    EventsTab(),
    ContactsTab(),
    NotesTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Obx(() => Scaffold(
      appBar: AppBar(
        title: Text(
          mainController.currentTitle,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          // Bouton de synchronisation
          IconButton(
            icon: Icon(Icons.sync),
            onPressed: () {
              // TODO: Implémenter la synchronisation
              Get.snackbar(
                '🔄 Synchronisation',
                'Synchronisation en cours...',
                backgroundColor: Colors.blue,
                colorText: Colors.white,
              );
            },
            tooltip: 'Synchroniser',
          ),
          
          // Bouton verrouiller
          IconButton(
            icon: Icon(Icons.lock),
            onPressed: () {
              vaultController.lockVault();
              Get.offAllNamed('/unlock_vault');
            },
            tooltip: 'Verrouiller',
          ),
        ],
      ),
      
      body: _tabs[mainController.currentIndex.value],
      
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: mainController.currentIndex.value,
        onTap: mainController.changeTab,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.description),
            label: 'Documents',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event),
            label: 'Événements',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.contacts),
            label: 'Contacts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.note),
            label: 'Notes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    ));
  }
}