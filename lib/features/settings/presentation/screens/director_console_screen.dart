import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_avatar.dart';
import '../../../../core/widgets/jn_badge.dart';
import '../../../../core/widgets/jn_button.dart';
import '../../../../core/widgets/jn_card.dart';
import '../../../player/presentation/screens/consolidated_roster_screen.dart';
import '../../../results/presentation/screens/manage_scorers_screen.dart';
import '../widgets/admin_notifications_dialog.dart';
import 'admin_user_profile_screen.dart';
import 'birthdays_of_month_screen.dart';
import 'manage_categories_screen.dart';
import 'manage_quotas_screen.dart';

class DirectorConsoleScreen extends ConsumerStatefulWidget {
  const DirectorConsoleScreen({super.key});

  @override
  ConsumerState<DirectorConsoleScreen> createState() => _DirectorConsoleScreenState();
}

class _DirectorConsoleScreenState extends ConsumerState<DirectorConsoleScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;
  late Stream<QuerySnapshot> _usersStream;

  @override
  void initState() {
    super.initState();
    _usersStream = FirebaseFirestore.instance.collection('users').snapshots();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _approveUser(
    BuildContext context,
    String userId,
    String userName,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'status': 'active'});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Usuario "$userName" aprobado con éxito.'),
            backgroundColor: context.colors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al aprobar usuario: $e'),
            backgroundColor: context.colors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteUser(
    BuildContext context,
    String userId,
    String userName,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Usuario "$userName" eliminado con éxito.'),
            backgroundColor: context.colors.warning,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al borrar usuario: $e'),
            backgroundColor: context.colors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Consola del Director'),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('read', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data?.docs.length ?? 0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () => showAdminNotificationsDialog(context),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: context.colors.error,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _usersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error al cargar datos: ${snapshot.error}',
                style: TextStyle(color: context.colors.error),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          final filteredDocs = docs.where((doc) {
            if (_searchQuery.isEmpty) return true;
            final data = doc.data() as Map<String, dynamic>;
            final String name = data['name']?.toString().toLowerCase() ?? '';
            final String lastName = data['lastName']?.toString().toLowerCase() ?? '';
            final String email = data['email']?.toString().toLowerCase() ?? '';
            return name.contains(_searchQuery) ||
                   lastName.contains(_searchQuery) ||
                   email.contains(_searchQuery);
          }).toList();

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
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: JNCard(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ManageScorersScreen()),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.sports_soccer, color: context.colors.primary, size: 28),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Goleadores por Categoría', style: context.typography.titleMedium),
                              Text('Gestionar tabla de goleadores', style: context.typography.bodySmall),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: context.colors.textTertiary),
                      ],
                    ),
                  ),
                ),
              ),
              
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: JNCard(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ManageCategoriesScreen()),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.category, color: context.colors.primary, size: 28),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Gestionar Categorías', style: context.typography.titleMedium),
                              Text('Crear o eliminar categorías', style: context.typography.bodySmall),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: context.colors.textTertiary),
                      ],
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: JNCard(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ManageQuotasScreen()),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.monetization_on, color: context.colors.primary, size: 28),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Estado de Cuotas', style: context.typography.titleMedium),
                              Text('Ver quiénes deben cuotas', style: context.typography.bodySmall),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: context.colors.textTertiary),
                      ],
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: JNCard(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ConsolidatedRosterScreen()),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.list_alt, color: context.colors.primary, size: 28),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Consolidado de Jugadores', style: context.typography.titleMedium),
                              Text('Listado completo y exportación a Excel', style: context.typography.bodySmall),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: context.colors.textTertiary),
                      ],
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: JNCard(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const BirthdaysOfMonthScreen()),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.cake, color: context.colors.primary, size: 28),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Cumpleaños del Mes', style: context.typography.titleMedium),
                              Text('Consultar cumpleaños de los jugadores', style: context.typography.bodySmall),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: context.colors.textTertiary),
                      ],
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Usuarios Registrados (${filteredDocs.length})',
                        style: context.typography.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        style: context.typography.bodyMedium,
                        decoration: const InputDecoration(
                          hintText: 'Buscar por nombre, apellido o email...',
                          prefixIcon: Icon(Icons.search, size: 20),
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                        onChanged: (val) {
                          if (_debounce?.isActive ?? false) _debounce!.cancel();
                          _debounce = Timer(const Duration(milliseconds: 500), () {
                            if (mounted) {
                              setState(() {
                                _searchQuery = val.toLowerCase();
                              });
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

              if (filteredDocs.isEmpty)
                SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: context.colors.textTertiary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No hay usuarios registrados',
                            style: context.typography.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Aún no hay usuarios registrados.',
                            textAlign: TextAlign.center,
                            style: context.typography.bodyMedium.copyWith(
                              color: context.colors.textSecondary,
                            ),
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
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final doc = filteredDocs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final String userId = doc.id;
                      final String name = data['name'] ?? '';
                      final String lastName = data['lastName'] ?? '';
                      final String email = data['email'] ?? '';
                      final String role = data['role'] ?? 'tutor';
                      final String? category = data['category'];
                      final String status = data['status'] ?? 'active';
                      final bool isPending = status == 'pending_approval';
                      final bool hasDebt = data['hasPendingDebt'] ?? false;

                      // Physical fitness status
                      final Timestamp? expiryTimestamp =
                          data['aptoFisicoExpiry'] as Timestamp?;
                      final DateTime? expiry = expiryTimestamp?.toDate();

                      bool hasAptoWarning = false;
                      bool hasAptoExpired = false;

                      if (expiry == null) {
                        hasAptoWarning = true;
                      } else {
                        hasAptoExpired = expiry.isBefore(DateTime.now());
                        hasAptoWarning =
                            hasAptoExpired ||
                            expiry.difference(DateTime.now()).inDays <= 30;
                      }

                      return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AdminUserProfileScreen(userId: userId),
                                  ),
                                );
                              },
                              child: JNCard(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  JNAvatar(name: '$name $lastName', size: 40),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$name $lastName',
                                          style: context.typography.titleMedium,
                                        ),
                                        Text(
                                          email,
                                          style: context.typography.bodySmall
                                              .copyWith(
                                                color: context.colors.textTertiary,
                                              ),
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            if (isPending)
                                              const JNBadge(
                                                label: 'PENDIENTE',
                                                type: JNBadgeType.accent,
                                                small: true,
                                              ),
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
                                              JNBadge(
                                                label: category,
                                                small: true,
                                              ),
                                            if (hasDebt)
                                              const JNBadge(
                                                label: 'DEUDA',
                                                type: JNBadgeType.error,
                                                small: true,
                                              ),
                                            if (expiry == null)
                                              const JNBadge(
                                                label: 'SIN APTO',
                                                type: JNBadgeType.error,
                                                small: true,
                                              )
                                            else if (hasAptoExpired)
                                              const JNBadge(
                                                label: 'APTO VENCIDO',
                                                type: JNBadgeType.error,
                                                small: true,
                                              )
                                            else if (hasAptoWarning)
                                              const JNBadge(
                                                label: 'APTO X VENCER',
                                                type: JNBadgeType.accent,
                                                small: true,
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isPending)
                                        IconButton(
                                          icon: Icon(
                                            Icons.check_circle_outline,
                                            color: context.colors.success,
                                          ),
                                          tooltip: 'Aprobar',
                                          onPressed: () => _approveUser(
                                            context,
                                            userId,
                                            '$name $lastName',
                                          ),
                                        ),
                                      // Delete user button
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete_outline,
                                      color: context.colors.error,
                                    ),
                                    onPressed: () {
                                      // Prevent Director from deleting themselves
                                      if (email ==
                                          'munozalbelonicolas@gmail.com') {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: const Text(
                                              'El Director no puede ser eliminado.',
                                            ),
                                            backgroundColor: context.colors.error,
                                          ),
                                        );
                                        return;
                                      }

                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          backgroundColor: context.colors.surface,
                                          title: const Text('Eliminar Usuario'),
                                          content: Text(
                                            '¿Estás seguro de que deseas eliminar a "$name $lastName" de la base de datos?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: Text(
                                                'Cancelar',
                                                style: TextStyle(
                                                  color:
                                                      context.colors.textSecondary,
                                                ),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.pop(context);
                                                _deleteUser(
                                                  context,
                                                  userId,
                                                  '$name $lastName',
                                                );
                                              },
                                              child: Text(
                                                'Eliminar',
                                                style: TextStyle(
                                                  color: context.colors.error,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                          .animate(delay: (index * 40).ms)
                          .fadeIn(duration: 300.ms)
                          .slideY(begin: 0.05);
                    }, childCount: docs.length),
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
  State<_SupportEmailConfigCard> createState() =>
      _SupportEmailConfigCardState();
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
        SnackBar(
          content: const Text('Por favor ingresa un correo electrónico válido'),
          backgroundColor: context.colors.error,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('config')
          .doc('support_settings')
          .set({
            'support_email': email,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Correo de soporte actualizado con éxito'),
            backgroundColor: context.colors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: context.colors.error,
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
      stream: FirebaseFirestore.instance
          .collection('config')
          .doc('support_settings')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data != null &&
              data['support_email'] != null &&
              !_isSaving &&
              _emailController.text.isEmpty) {
            _emailController.text = data['support_email'];
          }
        }

        return JNCard(
          padding: const EdgeInsets.all(16),
          border: Border.all(color: context.colors.primary.withValues(alpha: 0.15)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.mark_email_read,
                    color: context.colors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Configuración de Soporte',
                    style: context.typography.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Define la dirección de correo electrónico a la que llegarán las consultas de ayuda y soporte técnico de los usuarios.',
                style: context.typography.bodySmall,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _emailController,
                      style: context.typography.bodyMedium,
                      decoration: const InputDecoration(
                        labelText: 'Email de Soporte',
                        hintText: 'ejemplo@club.com',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
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