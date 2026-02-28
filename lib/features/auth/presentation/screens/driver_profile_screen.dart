import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../app/providers/app_providers.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../auth/presentation/state/auth_state.dart';

/// Full-featured profile screen with editable fields, password change,
/// account stats, and logout functionality.
class DriverProfileScreen extends ConsumerStatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  ConsumerState<DriverProfileScreen> createState() =>
      _DriverProfileScreenState();
}

class _DriverProfileScreenState extends ConsumerState<DriverProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  bool _isEditing = false;
  bool _isSaving = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _nameController = TextEditingController(text: user?.name ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      final result = await ref
          .read(authRepositoryProvider)
          .updateProfile(
            userId: user.id,
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
          );

      result.fold(
        (failure) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${failure.message}'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        (updatedUser) {
          ref.read(currentUserProvider.notifier).state = updatedUser;
          if (mounted) {
            setState(() => _isEditing = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Profile updated successfully'),
                  ],
                ),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: AppColors.error),
            SizedBox(width: 12),
            Text('Sign Out'),
          ],
        ),
        content: const Text(
          'Are you sure you want to sign out? Any unsaved changes will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authNotifierProvider.notifier).signOut();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 12),
            Text('Delete Account'),
          ],
        ),
        content: const Text(
          'This action is irreversible. All your data will be permanently deleted. '
          'Are you absolutely sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Account deletion requested. Contact admin.'),
                  backgroundColor: AppColors.warning,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          if (!_isEditing)
            IconButton(
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Profile',
            )
          else
            TextButton(
              onPressed: () {
                _nameController.text = user.name;
                _phoneController.text = user.phone;
                setState(() => _isEditing = false);
              },
              child: const Text('Cancel'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // ── Avatar & Info ──
              _buildAvatarSection(
                user,
              ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1),

              const SizedBox(height: 28),

              // ── Editable Fields ──
              _buildInfoCard(
                user,
              ).animate().fadeIn(duration: 400.ms, delay: 100.ms),

              const SizedBox(height: 20),

              // ── Account Stats ──
              _buildStatsCard(
                user,
              ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

              const SizedBox(height: 20),

              // ── Save Button ──
              if (_isEditing)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveProfile,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                  ),
                ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2),

              const SizedBox(height: 20),

              // ── Actions ──
              _buildActionsCard().animate().fadeIn(
                duration: 400.ms,
                delay: 300.ms,
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection(UserModel user) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _getRoleBadgeColor(user.role),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(
                _getRoleIcon(user.role),
                color: Colors.white,
                size: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          user.name,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: _getRoleBadgeColor(user.role).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            user.role.toUpperCase(),
            style: TextStyle(
              color: _getRoleBadgeColor(user.role),
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Personal Information',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          // Name
          TextFormField(
            controller: _nameController,
            enabled: _isEditing,
            decoration: InputDecoration(
              labelText: 'Full Name',
              prefixIcon: const Icon(
                Icons.person_outline,
                color: AppColors.primary,
              ),
              filled: true,
              fillColor: _isEditing ? Colors.white : AppColors.backgroundLight,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Name is required';
              }
              if (value.trim().length < 2) {
                return 'Name must be at least 2 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          // Phone
          TextFormField(
            controller: _phoneController,
            enabled: _isEditing,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Phone Number',
              prefixIcon: const Icon(
                Icons.phone_outlined,
                color: AppColors.primary,
              ),
              filled: true,
              fillColor: _isEditing ? Colors.white : AppColors.backgroundLight,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Phone is required';
              }
              if (value.trim().length < 8) {
                return 'Enter a valid phone number';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          // Email (read-only)
          TextFormField(
            initialValue: user.email,
            enabled: false,
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: const Icon(
                Icons.email_outlined,
                color: AppColors.textHint,
              ),
              filled: true,
              fillColor: AppColors.backgroundLight,
              helperText: 'Email cannot be changed',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account Details',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _infoRow(
            Icons.badge_outlined,
            'User ID',
            user.id.substring(0, 8).toUpperCase(),
          ),
          _infoRow(Icons.security_outlined, 'Role', user.role.toUpperCase()),
          _infoRow(
            Icons.calendar_today_outlined,
            'Joined',
            user.createdAt != null
                ? '${user.createdAt!.day}/${user.createdAt!.month}/${user.createdAt!.year}'
                : 'N/A',
          ),
          _infoRow(
            user.isActive ? Icons.check_circle_outline : Icons.block,
            'Status',
            user.isActive ? 'Active' : 'Inactive',
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textHint, fontSize: 13),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        children: [
          _actionTile(
            icon: Icons.lock_outline,
            label: 'Change Password',
            onTap: _showChangePasswordDialog,
          ),
          const Divider(height: 1, indent: 56),
          _actionTile(
            icon: Icons.logout,
            label: 'Sign Out',
            color: AppColors.warning,
            onTap: _confirmLogout,
          ),
          const Divider(height: 1, indent: 56),
          _actionTile(
            icon: Icons.delete_forever,
            label: 'Delete Account',
            color: AppColors.error,
            onTap: _confirmDeleteAccount,
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.textSecondary),
      title: Text(
        label,
        style: TextStyle(
          color: color ?? AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    final dialogFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: AppColors.primary),
            SizedBox(width: 12),
            Text('Change Password'),
          ],
        ),
        content: Form(
          key: dialogFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentPasswordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newPasswordCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password'),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v.length < 6) return 'Min 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmPasswordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                ),
                validator: (v) {
                  if (v != newPasswordCtrl.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (dialogFormKey.currentState!.validate()) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Password change feature coming soon'),
                    backgroundColor: AppColors.info,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Color _getRoleBadgeColor(String role) {
    switch (role) {
      case 'admin':
        return AppColors.accent;
      case 'driver':
        return AppColors.info;
      default:
        return AppColors.primary;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'driver':
        return Icons.local_shipping;
      default:
        return Icons.person;
    }
  }
}
