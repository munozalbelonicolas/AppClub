import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/app_logger.dart';
import '../../../../core/services/image_upload_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_button.dart';

class CreateProductScreen extends ConsumerStatefulWidget {
  final String? productId; // null = create, non-null = edit

  const CreateProductScreen({super.key, this.productId});

  @override
  ConsumerState<CreateProductScreen> createState() => _CreateProductScreenState();
}

class _CreateProductScreenState extends ConsumerState<CreateProductScreen> {
  final _db = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  bool _isLoading = false;
  bool _isSaving = false;

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController(text: '10');

  String _selectedCategory = 'indumentaria';
  final Set<String> _selectedSizes = {};
  String? _existingImageUrl;
  File? _localImage;

  final List<String> _categories = ['indumentaria', 'accesorios', 'calzado', 'equipamiento'];
  final List<String> _allSizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL', '28', '30', '32', '34', '36', '38', '40', '42'];

  bool get _isEditing => widget.productId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadProduct();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _loadProduct() async {
    setState(() => _isLoading = true);
    try {
      final doc = await _db.collection('store_products').doc(widget.productId).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _nameController.text = data['name'] ?? '';
          _descriptionController.text = data['description'] ?? '';
          _priceController.text = (data['price'] ?? 0).toString();
          _stockController.text = (data['stock'] ?? 0).toString();
          _selectedCategory = data['category'] ?? 'indumentaria';
          _selectedSizes.addAll(List<String>.from(data['sizes'] ?? []));
          _existingImageUrl = data['imageUrl'];
        });
      }
    } catch (e) {
      AppLogger.error('Error loading product', error: e, tag: 'App');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 800);
      if (picked != null) {
        setState(() => _localImage = File(picked.path));
      }
    } catch (e) {
      AppLogger.error('Error picking image', error: e, tag: 'App');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSizes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Seleccioná al menos un talle'), backgroundColor: context.colors.warning),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final user = ref.read(currentUserProvider)!;
      final price = double.tryParse(_priceController.text.trim()) ?? 0;
      final stock = int.tryParse(_stockController.text.trim()) ?? 0;

      // Upload image to Firebase Storage if a new one was selected
      String? imageUrl = _existingImageUrl;
      if (_localImage != null) {
        imageUrl = await ImageUploadService.uploadProductImage(
          _localImage!,
          productId: widget.productId,
        );
      }

      final productData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': price,
        'imageUrl': imageUrl ?? '',
        'sizes': _selectedSizes.toList()..sort(),
        'category': _selectedCategory,
        'stock': stock,
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_isEditing) {
        await _db.collection('store_products').doc(widget.productId).update(productData);
      } else {
        productData['createdBy'] = user.id;
        productData['createdAt'] = FieldValue.serverTimestamp();
        await _db.collection('store_products').add(productData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Producto actualizado' : 'Producto creado'),
            backgroundColor: context.colors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: context.colors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.colors.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Producto' : 'Nuevo Producto', style: context.typography.titleLarge),
        backgroundColor: context.colors.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image picker
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: context.colors.surfaceLight,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: _localImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                          child: Image.file(_localImage!, fit: BoxFit.cover, width: double.infinity),
                        )
                      : _existingImageUrl != null && _existingImageUrl!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                              child: Image.file(
                                File(_existingImageUrl!),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (context, error, stackTrace) => _imagePlaceholder(),
                              ),
                            )
                          : _imagePlaceholder(),
                ),
              ),
              const SizedBox(height: 20),

              // Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nombre del Producto',
                  hintText: 'Ej: Camiseta Titular 2026',
                  prefixIcon: const Icon(Icons.shopping_bag_outlined, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                  filled: true,
                  fillColor: context.colors.surfaceLight,
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Ingresá el nombre' : null,
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Descripción del producto...',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 48),
                    child: Icon(Icons.description_outlined, size: 20),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                  filled: true,
                  fillColor: context.colors.surfaceLight,
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Ingresá la descripción' : null,
              ),
              const SizedBox(height: 16),

              // Price & Stock in a row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Precio (\$)',
                        prefixIcon: const Icon(Icons.attach_money, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                        filled: true,
                        fillColor: context.colors.surfaceLight,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Precio';
                        if (double.tryParse(v.trim()) == null) return 'Inválido';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _stockController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Stock',
                        prefixIcon: const Icon(Icons.inventory_2_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                        filled: true,
                        fillColor: context.colors.surfaceLight,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Stock';
                        if (int.tryParse(v.trim()) == null) return 'Inválido';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Category dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Categoría',
                  prefixIcon: const Icon(Icons.category_outlined, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                  filled: true,
                  fillColor: context.colors.surfaceLight,
                ),
                dropdownColor: context.colors.surfaceVariant,
                items: _categories
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c[0].toUpperCase() + c.substring(1)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCategory = v!),
              ),
              const SizedBox(height: 20),

              // Sizes
              Text('Talles disponibles', style: context.typography.labelMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allSizes.map((size) {
                  final isSelected = _selectedSizes.contains(size);
                  return FilterChip(
                    label: Text(size),
                    selected: isSelected,
                    selectedColor: context.colors.primary.withValues(alpha: 0.3),
                    checkmarkColor: context.colors.primary,
                    backgroundColor: context.colors.surfaceLight,
                    side: BorderSide(
                      color: isSelected ? context.colors.primary : context.colors.border,
                    ),
                    labelStyle: TextStyle(
                      color: isSelected ? context.colors.primary : context.colors.textSecondary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedSizes.add(size);
                        } else {
                          _selectedSizes.remove(size);
                        }
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 32),

              JNButton(
                label: _isEditing ? 'Actualizar Producto' : 'Publicar Producto',
                onPressed: _isSaving ? null : _save,
                isLoading: _isSaving,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_outlined, size: 48, color: context.colors.textTertiary),
        const SizedBox(height: 8),
        Text('Agregar imagen', style: context.typography.bodyMedium.copyWith(color: context.colors.textTertiary)),
      ],
    );
  }
}