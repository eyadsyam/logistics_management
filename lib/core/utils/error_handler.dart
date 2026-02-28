import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Global error handler providing consistent error UI across the app.
/// Handles network errors, Firestore errors, auth errors, and generic exceptions.
class AppErrorHandler {
  AppErrorHandler._();

  /// Shows an error snackbar with proper styling and optional retry.
  static void showError(
    BuildContext context,
    dynamic error, {
    VoidCallback? retry,
  }) {
    final message = _mapError(error);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (retry != null)
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  retry();
                },
                child: const Text(
                  'RETRY',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: retry != null
            ? const Duration(seconds: 8)
            : const Duration(seconds: 4),
      ),
    );
  }

  /// Shows a success snackbar.
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Shows a warning snackbar.
  static void showWarning(BuildContext context, String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Maps various error types to user-friendly messages.
  static String _mapError(dynamic error) {
    final msg = error.toString().toLowerCase();

    // Network errors
    if (msg.contains('socketexception') ||
        msg.contains('no internet') ||
        msg.contains('network') ||
        msg.contains('connection refused')) {
      return 'No internet connection. Please check your network.';
    }
    if (msg.contains('timeout') || msg.contains('timed out')) {
      return 'Connection timed out. Please try again.';
    }

    // Firebase Auth errors
    if (msg.contains('user-not-found')) {
      return 'No user found with this email address.';
    }
    if (msg.contains('wrong-password') || msg.contains('invalid-credential')) {
      return 'Incorrect password. Please try again.';
    }
    if (msg.contains('email-already-in-use')) {
      return 'This email is already registered. Try signing in.';
    }
    if (msg.contains('weak-password')) {
      return 'Password is too weak. Use at least 6 characters.';
    }
    if (msg.contains('invalid-email')) {
      return 'Invalid email format. Please check your input.';
    }
    if (msg.contains('too-many-requests')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (msg.contains('user-disabled')) {
      return 'This account has been disabled. Contact admin.';
    }

    // Firestore errors
    if (msg.contains('permission-denied') ||
        msg.contains('missing or insufficient')) {
      return 'Permission denied. You don\'t have access to this resource.';
    }
    if (msg.contains('not-found')) {
      return 'The requested data was not found.';
    }
    if (msg.contains('already-exists')) {
      return 'This record already exists.';
    }
    if (msg.contains('unavailable')) {
      return 'Service temporarily unavailable. Please try again later.';
    }

    // Location errors
    if (msg.contains('location') && msg.contains('denied')) {
      return 'Location permission denied. Please enable it in settings.';
    }
    if (msg.contains('location') && msg.contains('disabled')) {
      return 'Location services are disabled. Please enable GPS.';
    }

    // Mapbox errors
    if (msg.contains('403') || msg.contains('forbidden')) {
      return 'Map service authorization failed. Check API token.';
    }
    if (msg.contains('429')) {
      return 'Too many map requests. Please wait a moment.';
    }

    // Generic
    if (msg.length > 120) {
      return 'An unexpected error occurred. Please try again.';
    }

    return error.toString();
  }
}

/// A reusable error display widget for async data.
class ErrorRetryWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorRetryWidget({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 40,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Oops! Something went wrong',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              AppErrorHandler._mapError(message),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textHint),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty state widget with customizable icon and message.
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.textHint),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}
