import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/mongodb_service.dart';
import 'login_page.dart';
import '../services/vector_tile_provider.dart';
import '../services/mapy_cz_download_service.dart';
import 'package:latlong2/latlong.dart';
import '../services/offline_ui_bridge.dart';
import '../widgets/ui/glass_ui.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    return GlassScaffold(
      body: Column(
        children: [
          // Header with Back Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Nastavení',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                children: [
                  // User profile section
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: const Color(0xFF4CAF50).withOpacity(0.1),
                          backgroundImage: user?.image != null ? NetworkImage(user!.image!) : null,
                          child: user?.image == null
                              ? const Icon(Icons.person, color: Color(0xFF4CAF50), size: 40)
                              : null,
                        ),
                        const SizedBox(height: 16),
                        if (user != null) ...[
                          Text(
                            user.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.email,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ] else ...[
                          const Text(
                            'Nepřihlášen',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Přihlaste se pro přístup ke všem funkcím',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Settings options
                  if (user != null) ...[
                    _buildSettingsSection(
                      title: 'Účet',
                      items: [
                        _buildSettingsItem(
                          icon: Icons.edit,
                          title: 'Upravit profil',
                          subtitle: 'Změnit jméno a jméno psa',
                          onTap: () {
                            _showEditProfileSheet(context);
                          },
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    _buildSettingsSection(
                      title: 'Aplikace',
                      items: [
                        _buildSettingsItem(
                          icon: Icons.storage_rounded,
                          title: 'Offline mapy',
                          subtitle: 'Správa cache, pokrytí, stažení oblastí',
                          onTap: () {
                            _showOfflineMapsSheet(context);
                          },
                        ),
                        _buildSettingsItem(
                          icon: Icons.info,
                          title: 'O aplikaci',
                          subtitle: 'Verze aplikace a informace',
                          onTap: () {
                            showAboutDialog(
                              context: context,
                              applicationName: 'Strakatá Turistika',
                              applicationVersion: '1.1.0',
                              applicationIcon: const Icon(Icons.hiking),
                            );
                          },
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Sign out button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: GlassCard(
                        onTap: () async {
                          await AuthService.signOut();
                          if (context.mounted) {
                            Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                          }
                        },
                        borderRadius: 16,
                        padding: EdgeInsets.zero,
                        child: Container(
                          alignment: Alignment.center,
                          color: Colors.red.withOpacity(0.1),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.logout, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Odhlásit se',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Sign in button for non-authenticated users
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: GlassCard(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginPage()),
                          );
                        },
                        borderRadius: 16,
                        padding: EdgeInsets.zero,
                        child: Container(
                          alignment: Alignment.center,
                          color: const Color(0xFF4CAF50).withOpacity(0.1),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.login, color: Color(0xFF4CAF50)),
                              SizedBox(width: 8),
                              Text(
                                'Přihlásit se',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4CAF50),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    _buildSettingsSection(
                      title: 'Aplikace',
                      items: [
                        _buildSettingsItem(
                          icon: Icons.info,
                          title: 'O aplikaci',
                          subtitle: 'Verze aplikace a informace',
                          onTap: () {
                            showAboutDialog(
                              context: context,
                              applicationName: 'Strakatá Turistika',
                              applicationVersion: '1.1.0',
                              applicationIcon: const Icon(Icons.hiking),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showOfflineMapsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        // consume external open requests
        OfflineUiBridge.consumeOpenManager();
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Offline mapy', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              FutureBuilder<Map<String, dynamic>>(
                future: VectorTileProvider.getDetailedStats(),
                builder: (context, snap) {
                  final stats = snap.data ?? {};
                  final total = stats['totalTiles'] ?? 0;
                  final bytes = stats['totalCompressedBytes'] ?? 0;
                  final mb = (bytes is int) ? (bytes / 1024 / 1024).toStringAsFixed(1) : '0.0';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dlaždice v cache: $total'),
                      const SizedBox(height: 4),
                      Text('Velikost: $mb MB'),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              const Text('Rychlé stažení oblastí', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      // Czech Republic center band sample preset
                      final sw = const LatLng(48.9, 12.3);
                      final ne = const LatLng(50.6, 16.0);
                      await MapyCzDownloadService.downloadBounds(
                        southwest: sw,
                        northeast: ne,
                        minZoom: 8,
                        maxZoom: 12,
                        concurrency: 24,
                        batchSize: 800,
                      );
                      if (context.mounted) Navigator.of(ctx).pop();
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Stáhnout střed ČR (z8–12)'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      // Prague area preset
                      final sw = const LatLng(49.95, 14.15);
                      final ne = const LatLng(50.25, 14.75);
                      await MapyCzDownloadService.downloadBounds(
                        southwest: sw,
                        northeast: ne,
                        minZoom: 10,
                        maxZoom: 15,
                        concurrency: 24,
                        batchSize: 800,
                      );
                      if (context.mounted) Navigator.of(ctx).pop();
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Praha (z10–15)'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      await MapyCzDownloadService.clearCache();
                      if (context.mounted) Navigator.of(ctx).pop();
                    },
                    icon: const Icon(Icons.cleaning_services_outlined),
                    label: const Text('Vyčistit cache'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Zavřít'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditProfileSheet(BuildContext context) {
    final user = AuthService.currentUser;
    final nameController = TextEditingController(text: user?.name ?? '');
    final dogNameController = TextEditingController(text: user?.dogName ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Upravit profil', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Jméno',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dogNameController,
                decoration: const InputDecoration(
                  labelText: 'Jméno psa',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Zrušit'),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () async {
                      final u = AuthService.currentUser;
                      if (u == null) {
                        Navigator.of(ctx).pop();
                        return;
                      }
                      final newName = nameController.text.trim();
                      final newDogName = dogNameController.text.trim();
                      bool ok = true;
                      try {
                        await _updateUserName(u.id, newName.isEmpty ? u.name : newName);
                        await AuthService.updateUserDogName(u.id, newDogName);
                      } catch (_) {
                        ok = false;
                      }
                      if (context.mounted) {
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok ? '✅ Profil uložen' : '❌ Nepodařilo se uložit profil'),
                            backgroundColor: ok ? const Color(0xFF4CAF50) : Colors.red,
                          ),
                        );
                      }
                    },
                    child: const Text('Uložit'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDisplayNameDialog(BuildContext context) {
    final controller = TextEditingController(text: AuthService.currentUser?.name ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zobrazované jméno'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Jméno',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Zrušit')),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              final user = AuthService.currentUser;
              if (user != null && newName.isNotEmpty) {
                await _updateUserName(user.id, newName);
                // ignore: use_build_context_synchronously
                Navigator.pop(ctx);
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Jméno aktualizováno')),
                );
              }
            },
            child: const Text('Uložit'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateUserName(String userId, String name) async {
    try {
      final users = await MongoDBService.getCollection('User');
      if (users != null) {
        await users.updateOne({'_id': userId}, {
          '\$set': {
            'name': name,
            'updatedAt': DateTime.now().toIso8601String(),
          }
        });
      }
      // update in-memory user
      final u = AuthService.currentUser;
      if (u != null) {
        final updated = User(
          id: u.id,
          email: u.email,
          name: name,
          image: u.image,
          isOAuth: u.isOAuth,
          provider: u.provider,
          providerAccountId: u.providerAccountId,
          role: u.role,
          isTwoFactorEnabled: u.isTwoFactorEnabled,
          dogName: u.dogName,
        );
        // Persist via session helper
        // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
        // Store back using same mechanism
        // This mirrors AuthService._saveSessionToStorage but we cannot call it here directly
        // so we re-use public sign-in persistence by setting the static field and calling saver
        // Note: this relies on current structure of AuthService
        // ignore: invalid_use_of_visible_for_testing_member
        // Assign
        // Dart has no access modifier, but we avoid importing private helpers
        // Instead update SharedPreferences directly
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_session', jsonEncode(updated.toMap()));
        // ignore: avoid_print
        print('✅ Updated display name in session');
      }
    } catch (e) {
      // ignore: avoid_print
      print('❌ Failed to update user name: $e');
    }
  }

  Widget _buildSettingsSection({
    required String title,
    required List<Widget> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 16),
        ...items,
      ],
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF4CAF50),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFF9CA3AF),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showDogNameDialog(BuildContext context, String currentDogName) {
    final dogNameController = TextEditingController(text: currentDogName);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.pets,
                  color: Color(0xFF4CAF50),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Jméno psa',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Zadejte jméno svého psa pro personalizaci vašeho zážitku',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: dogNameController,
                decoration: InputDecoration(
                  labelText: 'Jméno psa',
                  hintText: 'Zadejte jméno svého psa',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFFAFAFA),
                  prefixIcon: const Icon(
                    Icons.pets,
                    color: Color(0xFF4CAF50),
                  ),
                ),
                textCapitalization: TextCapitalization.words,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Zrušit',
                style: TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 16,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final newDogName = dogNameController.text.trim();
                final currentUser = AuthService.currentUser;
                
                if (currentUser != null) {
                  final success = await AuthService.updateUserDogName(
                    currentUser.id,
                    newDogName,
                  );
                  
                  Navigator.of(context).pop();
                  
                  if (success) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                            content: Text(
                              newDogName.isEmpty 
                                ? '✅ Jméno psa odstraněno'
                                : '✅ Jméno psa aktualizováno na "$newDogName"',
                            ),
                          backgroundColor: const Color(0xFF4CAF50),
                        ),
                      );
                      // Refresh the page to show updated dog name
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const SettingsPage()),
                      );
                    }
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                            content: Text('❌ Nepodařilo se aktualizovat jméno psa'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Uložit',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}