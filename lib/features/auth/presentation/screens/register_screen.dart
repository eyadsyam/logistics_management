import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../state/auth_state.dart';

/// Premium registration screen with multi-step form, role selection,
/// password strength indicator, and glassmorphism design.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreedToTerms = false;
  String _selectedRole = AppConstants.roleClient;

  // Page controller for step-by-step registration
  final PageController _pageController = PageController();
  int _currentStep = 0;
  static const int _totalSteps = 3;

  // Password strength
  double _passwordStrength = 0;
  String _passwordStrengthLabel = '';
  Color _passwordStrengthColor = AppColors.error;

  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _passwordController.addListener(_evaluatePasswordStrength);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _pageController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _evaluatePasswordStrength() {
    final password = _passwordController.text;
    double strength = 0;
    String label = '';
    Color color = AppColors.error;

    if (password.isEmpty) {
      setState(() {
        _passwordStrength = 0;
        _passwordStrengthLabel = '';
        _passwordStrengthColor = AppColors.error;
      });
      return;
    }

    // Length checks
    if (password.length >= 6) strength += 0.2;
    if (password.length >= 8) strength += 0.1;
    if (password.length >= 12) strength += 0.1;

    // Complexity checks
    if (password.contains(RegExp(r'[A-Z]'))) strength += 0.15;
    if (password.contains(RegExp(r'[a-z]'))) strength += 0.1;
    if (password.contains(RegExp(r'[0-9]'))) strength += 0.15;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength += 0.2;

    strength = strength.clamp(0.0, 1.0);

    if (strength < 0.3) {
      label = 'Weak';
      color = AppColors.error;
    } else if (strength < 0.6) {
      label = 'Fair';
      color = AppColors.warning;
    } else if (strength < 0.8) {
      label = 'Good';
      color = AppColors.info;
    } else {
      label = 'Strong';
      color = AppColors.success;
    }

    setState(() {
      _passwordStrength = strength;
      _passwordStrengthLabel = label;
      _passwordStrengthColor = color;
    });
  }

  void _nextStep() {
    if (_currentStep == 0) {
      // Validate role selection (always valid)
      _animateToStep(_currentStep + 1);
    } else if (_currentStep == 1) {
      // Validate personal info
      if (_nameController.text.trim().isEmpty) {
        _showValidationError('Please enter your full name');
        return;
      }
      if (_emailController.text.trim().isEmpty ||
          !_emailController.text.contains('@')) {
        _showValidationError('Please enter a valid email address');
        return;
      }
      if (_phoneController.text.trim().isEmpty) {
        _showValidationError('Please enter your phone number');
        return;
      }
      _animateToStep(_currentStep + 1);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _animateToStep(_currentStep - 1);
    }
  }

  void _animateToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  void _showValidationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreedToTerms) {
      _showValidationError('Please agree to the Terms & Conditions');
      return;
    }

    await ref
        .read(authNotifierProvider.notifier)
        .signUp(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          phone: _phoneController.text.trim(),
          role: _selectedRole,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    ref.listen<AuthState>(authNotifierProvider, (_, state) {
      state.whenOrNull(
        error: (message) => _showValidationError(message),
        authenticated: (_) {
          // Navigation handled by router's redirect
        },
      );
    });

    final isLoading = authState == const AuthState.loading();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.5, 1.0],
            colors: [
              AppColors.backgroundLight,
              AppColors.surfaceLight,
              AppColors.backgroundLight,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Top Bar with Back Arrow ──
              _buildTopBar(),

              // ── Header ──
              _buildHeader()
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .slideY(begin: -0.2, end: 0),

              const SizedBox(height: 16),

              // ── Step Indicator ──
              _buildStepIndicator().animate().fadeIn(
                duration: 500.ms,
                delay: 100.ms,
              ),

              const SizedBox(height: 24),

              // ── Step Pages ──
              Expanded(
                child: Form(
                  key: _formKey,
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (index) =>
                        setState(() => _currentStep = index),
                    children: [
                      _buildStep1RoleSelection(),
                      _buildStep2PersonalInfo(),
                      _buildStep3Security(isLoading),
                    ],
                  ),
                ),
              ),

              // ── Login Link ──
              _buildLoginLink().animate().fadeIn(
                duration: 500.ms,
                delay: 400.ms,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────
  //  Top Bar
  // ────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          if (_currentStep > 0)
            IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.textSecondary,
              ),
              onPressed: _previousStep,
            )
          else
            IconButton(
              icon: const Icon(
                Icons.close_rounded,
                color: AppColors.textSecondary,
              ),
              onPressed: () => context.go('/login'),
            ),
          const Spacer(),
          Text(
            'Step ${_currentStep + 1} of $_totalSteps',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textHint),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────
  //  Header
  // ────────────────────────────────────────────
  Widget _buildHeader() {
    return Column(
      children: [
        // Animated icon
        Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.primaryGradient,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(
                Icons.person_add_alt_1_rounded,
                size: 30,
                color: Colors.white,
              ),
            )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scaleXY(begin: 1, end: 1.05, duration: 1800.ms),
        const SizedBox(height: 14),
        Text(
          'Create Account',
          style: Theme.of(
            context,
          ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          _getStepSubtitle(),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textHint),
        ),
      ],
    );
  }

  String _getStepSubtitle() {
    switch (_currentStep) {
      case 0:
        return 'Choose your role to get started';
      case 1:
        return 'Tell us about yourself';
      case 2:
        return 'Secure your account';
      default:
        return '';
    }
  }

  // ────────────────────────────────────────────
  //  Step Indicator
  // ────────────────────────────────────────────
  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Row(
        children: List.generate(_totalSteps * 2 - 1, (index) {
          if (index.isOdd) {
            // Connector line
            final stepBefore = index ~/ 2;
            final isCompleted = _currentStep > stepBefore;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(1),
                  color: isCompleted ? AppColors.accent : AppColors.glassBorder,
                ),
              ),
            );
          }

          // Step dot
          final stepIndex = index ~/ 2;
          final isActive = _currentStep == stepIndex;
          final isCompleted = _currentStep > stepIndex;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            width: isActive ? 36 : 28,
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: isActive || isCompleted
                  ? const LinearGradient(colors: AppColors.accentGradient)
                  : null,
              color: !isActive && !isCompleted ? AppColors.cardLight : null,
              border: Border.all(
                color: isActive || isCompleted
                    ? AppColors.accent
                    : AppColors.glassBorder,
                width: 1.5,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.3),
                        blurRadius: 8,
                      ),
                    ]
                  : [],
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.black,
                    )
                  : Text(
                      '${stepIndex + 1}',
                      style: TextStyle(
                        color: isActive ? Colors.black : AppColors.textHint,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
            ),
          );
        }),
      ),
    );
  }

  // ────────────────────────────────────────────
  //  Step 1: Role Selection
  // ────────────────────────────────────────────
  Widget _buildStep1RoleSelection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 8),

          // ── Role Cards ──
          _buildRoleCard(
                role: AppConstants.roleClient,
                title: 'Client',
                subtitle: 'Ship packages and track deliveries in real-time',
                icon: Icons.business_center_rounded,
                features: [
                  'Create shipments',
                  'Live GPS tracking',
                  'Delivery history',
                ],
              )
              .animate()
              .fadeIn(duration: 400.ms, delay: 200.ms)
              .slideX(begin: -0.1),

          const SizedBox(height: 16),

          _buildRoleCard(
                role: AppConstants.roleDriver,
                title: 'Driver',
                subtitle: 'Accept and deliver shipments across the fleet',
                icon: Icons.local_shipping_rounded,
                features: [
                  'Accept shipments',
                  'Route optimization',
                  'Earnings dashboard',
                ],
              )
              .animate()
              .fadeIn(duration: 400.ms, delay: 350.ms)
              .slideX(begin: 0.1),

          const SizedBox(height: 32),

          // ── Continue Button ──
          _buildContinueButton(onPressed: _nextStep),
        ],
      ),
    );
  }

  Widget _buildRoleCard({
    required String role,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<String> features,
  }) {
    final isSelected = _selectedRole == role;

    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withValues(alpha: 0.08)
              : AppColors.glassBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.glassBorder,
            width: isSelected ? 1.5 : 0.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            // Icon container
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(colors: AppColors.accentGradient)
                    : null,
                color: isSelected ? null : AppColors.cardLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                size: 28,
                color: isSelected ? Colors.black : AppColors.textHint,
              ),
            ),
            const SizedBox(width: 16),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: isSelected
                              ? AppColors.accent
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? AppColors.accent
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.accent
                                : AppColors.textHint,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                size: 14,
                                color: Colors.black,
                              )
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.textHint),
                  ),
                  const SizedBox(height: 10),
                  // Feature chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: features
                        .map(
                          (f) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.accent.withValues(alpha: 0.12)
                                  : AppColors.cardElevated,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              f,
                              style: TextStyle(
                                fontSize: 11,
                                color: isSelected
                                    ? AppColors.accent
                                    : AppColors.textHint,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────
  //  Step 2: Personal Information
  // ────────────────────────────────────────────
  Widget _buildStep2PersonalInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.glassBackground,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.glassBorder, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Personal Details',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Full Name ──
            _buildTextField(
              controller: _nameController,
              label: 'Full Name',
              hint: 'Enter your full name',
              icon: Icons.badge_outlined,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 18),

            // ── Email ──
            _buildTextField(
              controller: _emailController,
              label: 'Email Address',
              hint: 'you@example.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required';
                if (!RegExp(
                  r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$',
                ).hasMatch(v.trim())) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),

            // ── Phone Number ──
            _buildTextField(
              controller: _phoneController,
              label: 'Phone Number',
              hint: '+20 123 456 7890',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Phone is required' : null,
            ),
            const SizedBox(height: 28),

            // ── Continue Button ──
            _buildContinueButton(onPressed: _nextStep),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.accent, size: 20),
        filled: true,
        fillColor: AppColors.cardLight.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.glassBorder,
            width: 0.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: validator,
    );
  }

  // ────────────────────────────────────────────
  //  Step 3: Password & Confirmation
  // ────────────────────────────────────────────
  Widget _buildStep3Security(bool isLoading) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.glassBackground,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.glassBorder, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: AppColors.accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Account Security',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Password ──
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Create a strong password',
                prefixIcon: const Icon(
                  Icons.lock_outlined,
                  color: AppColors.accent,
                  size: 20,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.textHint,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                filled: true,
                fillColor: AppColors.cardLight.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.glassBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.glassBorder,
                    width: 0.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.accent,
                    width: 1.5,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.error,
                    width: 1,
                  ),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                if (v.length < 6) return 'Min 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 12),

            // ── Password Strength Indicator ──
            if (_passwordController.text.isNotEmpty) ...[
              _buildPasswordStrengthBar(),
              const SizedBox(height: 8),
              _buildPasswordRequirements(),
              const SizedBox(height: 18),
            ] else
              const SizedBox(height: 18),

            // ── Confirm Password ──
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirm,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) =>
                  !isLoading && _agreedToTerms ? _handleRegister() : null,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                hintText: 'Re-enter your password',
                prefixIcon: const Icon(
                  Icons.lock_reset_outlined,
                  color: AppColors.accent,
                  size: 20,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.textHint,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
                filled: true,
                fillColor: AppColors.cardLight.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.glassBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.glassBorder,
                    width: 0.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.accent,
                    width: 1.5,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.error,
                    width: 1,
                  ),
                ),
              ),
              validator: (v) {
                if (v != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // ── Terms & Conditions ──
            _buildTermsCheckbox(),
            const SizedBox(height: 24),

            // ── Register Button ──
            _buildRegisterButton(isLoading),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordStrengthBar() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Password Strength',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textHint),
            ),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: _passwordStrengthColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              child: Text(_passwordStrengthLabel),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _passwordStrength),
            duration: const Duration(milliseconds: 350),
            builder: (context, value, _) {
              return LinearProgressIndicator(
                value: value,
                minHeight: 5,
                backgroundColor: AppColors.cardLight,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _passwordStrengthColor,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordRequirements() {
    final password = _passwordController.text;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _buildRequirement('6+ chars', password.length >= 6),
        _buildRequirement('Uppercase', password.contains(RegExp(r'[A-Z]'))),
        _buildRequirement('Number', password.contains(RegExp(r'[0-9]'))),
        _buildRequirement(
          'Special',
          password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')),
        ),
      ],
    );
  }

  Widget _buildRequirement(String label, bool met) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: met
            ? AppColors.success.withValues(alpha: 0.1)
            : AppColors.cardLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: met
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.glassBorder,
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 14,
            color: met ? AppColors.success : AppColors.textHint,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: met ? AppColors.success : AppColors.textHint,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsCheckbox() {
    return GestureDetector(
      onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: _agreedToTerms ? AppColors.accent : Colors.transparent,
              border: Border.all(
                color: _agreedToTerms ? AppColors.accent : AppColors.textHint,
                width: 1.5,
              ),
            ),
            child: _agreedToTerms
                ? const Icon(Icons.check, size: 15, color: Colors.black)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                children: [
                  const TextSpan(text: 'I agree to the '),
                  TextSpan(
                    text: 'Terms of Service',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterButton(bool isLoading) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: isLoading ? null : _handleRegister,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.black,
          disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.black,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.rocket_launch_rounded, size: 20),
                  const SizedBox(width: 10),
                  const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ────────────────────────────────────────────
  //  Shared Widgets
  // ────────────────────────────────────────────
  Widget _buildContinueButton({required VoidCallback onPressed}) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text(
              'Continue',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Already have an account? ',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          GestureDetector(
            onTap: () => context.go('/login'),
            child: Text(
              'Sign In',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
