import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/jn_card.dart';
import '../../../../core/widgets/jn_button.dart';

class StoreConfigScreen extends StatefulWidget {
  const StoreConfigScreen({super.key});

  @override
  State<StoreConfigScreen> createState() => _StoreConfigScreenState();
}

class _StoreConfigScreenState extends State<StoreConfigScreen> {
  final _db = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSaving = false;

  final _cbuController = TextEditingController();
  final _aliasController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountHolderController = TextEditingController();
  bool _isStoreEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _cbuController.dispose();
    _aliasController.dispose();
    _bankNameController.dispose();
    _accountHolderController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      final doc = await _db.doc('settings/store_config').get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _cbuController.text = data['cbu'] ?? '';
          _aliasController.text = data['alias'] ?? '';
          _bankNameController.text = data['bankName'] ?? '';
          _accountHolderController.text = data['accountHolder'] ?? '';
          _isStoreEnabled = data['isStoreEnabled'] ?? true;
        });
      }
    } catch (e) {
      debugPrint('Error loading store config: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await _db.doc('settings/store_config').set({
        'cbu': _cbuController.text.trim(),
        'alias': _aliasController.text.trim(),
        'bankName': _bankNameController.text.trim(),
        'accountHolder': _accountHolderController.text.trim(),
        'isStoreEnabled': _isStoreEnabled,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuración de tienda guardada'),
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
        title: Text('Configuración de Tienda', style: AppTypography.titleLarge),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Store toggle
              JNCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.storefront, color: AppColors.accent, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tienda Activa', style: AppTypography.titleSmall),
                          const SizedBox(height: 2),
                          Text(
                            _isStoreEnabled ? 'Visible para todos los usuarios' : 'Oculta temporalmente',
                            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isStoreEnabled,
                      activeThumbColor: AppColors.success,
                      onChanged: (v) => setState(() => _isStoreEnabled = v),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Datos Bancarios del Club',
                style: AppTypography.titleMedium.copyWith(color: AppColors.primary),
              ),
              const SizedBox(height: 4),
              Text(
                'Estos datos se mostrarán al comprador en el checkout.',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
              ),
              const SizedBox(height: 16),

              // CBU
              TextFormField(
                controller: _cbuController,
                decoration: InputDecoration(
                  labelText: 'CBU',
                  hintText: 'Ej: 0000000000000000000000',
                  prefixIcon: const Icon(Icons.account_balance, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Ingresá el CBU';
                  if (v.trim().length != 22) return 'El CBU debe tener 22 dígitos';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Alias
              TextFormField(
                controller: _aliasController,
                decoration: InputDecoration(
                  labelText: 'Alias',
                  hintText: 'Ej: CLUB.NEWBERY',
                  prefixIcon: const Icon(Icons.alternate_email, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Ingresá el alias' : null,
              ),
              const SizedBox(height: 16),

              // Bank Name
              TextFormField(
                controller: _bankNameController,
                decoration: InputDecoration(
                  labelText: 'Banco',
                  hintText: 'Ej: Banco Nación',
                  prefixIcon: const Icon(Icons.business, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Ingresá el banco' : null,
              ),
              const SizedBox(height: 16),

              // Account Holder
              TextFormField(
                controller: _accountHolderController,
                decoration: InputDecoration(
                  labelText: 'Titular de la Cuenta',
                  hintText: 'Ej: Club Atlético Jorge Newbery',
                  prefixIcon: const Icon(Icons.person_outline, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Ingresá el titular' : null,
              ),

              const SizedBox(height: 32),

              JNButton(
                label: 'Guardar Configuración',
                onPressed: _isSaving ? null : _saveConfig,
                isLoading: _isSaving,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
