import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_button.dart';
import '../../../../core/services/player_service.dart';
import '../../../../core/providers/session_provider.dart';

class RegisterPlayerScreen extends ConsumerStatefulWidget {
  final VoidCallback? onSuccess;
  const RegisterPlayerScreen({super.key, this.onSuccess});

  @override
  ConsumerState<RegisterPlayerScreen> createState() =>
      _RegisterPlayerScreenState();
}

class _RegisterPlayerScreenState extends ConsumerState<RegisterPlayerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dniController = TextEditingController();
  final _fullNameController = TextEditingController();
  DateTime? _birthDate;
  final _categoryController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _avatarPath;
  bool _enableLogin = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _pickAvatar() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 60,
      );
      if (image != null) {
        setState(() {
          _avatarPath = image.path;
        });
      }
    } catch (e) {
      debugPrint('Error picking avatar: $e');
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate() || _birthDate == null) {
      if (_birthDate == null) setState(() {}); // Trigger rebuild to show error
      return;
    }

    setState(() => _isLoading = true);
    try {
      final tutorSession = ref.read(currentUserProvider);
      if (tutorSession == null) throw Exception("Sesión no encontrada");

      final fullNameStr = _fullNameController.text.trim();
      final parts = fullNameStr.split(' ');
      final name = parts.isNotEmpty ? parts.first : '';
      final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

      await ref
          .read(playerServiceProvider)
          .registerOrLinkPlayer(
            tutorId: tutorSession.id,
            dni: _dniController.text.trim(),
            name: name,
            lastName: lastName,
            birthDate: _birthDate,
            category: _categoryController.text.trim(),
            weight: _weightController.text.trim(),
            height: _heightController.text.trim(),
            email: _enableLogin ? _emailController.text.trim() : null,
            password: _enableLogin && _passwordController.text.isNotEmpty
                ? _passwordController.text
                : null,
            enableAccount: _enableLogin,
            avatarUrl: _avatarPath,
          );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Jugador registrado con éxito'),
              backgroundColor: AppColors.success,
            ),
          );
          if (widget.onSuccess != null) {
            widget.onSuccess!();
          } else {
            Navigator.pop(context);
          }
        }
    } on PlayerExistsException catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text('Jugador ya registrado'),
              content: Text(
                'El jugador ${e.playerName} ya se encuentra registrado en el club. ¿Deseas enviar una solicitud para ser co-tutor?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    Navigator.pop(context); // close dialog
                    setState(() => _isLoading = true);
                    try {
                      final tutorSession = ref.read(currentUserProvider)!;
                      await ref.read(playerServiceProvider).submitCoTutorRequest(
                            tutorId: tutorSession.id,
                            tutorName: '${tutorSession.name} ${tutorSession.lastName}',
                            playerId: e.playerId,
                            playerName: e.playerName,
                            enableAccount: _enableLogin,
                          );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Solicitud enviada con éxito.'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                      if (widget.onSuccess != null) {
                        widget.onSuccess!();
                      } else {
                        Navigator.pop(context);
                      }
                    } catch (err) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $err'), backgroundColor: AppColors.error),
                      );
                    } finally {
                      if (mounted) setState(() => _isLoading = false);
                    }
                  },
                  child: const Text('Solicitar ser Co-Tutor'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Registrar Jugador', style: AppTypography.titleLarge),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Datos del jugador',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),

                // ─── Avatar Photo Card ────────────────────
                Center(
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: _pickAvatar,
                        child: CircleAvatar(
                          radius: 54,
                          backgroundColor: AppColors.surfaceLight,
                          backgroundImage: _avatarPath != null
                              ? FileImage(File(_avatarPath!)) as ImageProvider
                              : null,
                          child: _avatarPath == null
                              ? const Icon(
                                  Icons.person,
                                  size: 48,
                                  color: AppColors.textTertiary,
                                )
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickAvatar,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Tomar foto de perfil (Solo Cámara)',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                TextFormField(
                  controller: _dniController,
                  keyboardType: TextInputType.number,
                  style: AppTypography.bodyLarge,
                  decoration: const InputDecoration(
                    labelText: 'DNI (Sin puntos)',
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _fullNameController,
                  style: AppTypography.bodyLarge,
                  decoration: const InputDecoration(labelText: 'Nombre completo'),
                  validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate:
                                _birthDate ??
                                DateTime.now().subtract(
                                  const Duration(days: 365 * 10),
                                ),
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() => _birthDate = date);
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Fecha de Nacimiento',
                            errorText: _birthDate == null ? 'Requerido' : null,
                          ),
                          child: Text(
                            _birthDate != null
                                ? '${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}'
                                : 'Seleccionar fecha',
                            style: AppTypography.bodyLarge,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _categoryController,
                        style: AppTypography.bodyLarge,
                        decoration: const InputDecoration(
                          labelText: 'Categoría (ej: Sub-12)',
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Requerido' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _weightController,
                        style: AppTypography.bodyLarge,
                        decoration: const InputDecoration(
                          labelText: 'Peso (ej: 60kg)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _heightController,
                        style: AppTypography.bodyLarge,
                        decoration: const InputDecoration(
                          labelText: 'Altura (ej: 1.70m)',
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Habilitar inicio de sesión',
                            style: AppTypography.titleMedium.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Permite al jugador loguearse con correo y contraseña.',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _enableLogin,
                      onChanged: (v) => setState(() => _enableLogin = v),
                      activeThumbColor: AppColors.primary,
                    ),
                  ],
                ),
                if (_enableLogin) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: AppTypography.bodyLarge,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                    ),
                    validator: (v) => _enableLogin && (v == null || v.isEmpty)
                        ? 'Requerido para el inicio de sesión'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: AppTypography.bodyLarge,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) => _enableLogin && (v == null || v.length < 6)
                        ? 'La contraseña debe tener al menos 6 caracteres'
                        : null,
                  ),
                ],
                const SizedBox(height: 32),

                JNButton(
                  label: 'Registrar Jugador',
                  onPressed: _handleRegister,
                  fullWidth: true,
                  isLoading: _isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _dniController.dispose();
    _fullNameController.dispose();
    _categoryController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
