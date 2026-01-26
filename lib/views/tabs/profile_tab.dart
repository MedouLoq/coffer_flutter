import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/vault_controller.dart';
import '../../services/secure_storage_service.dart';
import '../../services/api_service.dart';
import '../../views/setup_password_view.dart';
import '../../widgets/pin_setup_view.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  String? _userEmail;
  String? _userName;
  final VaultController _vaultController = Get.find();

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final email = await SecureStorageService.getUserEmail();
    setState(() {
      _userEmail = email;
      _userName = email?.split('@')[0] ?? 'Utilisateur';
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // En-tête profil
          _buildProfileHeader(),

          const SizedBox(height: 20),

          // Section Sécurité
          _buildSection(
            'Sécurité',
            [
              _buildMenuItem(
                Icons.vpn_key,
                'Changer le mot de passe coffre',
                'Modifier votre mot de passe maître',
                Colors.blue,
                _changeVaultPassword,
              ),
              _buildMenuItem(
                Icons.pin,
                'Code PIN',
                'Configurer un code PIN pour la lecture',
                Colors.purple,
                () => Get.to(() => const PinSetupView()),
              ),
              _buildMenuItem(
                Icons.shield,
                'Authentification à 2 facteurs',
                'Ajouter une couche de sécurité',
                Colors.green,
                () => Get.snackbar('2FA', 'Fonctionnalité à venir'),
              ),
            ],
          ),

          // Section Données
          _buildSection(
            'Données',
            [
              _buildMenuItem(
                Icons.sync,
                'Synchroniser maintenant',
                'Forcer la synchronisation',
                Colors.blue,
                _syncNow,
              ),
              _buildMenuItem(
                Icons.backup,
                'Exporter les données',
                'Créer une sauvegarde chiffrée',
                Colors.orange,
                () => Get.snackbar('Export', 'Fonctionnalité à venir'),
              ),
              _buildMenuItem(
                Icons.restore,
                'Importer des données',
                'Restaurer depuis une sauvegarde',
                Colors.cyan,
                () => Get.snackbar('Import', 'Fonctionnalité à venir'),
              ),
            ],
          ),

          // Section Paramètres
          _buildSection(
            'Paramètres',
            [
              _buildMenuItem(
                Icons.language,
                'Langue',
                'Français',
                Colors.indigo,
                _changeLanguage,
              ),
              _buildMenuItem(
                Icons.dark_mode,
                'Thème',
                'Clair / Sombre',
                Colors.grey,
                () => Get.snackbar('Thème', 'Fonctionnalité à venir'),
              ),
              _buildMenuItem(
                Icons.notifications,
                'Notifications',
                'Gérer les notifications',
                Colors.amber,
                () => Get.snackbar('Notifications', 'Fonctionnalité à venir'),
              ),
            ],
          ),

          // Section Compte
          _buildSection(
            'Compte',
            [
              _buildMenuItem(
                Icons.info,
                'À propos',
                'Version 1.0.0',
                Colors.blue,
                _showAbout,
              ),
              _buildMenuItem(
                Icons.help,
                'Aide & Support',
                'Besoin d\'aide ?',
                Colors.green,
                () => Get.snackbar('Support', 'Fonctionnalité à venir'),
              ),
              _buildMenuItem(
                Icons.logout,
                'Déconnexion',
                'Se déconnecter du compte',
                Colors.red,
                _logout,
              ),
            ],
          ),

          // Section Danger
          _buildSection(
            'Zone de danger',
            [
              _buildMenuItem(
                Icons.warning,
                'Réinitialiser le coffre',
                'Supprimer toutes les données',
                Colors.red,
                _resetVault,
              ),
            ],
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 50,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.person,
              size: 50,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _userName ?? 'Utilisateur',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _userEmail ?? 'email@example.com',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_user, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text(
                  'Compte vérifié',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(children: items),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  void _changeVaultPassword() {
    Get.snackbar(
      'Changement de mot de passe',
      'Cette fonctionnalité nécessite de déverrouiller d\'abord le vault',
      backgroundColor: Colors.orange,
      colorText: Colors.white,
    );
    
    // TODO: Implémenter le changement de mot de passe maître
    // Nécessite: vérifier ancien password, dériver nouvelle clé, re-chiffrer toutes les données
  }

  Future<void> _syncNow() async {
    Get.dialog(
      const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Synchronisation en cours...'),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );

    try {
      await _vaultController.syncWithServer();
      Get.back();
    } catch (e) {
      Get.back();
      Get.snackbar(
        '❌ Erreur',
        'Sync échouée: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _changeLanguage() {
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
              'Choisir la langue',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Text('🇫🇷', style: TextStyle(fontSize: 32)),
              title: const Text('Français'),
              onTap: () => Get.back(),
            ),
            ListTile(
              leading: const Text('🇬🇧', style: TextStyle(fontSize: 32)),
              title: const Text('English'),
              onTap: () {
                Get.back();
                Get.snackbar('Langue', 'Fonctionnalité à venir');
              },
            ),
            ListTile(
              leading: const Text('🇸🇦', style: TextStyle(fontSize: 32)),
              title: const Text('العربية'),
              onTap: () {
                Get.back();
                Get.snackbar('Langue', 'Fonctionnalité à venir');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'Vault Secure',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.lock, size: 48, color: Colors.blue),
      children: const [
        Text('Application de coffre-fort sécurisé avec chiffrement zero-knowledge.'),
        SizedBox(height: 10),
        Text('© 2026 Vault Secure. Tous droits réservés.'),
      ],
    );
  }

  void _logout() {
    Get.dialog(
      AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              
              // Verrouiller le vault
              await _vaultController.logout();
              
              // Supprimer les tokens
              await SecureStorageService.clearAuthOnly();
              
              // Rediriger vers login
              Get.offAllNamed('/login');
              
              Get.snackbar(
                '👋 À bientôt',
                'Vous êtes déconnecté',
                backgroundColor: Colors.blue,
                colorText: Colors.white,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }

  void _resetVault() {
    Get.dialog(
      AlertDialog(
        title: const Text('⚠️ DANGER'),
        content: const Text(
          'Cette action supprimera TOUTES vos données de manière irréversible. Êtes-vous absolument sûr ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              await _vaultController.resetVault();
              Get.offAllNamed('/login');
              Get.snackbar(
                '💥 Vault réinitialisé',
                'Toutes les données ont été supprimées',
                backgroundColor: Colors.red,
                colorText: Colors.white,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('TOUT SUPPRIMER'),
          ),
        ],
      ),
    );
  }
}