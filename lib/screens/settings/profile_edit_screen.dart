import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:crypto_sync/providers/sync_provider.dart';
import 'package:crypto_sync/theme/app_colors.dart';
import 'package:crypto_sync/widgets/common_widgets.dart';
import 'package:crypto_sync/core/api_config.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  String? _base64Image;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final syncProvider = context.read<SyncProvider>();
    _nameController = TextEditingController(text: syncProvider.userName);
    _phoneController = TextEditingController(text: syncProvider.userPhone ?? '');
    _emailController = TextEditingController(text: syncProvider.userEmail);
    _base64Image = syncProvider.userProfilePic;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdate() async {
    setState(() => _isLoading = true);
    final syncProvider = context.read<SyncProvider>();
    final userId = syncProvider.lastUserId;

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/profile/update?user_id=$userId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': _nameController.text,
          'phone': _phoneController.text,
          'email': _emailController.text,
          'profile_pic': _base64Image,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          // Update local provider state 
          syncProvider.connect(
            userId!, 
            syncProvider.subProvider?.isAdmin == true ? 'admin' : 'user', // Dummy token for re-sync if needed, or better just use a setter
            userName: _nameController.text,
            userEmail: _emailController.text,
            userPhone: _phoneController.text,
            userProfilePic: _base64Image,
          );
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: AppColors.success),
          );
          context.pop();
        }
      } else {
        final error = jsonDecode(response.body)['detail'] ?? 'Update failed';
        throw Exception(error);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.surface,
                    backgroundImage: _base64Image != null 
                        ? MemoryImage(base64Decode(_base64Image!)) 
                        : null,
                    child: _base64Image == null 
                        ? const Icon(Icons.person, size: 60, color: AppColors.textSecondary) 
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: AppColors.surface,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (context) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.photo_library, color: AppColors.primary),
                                  title: const Text('Pick from Gallery'),
                                  onTap: () async {
                                    Navigator.pop(context);
                                    try {
                                      final XFile? image = await picker.pickImage(
                                        source: ImageSource.gallery,
                                        maxWidth: 512,
                                        maxHeight: 512,
                                        imageQuality: 80,
                                      );
                                      if (image != null) {
                                        final bytes = await image.readAsBytes();
                                        setState(() => _base64Image = base64Encode(bytes));
                                        debugPrint('Gallery image picked successfully. Size: ${bytes.length} bytes');
                                      } else {
                                        debugPrint('Gallery picker returned null (user cancelled?)');
                                      }
                                    } catch (e) {
                                      debugPrint('Error picking from gallery: $e');
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error picking image: $e'), backgroundColor: AppColors.danger),
                                        );
                                      }
                                    }
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.camera_alt, color: AppColors.primary),
                                  title: const Text('Take a Photo'),
                                  onTap: () async {
                                    Navigator.pop(context);
                                    try {
                                      final XFile? image = await picker.pickImage(
                                        source: ImageSource.camera,
                                        maxWidth: 512,
                                        maxHeight: 512,
                                        imageQuality: 80,
                                      );
                                      if (image != null) {
                                        final bytes = await image.readAsBytes();
                                        setState(() => _base64Image = base64Encode(bytes));
                                        debugPrint('Camera image captured successfully. Size: ${bytes.length} bytes');
                                      }
                                    } catch (e) {
                                      debugPrint('Error capturing from camera: $e');
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error taking photo: $e'), backgroundColor: AppColors.danger),
                                        );
                                      }
                                    }
                                  },
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildLabel('Full Name'),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline)),
            ),
            const SizedBox(height: 24),
            _buildLabel('Phone Number'),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.phone_outlined)),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 24),
            _buildLabel('Email Address'),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.email_outlined)),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 48),
            GradientButton(
              label: _isLoading ? 'Saving...' : 'Save Changes',
              onPressed: _isLoading ? null : _handleUpdate,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14));
  }
}

