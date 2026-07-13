import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/category_service.dart';

import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_avatar.dart';
import '../../../../core/widgets/jn_badge.dart';
import '../../../../core/widgets/jn_button.dart';
import '../../../../core/widgets/jn_card.dart';

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
            backgroundColor: context.colors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: context.colors.error),
        );
      }
    }
  }

  Future<void> _updateRole(String role, String? category, List<String>? assignedCategories, String userName) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
        'role': role,
        'category': category,
        if (role == 'dt' && assignedCategories != null) 'assignedCategories': assignedCategories,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rol de $userName actualizado a $role'),
            backgroundColor: context.colors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: context.colors.error),
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
            backgroundColor: context.colors.warning,
          ),
        );
        Navigator.pop(context); // Go back after delete
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al borrar usuario: $e'), backgroundColor: context.colors.error),
        );
      }
    }
  }

  Future<void> _deleteLink(String linkId) async {
    try {
      await FirebaseFirestore.instance.collection('player_tutor_links').doc(linkId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Vínculo eliminado con éxito.'),
            backgroundColor: context.colors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar vínculo: $e'), backgroundColor: context.colors.error),
        );
      }
    }
  }

  Stream<List<Map<String, dynamic>>> _fetchPlayerTutors(String playerId) {
    return FirebaseFirestore.instance
        .collection('player_tutor_links')
        .where('playerId', isEqualTo: playerId)
        .snapshots()
        .asyncMap((snapshot) async {
      final List<Map<String, dynamic>> links = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final tutorId = data['tutorId'] as String?;
        if (tutorId != null) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(tutorId).get();
          if (userDoc.exists) {
            links.add({
              'linkId': doc.id,
              ...userDoc.data()!,
            });
          }
        }
      }
      return links;
    });
  }

  Stream<List<Map<String, dynamic>>> _fetchTutorPlayers(String tutorId) {
    return FirebaseFirestore.instance
        .collection('player_tutor_links')
        .where('tutorId', isEqualTo: tutorId)
        .snapshots()
        .asyncMap((snapshot) async {
      final List<Map<String, dynamic>> links = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final playerId = data['playerId'] as String?;
        if (playerId != null) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(playerId).get();
          if (userDoc.exists) {
            links.add({
              'linkId': doc.id,
              ...userDoc.data()!,
            });
          }
        }
      }
      return links;
    });
  }

  void _showRoleDialog(Map<String, dynamic> data) {
    String selectedRole = data['role'] ?? 'padre';
    String? selectedCategory = data['category'];
    List<String> selectedCategories = [];
    if (data['assignedCategories'] != null) {
      selectedCategories = List<String>.from(data['assignedCategories']);
    } else if (data['category'] != null) {
      selectedCategories = [data['category']];
    }
    final roles = ['padre', 'jugador', 'dt', 'secretario', 'directivo'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: context.colors.surface,
            title: const Text('Cambiar Rol o Categoría'),
            content: SingleChildScrollView(
              child: Column(
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
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  if (selectedRole != 'directivo' && selectedRole != 'secretario')
                    Consumer(
                      builder: (context, ref, child) {
                        final categoriesAsync = ref.watch(categoriesStreamProvider);
                        return categoriesAsync.when(
                          data: (categories) {
                            if (categories.isEmpty) {
                              return const Text('No hay categorías creadas. Cree una primero en "Gestionar Categorías".');
                            }
                            
                            if (selectedRole == 'dt') {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Categorías asignadas:', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: categories.map((c) {
                                      final isSelected = selectedCategories.contains(c);
                                      return FilterChip(
                                        label: Text(c),
                                        selected: isSelected,
                                        onSelected: (selected) {
                                          setState(() {
                                            if (selected) {
                                              selectedCategories.add(c);
                                            } else {
                                              selectedCategories.remove(c);
                                            }
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ],
                              );
                            } else {
                              // Ensure selectedCategory is valid
                              if (selectedCategory != null && !categories.contains(selectedCategory)) {
                                selectedCategory = null;
                              }
                              selectedCategory ??= categories.first;

                              return DropdownButtonFormField<String>(
                                initialValue: selectedCategory,
                                decoration: const InputDecoration(labelText: 'Categoría'),
                                items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                                onChanged: (v) {
                                  setState(() {
                                    selectedCategory = v;
                                  });
                                },
                              );
                            }
                          },
                          loading: () => const CircularProgressIndicator(),
                          error: (err, stack) => Text('Error al cargar: $err'),
                        );
                      },
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _updateRole(selectedRole, selectedRole == 'dt' ? (selectedCategories.isNotEmpty ? selectedCategories.first : null) : selectedCategory, selectedCategories, '${data['name']} ${data['lastName']}');
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
      backgroundColor: context.colors.background,
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
                    Text('$name $lastName', style: context.typography.headlineMedium),
                    Text(email, style: context.typography.bodyLarge.copyWith(color: context.colors.textSecondary)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        JNBadge(label: role.toUpperCase()),
                        if (category != null) JNBadge(label: category, type: JNBadgeType.accent),
                        if (isPending) const JNBadge(label: 'PENDIENTE', type: JNBadgeType.warning),
                        if (isDisabled) const JNBadge(label: 'BLOQUEADO', type: JNBadgeType.error),
                        if (status == 'active') const JNBadge(label: 'ACTIVO', type: JNBadgeType.success),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              if (hasPersonalData) ...[
                Text('Datos Personales', style: context.typography.titleLarge),
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

              Text('Datos de Contacto', style: context.typography.titleLarge),
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

              Text('Acciones de Administrador', style: context.typography.titleLarge),
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
                        onPressed: () {
                          if (email == 'munozalbelonicolas@gmail.com') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('El Director no puede ser bloqueado.'),
                                backgroundColor: context.colors.error,
                              ),
                            );
                            return;
                          }
                          final currentUserId = ref.read(currentUserProvider)?.id;
                          if (widget.userId == currentUserId) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('No puedes bloquear tu propia cuenta.'),
                                backgroundColor: context.colors.error,
                              ),
                            );
                            return;
                          }
                          _updateStatus('disabled', '$name $lastName');
                        },
                      ),
                    const SizedBox(height: 12),
                    JNButton(
                      label: 'Cambiar Rol o Categoría',
                      onPressed: () => _showRoleDialog(data),
                      variant: JNButtonVariant.outline,
                    ),
                    const SizedBox(height: 12),
                    JNButton(
                      label: 'Eliminar Cuenta',
                      onPressed: () {
                        if (email == 'munozalbelonicolas@gmail.com') {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('No puedes eliminar al administrador principal'), backgroundColor: context.colors.error));
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
                                child: Text('Eliminar', style: TextStyle(color: context.colors.error)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (role == 'padre' || role == 'tutor') ...[
                Text('Jugadores a cargo', style: context.typography.titleLarge),
                const SizedBox(height: 12),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _fetchTutorPlayers(widget.userId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final players = snapshot.data!;
                    if (players.isEmpty) return const Text('No tiene jugadores vinculados.');
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: players.length,
                      itemBuilder: (context, i) {
                        final p = players[i];
                        final pName = '${p['name'] ?? ''} ${p['lastName'] ?? ''}'.trim();
                        return JNCard(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: JNAvatar(name: pName.isNotEmpty ? pName : 'Jugador', size: 40),
                            title: Text(pName),
                            subtitle: Text('DNI: ${p['dni'] ?? 'N/A'} · ${p['category'] ?? 'N/A'}'),
                            trailing: IconButton(
                              icon: Icon(Icons.delete_outline, color: context.colors.error),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('¿Desvincular jugador?'),
                                    content: const Text('Esto eliminará el vínculo entre el tutor y el jugador.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _deleteLink(p['linkId']);
                                        },
                                        child: Text('Eliminar', style: TextStyle(color: context.colors.error)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],

              if (role == 'jugador') ...[
                Text('Tutores y Co-tutores', style: context.typography.titleLarge),
                const SizedBox(height: 12),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _fetchPlayerTutors(widget.userId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final tutors = snapshot.data!;
                    if (tutors.isEmpty) return const Text('No tiene tutores vinculados.');
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: tutors.length,
                      itemBuilder: (context, i) {
                        final t = tutors[i];
                        final tName = '${t['name'] ?? ''} ${t['lastName'] ?? ''}'.trim();
                        return JNCard(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: JNAvatar(name: tName.isNotEmpty ? tName : 'Tutor', size: 40),
                            title: Text(tName),
                            subtitle: Text('DNI: ${t['dni'] ?? 'N/A'}'),
                            trailing: IconButton(
                              icon: Icon(Icons.delete_outline, color: context.colors.error),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('¿Desvincular tutor?'),
                                    content: const Text('Esto eliminará el vínculo entre el jugador y este tutor/co-tutor.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _deleteLink(t['linkId']);
                                        },
                                        child: Text('Eliminar', style: TextStyle(color: context.colors.error)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
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