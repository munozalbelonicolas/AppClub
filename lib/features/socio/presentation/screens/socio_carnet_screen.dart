import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_avatar.dart';

class SocioCarnetScreen extends ConsumerWidget {
  const SocioCarnetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionUser = ref.watch(currentUserProvider);
    if (sessionUser == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(
          'Carnet Digital',
          style: context.typography.headlineSmall.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    context.colors.primary,
                    context.colors.primary.withValues(alpha: 0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: context.colors.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Decorative background element
                  Positioned(
                    right: -20,
                    top: -20,
                    child: Icon(
                      Icons.shield_outlined,
                      size: 150,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Club Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.shield, color: Colors.white, size: 28),
                            const SizedBox(width: 12),
                            Text(
                              'CLUB JORGE NEWBERY',
                              style: context.typography.titleMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        
                        // Avatar
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          child: JNAvatar(
                            name: '${sessionUser.name} ${sessionUser.lastName}',
                            size: 100,
                            imageUrl: sessionUser.avatarUrl,
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // User Info
                        Text(
                          '${sessionUser.name} ${sessionUser.lastName}'.toUpperCase(),
                          style: context.typography.headlineMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: sessionUser.status == 'active' 
                                ? Colors.green.withValues(alpha: 0.2)
                                : Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sessionUser.status == 'active'
                                  ? Colors.greenAccent
                                  : Colors.orangeAccent,
                            ),
                          ),
                          child: Text(
                            sessionUser.status == 'active' 
                                ? 'SOCIO ACTIVO' 
                                : 'PENDIENTE',
                            style: context.typography.labelLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // DNI (Optional)
                        if (sessionUser.dni != null && sessionUser.dni!.isNotEmpty)
                          Text(
                            'DNI: ${sessionUser.dni}',
                            style: context.typography.titleSmall.copyWith(
                              color: Colors.white70,
                              letterSpacing: 2,
                            ),
                          ),
                        const SizedBox(height: 8),
                        
                        // Member Type
                        Text(
                          'Socio Titular',
                          style: context.typography.titleSmall.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // QR Code
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: QrImageView(
                            data: 'appclub://socio/${sessionUser.id}',
                            size: 150.0,
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
