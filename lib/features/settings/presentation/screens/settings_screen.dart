import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_card.dart';
import '../../../../core/widgets/jn_avatar.dart';
import '../../../../core/widgets/jn_button.dart';
import '../../../../data/mock/mock_data.dart';
import '../../../../core/providers/session_provider.dart';
import 'sponsors_management_screen.dart';
import '../../../player/presentation/screens/my_profile_screen.dart';
import 'director_console_screen.dart';

class SettingsScreen extends ConsumerWidget {
  final VoidCallback onLogout;
  const SettingsScreen({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider) ?? SessionMocks.users['padre']!;
    final player = MockData.currentPlayer;

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
                Text(
                  user.email,
                  style: AppTypography.bodyMedium,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    user.role.toUpperCase(),
                    style: AppTypography.badge.copyWith(color: AppColors.accent),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms),

          const SizedBox(height: 20),

          // ─── Hijo asociado ────────────────────────
          Text('Jugador asociado', style: AppTypography.labelMedium),
          const SizedBox(height: 8),
          JNCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                JNAvatar(
                  name: '${player['name']} ${player['lastName']}',
                  size: 42,
                  number: player['number'] as int,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${player['name']} ${player['lastName']}', style: AppTypography.titleMedium),
                      Text('${player['category']} · ${player['position']}', style: AppTypography.bodySmall),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary),
              ],
            ),
          ).animate(delay: 100.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: 20),

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
            ],
          ).animate(delay: 120.ms).fadeIn(duration: 400.ms),

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

          // ─── Settings Groups ──────────────────────
          Text('Notificaciones', style: AppTypography.labelMedium),
          const SizedBox(height: 8),
          _SettingsGroup(
            items: [
              _SettingToggle(icon: Icons.notifications, label: 'Notificaciones push', value: true),
              _SettingToggle(icon: Icons.campaign, label: 'Comunicados', value: true),
              _SettingToggle(icon: Icons.sports_soccer, label: 'Resultados de partidos', value: true),
              _SettingToggle(icon: Icons.payment, label: 'Recordatorios de cuotas', value: false),
            ],
          ).animate(delay: 200.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: 20),

          Text('General', style: AppTypography.labelMedium),
          const SizedBox(height: 8),
          _SettingsGroup(
            items: [
              _SettingNav(icon: Icons.info_outline, label: 'Sobre el club'),
              _SettingNav(icon: Icons.description_outlined, label: 'Términos y condiciones'),
              _SettingNav(icon: Icons.shield_outlined, label: 'Política de privacidad'),
              _SettingNav(icon: Icons.help_outline, label: 'Ayuda y soporte'),
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
                const Divider(height: 0.5, indent: 52, color: AppColors.divider),
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

  const _SettingToggle({required this.icon, required this.label, required this.value});

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
          Expanded(child: Text(widget.label, style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary))),
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
            Expanded(child: Text(label, style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary))),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
