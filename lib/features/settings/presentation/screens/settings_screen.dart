import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_avatar.dart';
import '../../../../core/widgets/jn_button.dart';
import '../../../../core/widgets/jn_card.dart';
import '../../../coach_panel/presentation/screens/coach_dashboard_screen.dart';
import '../../../coach_panel/presentation/screens/coach_reports_admin_screen.dart';
import '../../../inbox/presentation/screens/inbox_screen.dart';
import '../../../player/presentation/screens/child_detail_screen.dart';
import '../../../player/presentation/screens/my_profile_screen.dart';
import '../../../results/presentation/screens/fixture_screen.dart';
import '../../../results/presentation/screens/league_report_screen.dart';
import '../../../results/presentation/screens/manage_scorers_screen.dart';
import '../../../results/presentation/screens/results_screen.dart';
import 'birthday_config_screen.dart';
import 'club_management_screen.dart';
import 'director_console_screen.dart';
import 'privacy_policy_screen.dart';
import 'sponsors_management_screen.dart';
import 'support_form_screen.dart';
import 'terms_conditions_screen.dart';

class SettingsScreen extends ConsumerWidget {
  final VoidCallback onLogout;
  const SettingsScreen({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return Scaffold(
        backgroundColor: context.colors.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    // We will query children from Firestore using a StreamBuilder below instead of a single mock variable.

    return Scaffold(
      backgroundColor: context.colors.background,
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
                  borderColor: context.colors.accent,
                  borderWidth: 3,
                ),
                const SizedBox(height: 14),
                Text(
                  '${user.name} ${user.lastName}',
                  style: context.typography.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(user.email, style: context.typography.bodyMedium),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    user.role.toLowerCase() == 'padre' ? 'TUTOR' : user.role.toUpperCase(),
                    style: context.typography.badge.copyWith(
                      color: context.colors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms),

          const SizedBox(height: 20),

          // ─── Hijos asociados (Tutor) ────────────────────────
          if (user.role == 'tutor') ...[
            Text('Mis Hijos', style: context.typography.labelMedium),
            const SizedBox(height: 8),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('player_tutor_links')
                  .where('tutorId', isEqualTo: user.id)
                  .snapshots()
                  .asyncMap((snapshot) async {
                final List<Map<String, dynamic>> children = [];
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
                        'Sin hijos registrados. Agrégalos desde "Mi Cuenta".',
                        style: context.typography.bodySmall.copyWith(
                          color: context.colors.textTertiary,
                        ),
                      ),
                    ),
                  );
                }
                return Column(
                  children: children.map((player) {
                    final playerId = player['id']?.toString() ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: JNCard(
                        padding: const EdgeInsets.all(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            if (playerId.isEmpty) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChildDetailScreen(childId: playerId),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: context.colors.surfaceLight,
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
                                    ? Icon(
                                        Icons.person,
                                        size: 20,
                                        color: context.colors.textTertiary,
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
                                      style: context.typography.titleMedium,
                                    ),
                                    Text(
                                      'Categoría: ${player['category'] ?? 'Sin Categoría'}',
                                      style: context.typography.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: context.colors.textTertiary,
                                size: 20,
                              ),
                            ],
                          ),
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
          Text('Mi Perfil', style: context.typography.labelMedium),
          const SizedBox(height: 8),
          _SettingsGroup(
            items: [
              _SettingNav(
                icon: Icons.person_outline,
                label: (user.role == 'jugador' || user.role == 'tutor') ? 'Mi Cuenta y Ficha Médica' : 'Mi Cuenta',
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
          Text('Deportivo', style: context.typography.labelMedium),
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
              if (user.isAdmin)
                _SettingNav(
                  icon: Icons.assignment_ind_outlined,
                  label: 'Informes de DTs',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CoachReportsAdminScreen(),
                      ),
                    );
                  },
                ),
            ],
          ).animate(delay: 135.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: 24),

          // ─── Administration Group (Only for Secretarios and Directivos) ───
          if (user.isAdmin) ...[
            Text('Administración del Club', style: context.typography.labelMedium),
            const SizedBox(height: 8),
            _SettingsGroup(
              items: [
                _SettingNav(
                  icon: Icons.cake,
                  label: 'Sistema de Cumpleaños',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BirthdayConfigScreen(),
                      ),
                    );
                  },
                ),
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
                if (user.isAdmin)
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

          // ─── Herramientas de DT ───────────────────────────
          if (user.isCoach) ...[
            Text('Herramientas de DT', style: context.typography.labelMedium),
            const SizedBox(height: 8),
            _SettingsGroup(
              items: [
                _SettingNav(
                  icon: Icons.sports,
                  label: 'Panel DT (Ver Plantel)',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CoachDashboardScreen(),
                      ),
                    );
                  },
                ),
              ],
            ).animate(delay: 155.ms).fadeIn(duration: 400.ms),
            const SizedBox(height: 20),
          ],

          // ─── Directivos, Secretarios y DTs ──────────────────────
          if (user.isAdmin || user.isCoach) ...[
            Text('Competiciones y Rivalidades', style: context.typography.labelMedium),
            const SizedBox(height: 8),
            _SettingsGroup(
              items: [
                if (user.isAdmin)
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
                _SettingNav(
                  icon: Icons.sports_soccer,
                  label: 'Gestión de Goleadores',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ManageScorersScreen(),
                      ),
                    );
                  },
                ),
              ],
            ).animate(delay: 160.ms).fadeIn(duration: 400.ms),
            const SizedBox(height: 20),
          ],

          // ─── Settings Groups ──────────────────────
          Text('Notificaciones', style: context.typography.labelMedium),
          const SizedBox(height: 8),
          const _SettingsGroup(
            items: [
              _SettingToggle(
                icon: Icons.notifications,
                label: 'Notificaciones push',
                prefKey: 'pref_push_notifications',
              ),
              _SettingToggle(
                icon: Icons.campaign,
                label: 'Comunicados',
                prefKey: 'pref_announcements_notifications',
              ),
              _SettingToggle(
                icon: Icons.sports_soccer,
                label: 'Resultados de partidos',
                prefKey: 'pref_match_notifications',
              ),
              _SettingToggle(
                icon: Icons.payment,
                label: 'Recordatorios de cuotas',
                prefKey: 'pref_quota_notifications',
                defaultValue: false,
              ),
            ],
          ).animate(delay: 200.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: 20),

          Text('General', style: context.typography.labelMedium),
          const SizedBox(height: 8),
          _SettingsGroup(
            items: [
              Consumer(
                builder: (context, ref, child) {
                  final themeMode = ref.watch(themeModeProvider);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
                          size: 20,
                          color: context.colors.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Modo Oscuro',
                            style: context.typography.bodyMedium.copyWith(
                              color: context.colors.textPrimary,
                            ),
                          ),
                        ),
                        Switch.adaptive(
                          value: themeMode == ThemeMode.dark,
                          onChanged: (isDark) {
                            ref.read(themeModeProvider.notifier).setThemeMode(
                              isDark ? ThemeMode.dark : ThemeMode.light,
                            );
                          },
                          activeTrackColor: context.colors.primary,
                          activeThumbColor: Colors.white,
                        ),
                      ],
                    ),
                  );
                },
              ),
              _SettingNav(
                icon: Icons.info_outline,
                label: 'Acerca de',
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: AppConfig.appName,
                    applicationVersion: AppConfig.fullVersion,
                    applicationIcon: Image.asset('assets/images/app_logo.jpg', width: 48, height: 48),
                    applicationLegalese: 'powered by Nilotech @2026 https://nilotech.online\nTodos los derechos reservados',
                  );
                },
              ),
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
              _SettingNav(
                icon: Icons.delete_forever_outlined,
                label: 'Eliminar mi cuenta',
                onTap: () => _confirmDeleteAccount(context, ref),
              ),
            ],
          ).animate(delay: 300.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: 24),

          // App info
          Center(
            child: Column(
              children: [
                Text(AppConfig.appName, style: context.typography.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('v${AppConfig.appVersion}', style: context.typography.labelSmall.copyWith(color: context.colors.textSecondary)),
                const SizedBox(height: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.asset(
                        'assets/icons/LogoNilo.png',
                        width: 16,
                        height: 16,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'powered by Nilotech',
                      style: context.typography.labelSmall.copyWith(
                        color: context.colors.textSecondary,
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
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

  Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.colors.surface,
        title: const Text('¿Eliminar tu cuenta?'),
        content: const Text(
          'Esta acción eliminará tu cuenta y tus datos personales de la plataforma. '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Eliminar',
              style: TextStyle(color: ctx.colors.error, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(authServiceProvider).deleteAccount();
        onLogout();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar la cuenta: $e'),
              backgroundColor: context.colors.error,
            ),
          );
        }
      }
    }
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
                Divider(
                  height: 0.5,
                  indent: 52,
                  color: context.colors.divider,
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
  final String prefKey;
  final bool defaultValue;

  const _SettingToggle({
    required this.icon,
    required this.label,
    required this.prefKey,
    this.defaultValue = true,
  });

  @override
  State<_SettingToggle> createState() => _SettingToggleState();
}

class _SettingToggleState extends State<_SettingToggle> {
  bool _value = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _value = widget.defaultValue;
    _loadPref();
  }

  Future<void> _loadPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _value = prefs.getBool(widget.prefKey) ?? widget.defaultValue;
        _loaded = true;
      });
    }
  }

  Future<void> _savePref(bool val) async {
    setState(() => _value = val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(widget.prefKey, val);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          Icon(widget.icon, size: 20, color: context.colors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.label,
              style: context.typography.bodyMedium.copyWith(
                color: context.colors.textPrimary,
              ),
            ),
          ),
          Switch.adaptive(
            value: _value,
            onChanged: _loaded ? _savePref : null,
            activeTrackColor: context.colors.primary,
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
            Icon(icon, size: 20, color: context.colors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: context.typography.bodyMedium.copyWith(
                  color: context.colors.textPrimary,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: context.colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}