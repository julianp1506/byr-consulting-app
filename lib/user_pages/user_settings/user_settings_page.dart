import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:namer_app/user_pages/user_settings/user_account_info_page.dart';
import 'package:namer_app/user_pages/user_settings/user_contact_page.dart';
import 'package:namer_app/user_pages/user_settings/user_help_center_page.dart';
import 'package:namer_app/user_pages/user_settings/user_more_info_page.dart';

class UserSettingsPage extends StatefulWidget {
  const UserSettingsPage({Key? key}) : super(key: key);

  @override
  State<UserSettingsPage> createState() => _UserSettingsPageState();
}

class _UserSettingsPageState extends State<UserSettingsPage> {
  final Color _mainOrange = const Color(0xFFFF8902);
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  /// Stream que observa en tiempo real el documento de usuario
  Stream<DocumentSnapshot> get _userDocStream {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .snapshots();
  }

  /// Lógica de logout con confirmación
  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('confirm_logout'.tr()),
        content: Text('are_you_sure_logout'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            child: Text('Logout'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  /// Cambia el idioma entre inglés y español
  void _toggleLanguage(BuildContext context) {
    final currentLocale = context.locale;
    if (currentLocale.languageCode == 'es') {
      context.setLocale(const Locale('en'));
    } else {
      context.setLocale(const Locale('es'));
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('language_changed'.tr()),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F3),
      appBar: AppBar(
        toolbarHeight: 50,
        backgroundColor: _mainOrange,
        title: Text(
          'settings'.tr(),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Image.asset('assets/logo_white.png', height: 40),
          ),
        ],
      ),
      body: Column(
        children: [
          // ===== Datos de usuario (StreamBuilder) =====
          StreamBuilder<DocumentSnapshot>(
            stream: _userDocStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
              final firstName = data['firstName'] ?? 'first_name'.tr();
              final lastName = data['lastName'] ?? 'last_name'.tr();
              final photoUrl = data['photoUrl'] as String?;

              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundImage: photoUrl != null
                              ? NetworkImage(photoUrl)
                              : const AssetImage('assets/worker_avatar.jpg')
                                  as ImageProvider,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () {
                              // Opcional: Abrir ImagePicker para cambiar foto de perfil
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: _mainOrange,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    title: Text(
                      '$firstName $lastName',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      'Worker'.tr(),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserAccountInfoPage(),
                        ),
                      );
                      // El StreamBuilder recargará automáticamente si cambian datos
                    },
                  ),
                ),
              );
            },
          ),

          // ===== Lista de opciones agrupadas por secciones =====
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // ----- Sección: Cuenta -----
                Text(
                  'account'.tr(),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _buildOption(
                  icon: Icons.person,
                  title: 'Account info'.tr(),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UserAccountInfoPage(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // ----- Sección: Preferencias -----
                Text(
                  'preferences'.tr(),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _buildOption(
                  icon: Icons.language,
                  title: 'language'.tr(),
                  onTap: () => _toggleLanguage(context),
                ),

                const SizedBox(height: 16),

                // ----- Sección: Soporte / Ayuda -----
                Text(
                  'support'.tr(),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _buildOption(
                  icon: Icons.help_outline,
                  title: 'Help center'.tr(),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UserHelpCenterPage(),
                      ),
                    );
                    // Implementar navegación a centro de ayuda
                  },
                ),
                _buildOption(
                  icon: Icons.contact_mail,
                  title: 'Contact us'.tr(),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UserContactPage(),
                      ),
                    );
                  },
                ),
                _buildOption(
                  icon: Icons.info_outline,
                  title: 'More information'.tr(),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UserMoreInfoPage(),
                      ),
                    );
                    // Implementar navegación a centro de ayuda
                  },
                ),

                const SizedBox(height: 32),

                // ----- Botón de Cerrar Sesión -----
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _confirmLogout(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _mainOrange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Logout'.tr(),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Construye cada opción con ícono, texto y chevron
  Widget _buildOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: _mainOrange),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey[800],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
