import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_card.dart';
import '../../../../core/widgets/jn_button.dart';
import '../../../../core/providers/session_provider.dart';

class SupportFormScreen extends ConsumerStatefulWidget {
  const SupportFormScreen({super.key});

  @override
  ConsumerState<SupportFormScreen> createState() => _SupportFormScreenState();
}

class _SupportFormScreenState extends ConsumerState<SupportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  
  String _selectedCategory = 'Consulta General';
  bool _isLoading = false;
  bool _isSubmitted = false;
  String _activeSupportEmail = 'ayuda@jorgenewbery.com'; // Fallback

  final List<String> _categories = [
    'Consulta General',
    'Deportivo / Entrenamientos',
    'Pagos y Cuotas',
    'Soporte Técnico App',
    'Sugerencias',
  ];

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitForm(String supportEmail, dynamic currentUser) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance.collection('support_inquiries').add({
        'userId': currentUser.id,
        'userName': '${currentUser.name} ${currentUser.lastName}',
        'userEmail': currentUser.email,
        'subject': _subjectController.text.trim(),
        'category': _selectedCategory,
        'message': _messageController.text.trim(),
        'sentToEmail': supportEmail,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _isLoading = false;
        _isSubmitted = true;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar la consulta: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider) ?? SessionMocks.users['padre']!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ayuda y Soporte'),
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('config')
            .doc('support_settings')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>?;
            if (data != null &&
                data['support_email'] != null &&
                data['support_email'].toString().trim().isNotEmpty) {
              _activeSupportEmail = data['support_email'].toString().trim();
            }
          }

          return SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: _isSubmitted
                  ? _buildSuccessView()
                  : _buildFormView(currentUser),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFormView(dynamic currentUser) {
    return SingleChildScrollView(
      key: const ValueKey('form_view'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info banner about support email
            JNCard(
              padding: const EdgeInsets.all(16),
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.1),
                  AppColors.surfaceLight
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              child: Row(
                children: [
                  const Icon(Icons.mark_email_unread_outlined,
                      color: AppColors.primary, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Soporte Oficial por Correo',
                          style: AppTypography.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tu consulta será dirigida a:\n$_activeSupportEmail',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),

            const SizedBox(height: 24),

            Text('Completa los detalles de tu consulta',
                style: AppTypography.labelMedium),
            const SizedBox(height: 12),

            // Subject field
            TextFormField(
              controller: _subjectController,
              style: AppTypography.bodyLarge,
              decoration: const InputDecoration(
                labelText: 'Asunto / Título corto',
                hintText: 'Ej: Consulta sobre ficha médica vencida',
              ),
              validator: (val) => val == null || val.trim().isEmpty
                  ? 'Por favor ingresa un asunto'
                  : null,
            ).animate(delay: 50.ms).fadeIn(),

            const SizedBox(height: 16),

            // Category dropdown
            DropdownButtonFormField<String>(
              dropdownColor: AppColors.surface,
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Categoría de consulta',
              ),
              items: _categories.map((cat) {
                return DropdownMenuItem(
                  value: cat,
                  child: Text(cat, style: AppTypography.bodyLarge),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedCategory = val;
                  });
                }
              },
            ).animate(delay: 100.ms).fadeIn(),

            const SizedBox(height: 16),

            // Message text field
            TextFormField(
              controller: _messageController,
              maxLines: 6,
              style: AppTypography.bodyLarge,
              decoration: const InputDecoration(
                labelText: 'Mensaje / Detalles de la ayuda requerida',
                hintText: 'Describe aquí en detalle tu problema o inquietud...',
                alignLabelWithHint: true,
              ),
              validator: (val) => val == null || val.trim().isEmpty
                  ? 'Por favor escribe el mensaje con los detalles'
                  : null,
            ).animate(delay: 150.ms).fadeIn(),

            const SizedBox(height: 32),

            // Submit button
            JNButton(
              label: 'Enviar Consulta',
              icon: Icons.send,
              onPressed: () => _submitForm(_activeSupportEmail, currentUser),
              isLoading: _isLoading,
              fullWidth: true,
            ).animate(delay: 200.ms).fadeIn().scaleY(begin: 0.9),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Container(
      key: const ValueKey('success_view'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Animated Paper Airplane Icon
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.send,
              color: AppColors.success,
              size: 72,
            ),
          )
              .animate()
              .scale(duration: 600.ms, curve: Curves.easeOutBack)
              .then()
              .shake(duration: 300.ms),
          
          const SizedBox(height: 32),
          
          Text(
            '¡Consulta Enviada!',
            style: AppTypography.displaySmall.copyWith(color: AppColors.success),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms),
          
          const SizedBox(height: 16),
          
          Text(
            'Tu mensaje ha sido registrado exitosamente y enviado a la dirección de correo oficial del club:',
            style: AppTypography.bodyMedium,
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 300.ms),
          
          const SizedBox(height: 12),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Text(
              _activeSupportEmail,
              style: AppTypography.titleMedium.copyWith(color: AppColors.primary),
            ),
          ).animate().fadeIn(delay: 400.ms).scale(begin: const Offset(0.9, 0.9)),
          
          const SizedBox(height: 16),
          
          Text(
            'Te responderemos a la brevedad a tu correo electrónico registrado:\n${ref.read(currentUserProvider)?.email ?? ""}',
            style: AppTypography.bodySmall,
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 500.ms),
          
          const SizedBox(height: 48),
          
          JNButton(
            label: 'Volver a Ajustes',
            variant: JNButtonVariant.outline,
            onPressed: () {
              Navigator.pop(context);
            },
            fullWidth: true,
          ).animate().fadeIn(delay: 600.ms),
        ],
      ),
    );
  }
}
