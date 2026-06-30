import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_card.dart';
import '../../../../core/widgets/jn_avatar.dart';
import '../../../../core/widgets/jn_button.dart';
import '../../../../core/providers/session_provider.dart';

// Import screens from other features
import '../../../player/presentation/screens/my_profile_screen.dart';
import '../../../inbox/presentation/screens/inbox_screen.dart';
import '../../../results/presentation/screens/results_screen.dart';
import '../../../results/presentation/screens/fixture_screen.dart';
import '../../../results/presentation/screens/league_report_screen.dart';
import 'club_management_screen.dart';
import 'sponsors_management_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_conditions_screen.dart';
import 'support_form_screen.dart';
import 'director_console_screen.dart';

class SettingsScreen extends ConsumerWidget {
  final VoidCallback onLogout;
  const SettingsScreen({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider)!;
    // We will query children from Firestore using a StreamBuilder below instead of a single mock variable.

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          // ─── User Profile Card ────────────────────
          JNCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                JNAvatar(
                  name: '${user.name} ${user.lastName}',
                  size: 72,
                  borderColor: AppColors.accent,
                  borderWidth: 3,
                ),
                const SizedBox(height: 14),
                Text(
                  '${user.name} ${user.lastName}',
                  style: AppTypography.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(user.email, style: AppTypography.bodyMedium),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    user.role.toUpperCase(),
                    style: AppTypography.badge.copyWith(
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms),

          const SizedBox(height: 20),

          // ─── Hijos asociados (Tutor) ────────────────────────
          if (user.role == 'padre') ...[
            Text('Mis Hijos (Jugadores)', style: AppTypography.labelMedium),
            const SizedBox(height: 8),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('player_tutor_links')
                  .where('tutorId', isEqualTo: user.id)
                  .snapshots()
                  .asyncMap((snapshot) async {
                List<Map<String, dynamic>> children = [];
                for (var doc in snapshot.docs) {
                  final data = doc.data();
                  final playerId = data['playerId'] as String?;
                  if (playerId != null) {
                    final playerDoc = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(playerId)
                        .get();
                    if (playerDoc.exists) {
                      children.add({
                        'id': playerDoc.id,
                        ...playerDoc.data()!,
                      });
                    }
                  }
                }
                return children;
              }),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final children = snapshot.data ?? [];
                if (children.isEmpty) {
                  return JNCard(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'Sin hijos registrados. Agrégalos desde "Mi Perfil".',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  );
                }
                return Column(
                  children: children.map((player) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: JNCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.surfaceLight,
                              backgroundImage: player['avatarUrl'] != null &&
                                      player['avatarUrl'].toString().isNotEmpty
                                  ? (player['avatarUrl'].toString().startsWith('http')
                                      ? NetworkImage(player['avatarUrl'].toString())
                                          as ImageProvider
                                      : FileImage(File(player['avatarUrl'].toString()))
                                          as ImageProvider)
                                  : null,
                              child: player['avatarUrl'] == null ||
                                      player['avatarUrl'].toString().isEmpty
                                  ? const Icon(
                                      Icons.person,
                                      size: 20,
                                      color: AppColors.textTertiary,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${player['name']} ${player['lastName'] ?? ''}',
                                    style: AppTypography.titleMedium,
                                  ),
                                  Text(
                                    'Categoría: ${player['category'] ?? 'Sin Categoría'}',
                                    style: AppTypography.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ).animate(delay: 100.ms).fadeIn(duration: 400.ms),
            const SizedBox(height: 20),
          ],

          // ─── Mi Cuenta Group ──────────────────────
          Text('Mi Perfil', style: AppTypography.labelMedium),
          const SizedBox(height: 8),
          _SettingsGroup(
            items: [
              _SettingNav(
                icon: Icons.person_outline,
                label: 'Mi Cuenta y Ficha Médica',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MyProfileScreen(),
                    ),
                  );
                },
              ),
              _SettingNav(
                icon: Icons.mail_outline,
                label: 'Buzón de Mensajes (Inbox)',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const InboxScreen(),
                    ),
                  );
                },
              ),
            ],
          ).animate(delay: 120.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: 24),

          // ─── Resultados ─────────────────────────────
          Text('Deportivo', style: AppTypography.labelMedium),
          const SizedBox(height: 8),
          _SettingsGroup(
            items: [
              _SettingNav(
                icon: Icons.emoji_events_outlined,
                label: 'Resultados',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ResultsScreen(),
                    ),
                  );
                },
              ),
              _SettingNav(
                icon: Icons.calendar_view_week_outlined,
                label: 'Fixture',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FixtureScreen(),
                    ),
                  );
                },
              ),
              _SettingNav(
                icon: Icons.assignment_outlined,
                label: 'Informe Liga',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LeagueReportScreen(),
                    ),
                  );
                },
              ),
            ],
          ).animate(delay: 135.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: 24),

          // ─── Administration Group (Only for Secretarios and Directivos) ───
          if (user.isAdmin) ...[
            Text('Administración del Club', style: AppTypography.labelMedium),
            const SizedBox(height: 8),
            _SettingsGroup(
              items: [
                _SettingNav(
                  icon: Icons.business,
                  label: 'Gestión de Sponsors',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SponsorsManagementScreen(),
                      ),
                    );
                  },
                ),
                if (user.isDirector)
                  _SettingNav(
                    icon: Icons.admin_panel_settings_outlined,
                    label: 'Consola del Director',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DirectorConsoleScreen(),
                        ),
                      );
                    },
                  ),
              ],
            ).animate(delay: 150.ms).fadeIn(duration: 400.ms),
            const SizedBox(height: 20),
          ],

          // ─── Directivos, Secretarios y DTs ──────────────────────
          if (user.isAdmin || user.isCoach) ...[
            Text('Competiciones y Rivalidades', style: AppTypography.labelMedium),
            const SizedBox(height: 8),
            _SettingsGroup(
              items: [
                _SettingNav(
                  icon: Icons.shield,
                  label: 'Gestión de Clubes',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ClubManagementScreen(),
                      ),
                    );
                  },
                ),
              ],
            ).animate(delay: 160.ms).fadeIn(duration: 400.ms),
            const SizedBox(height: 20),
          ],

          // ─── Settings Groups ──────────────────────
          Text('Notificaciones', style: AppTypography.labelMedium),
          const SizedBox(height: 8),
          _SettingsGroup(
            items: [
              _SettingToggle(
                icon: Icons.notifications,
                label: 'Notificaciones push',
                value: true,
              ),
              _SettingToggle(
                icon: Icons.campaign,
                label: 'Comunicados',
                value: true,
              ),
              _SettingToggle(
                icon: Icons.sports_soccer,
                label: 'Resultados de partidos',
                value: true,
              ),
              _SettingToggle(
                icon: Icons.payment,
                label: 'Recordatorios de cuotas',
                value: false,
              ),
            ],
          ).animate(delay: 200.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: 20),

          Text('General', style: AppTypography.labelMedium),
          const SizedBox(height: 8),
          _SettingsGroup(
            items: [
              _SettingNav(icon: Icons.info_outline, label: 'Sobre el club'),
              _SettingNav(
                icon: Icons.description_outlined,
                label: 'Términos y condiciones',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TermsConditionsScreen(),
                    ),
                  );
                },
              ),
              _SettingNav(
                icon: Icons.shield_outlined,
                label: 'Política de privacidad',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PrivacyPolicyScreen(),
                    ),
                  );
                },
              ),
              _SettingNav(
                icon: Icons.help_outline,
                label: 'Ayuda y soporte',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SupportFormScreen(),
                    ),
                  );
                },
              ),
            ],
          ).animate(delay: 300.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: 24),

          // App info
          Center(
            child: Column(
              children: [
                Text('Jorge Newbery App', style: AppTypography.bodySmall),
                Text('v1.0.0', style: AppTypography.labelSmall),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Logout
          JNButton(
            label: 'Cerrar sesión',
            onPressed: onLogout,
            variant: JNButtonVariant.outline,
            fullWidth: true,
            icon: Icons.logout,
          ).animate(delay: 400.ms).fadeIn(duration: 400.ms),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> items;
  const _SettingsGroup({required this.items});

  @override
  Widget build(BuildContext context) {
    return JNCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: items.asMap().entries.map((entry) {
          final isLast = entry.key == items.length - 1;
          return Column(
            children: [
              entry.value,
              if (!isLast)
                const Divider(
                  height: 0.5,
                  indent: 52,
                  color: AppColors.divider,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _SettingToggle extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool value;

  const _SettingToggle({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  State<_SettingToggle> createState() => _SettingToggleState();
}

class _SettingToggleState extends State<_SettingToggle> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          Icon(widget.icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.label,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Switch.adaptive(
            value: _value,
            onChanged: (v) => setState(() => _value = v),
            activeTrackColor: AppColors.primary,
            activeThumbColor: Colors.white,
          ),
        ],
      ),
    );
  }
}

class _SettingNav extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _SettingNav({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
