import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_card.dart';
import '../../../../core/widgets/jn_button.dart';
import '../../../../core/widgets/jn_avatar.dart';
import '../../../../core/widgets/jn_badge.dart';

class AdminUserProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const AdminUserProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<AdminUserProfileScreen> createState() => _AdminUserProfileScreenState();
}

class _AdminUserProfileScreenState extends ConsumerState<AdminUserProfileScreen> {
  Future<void> _updateStatus(String status, String userName) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
        'status': status,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Estado de $userName actualizado a $status'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _updateRole(String role, String? category, String userName) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
        'role': role,
        'category': category,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rol de $userName actualizado a $role'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _deleteUser(String userName) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Usuario "$userName" eliminado con éxito.'),
            backgroundColor: AppColors.warning,
          ),
        );
        Navigator.pop(context); // Go back after delete
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al borrar usuario: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showRoleDialog(Map<String, dynamic> data) {
    String selectedRole = data['role'] ?? 'padre';
    String? selectedCategory = data['category'];
    final roles = ['padre', 'jugador', 'dt', 'secretario', 'directivo'];
    final categories = ['Sub-12', 'Sub-14', 'Sub-16', 'Sub-18', 'Primera'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Cambiar Rol'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(labelText: 'Rol'),
                  items: roles.map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase()))).toList(),
                  onChanged: (v) {
                    setState(() {
                      selectedRole = v!;
                      if (selectedRole == 'directivo' || selectedRole == 'secretario') {
                        selectedCategory = null;
                      } else {
                        selectedCategory ??= 'Sub-12';
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (selectedRole != 'directivo' && selectedRole != 'secretario')
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(labelText: 'Categoría'),
                    items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) {
                      setState(() {
                        selectedCategory = v;
                      });
                    },
                  ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _updateRole(selectedRole, selectedCategory, '${data['name']} ${data['lastName']}');
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Perfil de Usuario'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Usuario no encontrado'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final name = data['name'] ?? '';
          final lastName = data['lastName'] ?? '';
          final email = data['email'] ?? '';
          final phone1 = data['phone1'] ?? 'No especificado';
          final role = data['role'] ?? 'padre';
          final category = data['category'];
          final status = data['status'] ?? 'active';

          final isPending = status == 'pending_approval';
          final isDisabled = status == 'disabled';
          
          final hasPersonalData = data['dni'] != null || data['birthDate'] != null || data['height'] != null || data['weight'] != null;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              JNCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    JNAvatar(name: '$name $lastName', size: 80),
                    const SizedBox(height: 16),
                    Text('$name $lastName', style: AppTypography.headlineMedium),
                    Text(email, style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        JNBadge(label: role.toUpperCase(), type: JNBadgeType.neutral),
                        if (category != null) JNBadge(label: category, type: JNBadgeType.accent),
                        if (isPending) JNBadge(label: 'PENDIENTE', type: JNBadgeType.warning),
                        if (isDisabled) JNBadge(label: 'BLOQUEADO', type: JNBadgeType.error),
                        if (status == 'active') JNBadge(label: 'ACTIVO', type: JNBadgeType.success),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              if (hasPersonalData) ...[
                Text('Datos Personales', style: AppTypography.titleLarge),
                const SizedBox(height: 12),
                JNCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (data['dni'] != null && data['dni'].toString().isNotEmpty)
                        ListTile(
                          leading: const Icon(Icons.badge_outlined),
                          title: const Text('DNI'),
                          subtitle: Text(data['dni'].toString()),
                        ),
                      if (data['birthDate'] != null && data['birthDate'].toString().isNotEmpty)
                        ListTile(
                          leading: const Icon(Icons.cake_outlined),
                          title: const Text('Fecha de Nacimiento'),
                          subtitle: Text(data['birthDate'] is Timestamp 
                            ? (data['birthDate'] as Timestamp).toDate().toString().split(' ')[0] 
                            : data['birthDate'].toString()),
                        ),
                      if (data['height'] != null && data['height'].toString().isNotEmpty)
                        ListTile(
                          leading: const Icon(Icons.height_outlined),
                          title: const Text('Altura'),
                          subtitle: Text('${data['height']} cm'),
                        ),
                      if (data['weight'] != null && data['weight'].toString().isNotEmpty)
                        ListTile(
                          leading: const Icon(Icons.scale_outlined),
                          title: const Text('Peso'),
                          subtitle: Text('${data['weight']} kg'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              Text('Datos de Contacto', style: AppTypography.titleLarge),
              const SizedBox(height: 12),
              JNCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.phone),
                      title: const Text('Teléfono Principal'),
                      subtitle: Text(phone1),
                    ),
                    if (data['phone2'] != null && data['phone2'].toString().isNotEmpty)
                      ListTile(
                        leading: const Icon(Icons.phone_android),
                        title: const Text('Teléfono Secundario'),
                        subtitle: Text(data['phone2']),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Text('Acciones de Administrador', style: AppTypography.titleLarge),
              const SizedBox(height: 12),
              JNCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isPending)
                      JNButton(
                        label: 'Aprobar Ingreso',
                        onPressed: () => _updateStatus('active', '$name $lastName'),
                        variant: JNButtonVariant.success,
                      ),
                    if (!isPending) const SizedBox(height: 12),
                    if (isDisabled)
                      JNButton(
                        label: 'Desbloquear Usuario',
                        onPressed: () => _updateStatus('active', '$name $lastName'),
                        variant: JNButtonVariant.outline,
                      )
                    else
                      JNButton(
                        label: 'Bloquear Usuario',
                        onPressed: () => _updateStatus('disabled', '$name $lastName'),
                        variant: JNButtonVariant.primary,
                      ),
                    const SizedBox(height: 12),
                    JNButton(
                      label: 'Cambiar Rol',
                      onPressed: () => _showRoleDialog(data),
                      variant: JNButtonVariant.outline,
                    ),
                    const SizedBox(height: 12),
                    JNButton(
                      label: 'Eliminar Cuenta',
                      onPressed: () {
                        if (email == 'munozalbelonicolas@gmail.com') {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No puedes eliminar al administrador principal'), backgroundColor: AppColors.error));
                          return;
                        }
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('¿Eliminar cuenta?'),
                            content: const Text('Esta acción es irreversible.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _deleteUser('$name $lastName');
                                },
                                child: const Text('Eliminar', style: TextStyle(color: AppColors.error)),
                              ),
                            ],
                          ),
                        );
                      },
                      variant: JNButtonVariant.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (role == 'padre' || role == 'tutor') ...[
                Text('Jugadores a cargo', style: AppTypography.titleLarge),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').where('tutorId', isEqualTo: widget.userId).snapshots(),
                  builder: (context, playersSnapshot) {
                    if (!playersSnapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final players = playersSnapshot.data!.docs;
                    if (players.isEmpty) return const Text('No tiene jugadores registrados.');
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: players.length,
                      itemBuilder: (context, i) {
                        final p = players[i].data() as Map<String, dynamic>;
                        return JNCard(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: JNAvatar(name: p['fullName'] ?? 'Jugador', size: 40),
                            title: Text(p['fullName'] ?? ''),
                            subtitle: Text('DNI: ${p['dni']} · ${p['category']}'),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
