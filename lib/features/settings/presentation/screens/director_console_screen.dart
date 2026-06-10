import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_card.dart';
import '../../../../core/widgets/jn_button.dart';
import '../../../../core/widgets/jn_avatar.dart';
import '../../../../core/widgets/jn_badge.dart';

class DirectorConsoleScreen extends ConsumerWidget {
  const DirectorConsoleScreen({super.key});

  static final List<Map<String, dynamic>> _mockUsers = [
    {
      'id': 'mock_usr_sec_01',
      'name': 'Roberto',
      'lastName': 'Pérez',
      'email': 'secretaria.demo@appclub.com',
      'role': 'secretario',
      'dni': '24123789',
      'age': 52,
      'hasPendingDebt': false,
    },
    {
      'id': 'mock_usr_dt_01',
      'name': 'Pablo',
      'lastName': 'Ramírez',
      'email': 'dt.sub12@appclub.com',
      'role': 'dt',
      'category': 'Sub-12',
      'dni': '30456123',
      'age': 38,
      'hasPendingDebt': false,
    },
    {
      'id': 'mock_usr_dt_02',
      'name': 'Diego',
      'lastName': 'Simeone',
      'email': 'dt.sub14@appclub.com',
      'role': 'dt',
      'category': 'Sub-14',
      'dni': '28456111',
      'age': 45,
      'hasPendingDebt': false,
    },
    {
      'id': 'mock_usr_padre_01',
      'name': 'Carlos',
      'lastName': 'Gutiérrez',
      'email': 'padre.deudor@appclub.com',
      'role': 'padre',
      'category': 'Sub-12',
      'dni': '35123456',
      'age': 40,
      'fatherName': 'Ramón Gutiérrez',
      'motherName': 'Isabel Díaz',
      'hasPendingDebt': true, // Debtor
      'aptoFisicoUrl': 'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?w=100',
      'aptoFisicoExpiry': Timestamp.fromDate(DateTime.now().add(const Duration(days: 10))), // Expiring soon (10 days)
    },
    {
      'id': 'mock_usr_jugador_01',
      'name': 'Juan',
      'lastName': 'Pérez',
      'email': 'jugador.vencido@appclub.com',
      'role': 'jugador',
      'category': 'Sub-12',
      'dni': '45123999',
      'age': 11,
      'fatherName': 'Roberto Pérez',
      'motherName': 'Ana Gómez',
      'hasPendingDebt': false,
      'aptoFisicoUrl': 'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?w=100',
      'aptoFisicoExpiry': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 5))), // Expired (5 days ago)
    },
    {
      'id': 'mock_usr_jugador_02',
      'name': 'Lucas',
      'lastName': 'Díaz',
      'email': 'jugador.sano@appclub.com',
      'role': 'jugador',
      'category': 'Sub-14',
      'dni': '46123888',
      'age': 13,
      'fatherName': 'Mario Díaz',
      'motherName': 'Sofía Romero',
      'hasPendingDebt': false,
      'aptoFisicoUrl': 'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?w=100',
      'aptoFisicoExpiry': Timestamp.fromDate(DateTime.now().add(const Duration(days: 200))), // Active/Ok
    },
  ];

  Future<void> _seedMockData(BuildContext context) async {
    final FirebaseFirestore db = FirebaseFirestore.instance;
    int count = 0;
    try {
      for (final user in _mockUsers) {
        final docRef = db.collection('users').doc(user['id']);
        await docRef.set({
          ...user,
          'createdAt': FieldValue.serverTimestamp(),
        });
        count++;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Se cargaron $count usuarios de prueba en Firestore.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al poblar base de datos: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteUser(BuildContext context, String userId, String userName) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Usuario "$userName" eliminado con éxito.'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al borrar usuario: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Consola del Director'),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add),
            onPressed: () => _seedMockData(context),
            tooltip: 'Cargar Usuarios de Prueba',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar datos: ${snapshot.error}', style: TextStyle(color: AppColors.error)));
          }

          final docs = snapshot.data?.docs ?? [];

          return CustomScrollView(
            slivers: [
              // Support Configuration Card (Visible only to Director/Directivos)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: _SupportEmailConfigCard(),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    'Usuarios Registrados (${docs.length})',
                    style: AppTypography.headlineSmall,
                  ),
                ),
              ),

              if (docs.isEmpty)
                SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.people_outline, size: 64, color: AppColors.textTertiary),
                          const SizedBox(height: 16),
                          Text('No hay usuarios registrados', style: AppTypography.titleLarge),
                          const SizedBox(height: 8),
                          Text(
                            'Pulsa el botón de arriba o el de abajo para poblar la base de datos con usuarios de prueba con deudas y aptos vencidos.',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 24),
                          JNButton(
                            label: 'Poblar Usuarios de Prueba',
                            onPressed: () => _seedMockData(context),
                            icon: Icons.playlist_add,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final String userId = doc.id;
                        final String name = data['name'] ?? '';
                        final String lastName = data['lastName'] ?? '';
                        final String email = data['email'] ?? '';
                        final String role = data['role'] ?? 'padre';
                        final String? category = data['category'];
                        final bool hasDebt = data['hasPendingDebt'] ?? false;
                        
                        // Physical fitness status
                        final Timestamp? expiryTimestamp = data['aptoFisicoExpiry'] as Timestamp?;
                        final DateTime? expiry = expiryTimestamp?.toDate();
                        
                        bool hasAptoWarning = false;
                        bool hasAptoExpired = false;

                        if (expiry == null) {
                          hasAptoWarning = true;
                        } else {
                          hasAptoExpired = expiry.isBefore(DateTime.now());
                          hasAptoWarning = hasAptoExpired || expiry.difference(DateTime.now()).inDays <= 30;
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: JNCard(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                JNAvatar(name: '$name $lastName', size: 40),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('$name $lastName', style: AppTypography.titleMedium),
                                      Text(email, style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          JNBadge(
                                            label: role.toUpperCase(),
                                            type: role == 'directivo'
                                                ? JNBadgeType.error
                                                : role == 'secretario'
                                                    ? JNBadgeType.info
                                                    : role == 'dt'
                                                        ? JNBadgeType.accent
                                                        : JNBadgeType.neutral,
                                            small: true,
                                          ),
                                          if (category != null)
                                            JNBadge(label: category, type: JNBadgeType.neutral, small: true),
                                          if (hasDebt)
                                            const JNBadge(label: 'DEUDA', type: JNBadgeType.error, small: true),
                                          if (expiry == null)
                                            const JNBadge(label: 'SIN APTO', type: JNBadgeType.error, small: true)
                                          else if (hasAptoExpired)
                                            const JNBadge(label: 'APTO VENCIDO', type: JNBadgeType.error, small: true)
                                          else if (hasAptoWarning)
                                            const JNBadge(label: 'APTO X VENCER', type: JNBadgeType.accent, small: true),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Delete user button
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                                  onPressed: () {
                                    // Prevent Director from deleting themselves
                                    if (email == 'munozalbelonicolas@gmail.com') {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('El Director no puede ser eliminado.'),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                      return;
                                    }

                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        backgroundColor: AppColors.surface,
                                        title: const Text('Eliminar Usuario'),
                                        content: Text('¿Estás seguro de que deseas eliminar a "$name $lastName" de la base de datos?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              _deleteUser(context, userId, '$name $lastName');
                                            },
                                            child: const Text('Eliminar', style: TextStyle(color: AppColors.error)),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ).animate(delay: (index * 40).ms).fadeIn(duration: 300.ms).slideY(begin: 0.05);
                      },
                      childCount: docs.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SupportEmailConfigCard extends StatefulWidget {
  const _SupportEmailConfigCard();
  @override
  State<_SupportEmailConfigCard> createState() => _SupportEmailConfigCardState();
}

class _SupportEmailConfigCardState extends State<_SupportEmailConfigCard> {
  final _emailController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingresa un correo electrónico válido'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await FirebaseFirestore.instance.collection('config').doc('support_settings').set({
        'support_email': email,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Correo de soporte actualizado con éxito'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('config').doc('support_settings').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data != null && data['support_email'] != null && !_isSaving && _emailController.text.isEmpty) {
            _emailController.text = data['support_email'];
          }
        }

        return JNCard(
          padding: const EdgeInsets.all(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.mark_email_read, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text('Configuración de Soporte', style: AppTypography.titleLarge),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Define la dirección de correo electrónico a la que llegarán las consultas de ayuda y soporte técnico de los usuarios.',
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _emailController,
                      style: AppTypography.bodyMedium,
                      decoration: const InputDecoration(
                        labelText: 'Email de Soporte',
                        hintText: 'ejemplo@club.com',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : JNButton(
                          label: 'Guardar',
                          onPressed: _saveEmail,
                          size: JNButtonSize.small,
                        ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

