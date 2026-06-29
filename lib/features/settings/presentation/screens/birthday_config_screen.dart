import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_button.dart';

class BirthdayConfigScreen extends StatefulWidget {
  const BirthdayConfigScreen({super.key});

  @override
  State<BirthdayConfigScreen> createState() => _BirthdayConfigScreenState();
}

class _BirthdayConfigScreenState extends State<BirthdayConfigScreen> {
  final _db = FirebaseFirestore.instance;

  bool _isLoading = true;
  bool _isSaving = false;

  bool _enablePosts = true;
  bool _enableNotifications = true;
  int _daysPriorToNotify = 1;
  final _templateController = TextEditingController(
    text:
        'Todo el equipo de AppClub y nuestro club queremos desearle un muy feliz cumpleaños a {nombre}. Esperamos que tengas un excelente día junto a tu familia y amigos.',
  );

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final doc = await _db.doc('settings/birthday_system').get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _enablePosts = data['enablePosts'] ?? true;
          _enableNotifications = data['enableNotifications'] ?? true;
          _daysPriorToNotify = data['daysPriorToNotify'] ?? 1;
          _templateController.text =
              data['textTemplate'] ?? _templateController.text;
        });
      }
    } catch (e) {
      debugPrint('Error loading config: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);
    try {
      await _db.doc('settings/birthday_system').set({
        'enablePosts': _enablePosts,
        'enableNotifications': _enableNotifications,
        'daysPriorToNotify': _daysPriorToNotify,
        'textTemplate': _templateController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuración guardada exitosamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Sistema de Cumpleaños', style: AppTypography.titleLarge),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(
                      'Publicaciones Automáticas',
                      style: AppTypography.titleSmall,
                    ),
                    subtitle: Text(
                      'Publicar novedad en el Feed el día del cumpleaños',
                      style: AppTypography.bodySmall,
                    ),
                    value: _enablePosts,
                    activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) => setState(() => _enablePosts = val),
                  ),
                  const Divider(color: AppColors.border),
                  SwitchListTile(
                    title: Text(
                      'Notificaciones Automáticas',
                      style: AppTypography.titleSmall,
                    ),
                    subtitle: Text(
                      'Avisar a Profesores y Directivos',
                      style: AppTypography.bodySmall,
                    ),
                    value: _enableNotifications,
                    activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) =>
                        setState(() => _enableNotifications = val),
                  ),
                ],
              ),
            ),

            if (_enableNotifications) ...[
              const SizedBox(height: 24),
              Text(
                'Días previos de aviso',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '¿Cuántos días antes enviar el recordatorio al cuerpo técnico?',
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: 12),
              Slider(
                value: _daysPriorToNotify.toDouble(),
                min: 0,
                max: 7,
                divisions: 7,
                label: _daysPriorToNotify == 0
                    ? 'Mismo día'
                    : '$_daysPriorToNotify días antes',
                activeColor: AppColors.primary,
                onChanged: (val) =>
                    setState(() => _daysPriorToNotify = val.toInt()),
              ),
              Center(
                child: Text(
                  _daysPriorToNotify == 0
                      ? 'Se avisará el mismo día.'
                      : 'Se avisará $_daysPriorToNotify días antes y el mismo día.',
                  style: AppTypography.labelMedium,
                ),
              ),
            ],

            if (_enablePosts) ...[
              const SizedBox(height: 32),
              Text(
                'Plantilla de Publicación',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'El texto que se mostrará en Novedades. Usa {nombre} para insertar automáticamente el nombre del jugador.',
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _templateController,
                maxLines: 5,
                style: AppTypography.bodyMedium,
                decoration: InputDecoration(
                  hintText: '¡Feliz cumple {nombre}!',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.primary),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vista Previa',
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _templateController.text.replaceAll(
                        '{nombre}',
                        'Juan Pérez',
                      ),
                      style: AppTypography.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 40),
            JNButton(
              label: 'Guardar Configuración',
              onPressed: _saveConfig,
              isLoading: _isSaving,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _templateController.dispose();
    super.dispose();
  }
}
