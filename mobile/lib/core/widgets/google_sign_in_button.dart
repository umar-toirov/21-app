import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';

/// Google sign-in button (Supabase OAuth).
class GoogleSignInButton extends ConsumerStatefulWidget {
  const GoogleSignInButton({super.key, this.onError});

  final ValueChanged<String>? onError;

  @override
  ConsumerState<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends ConsumerState<GoogleSignInButton> {
  bool _loading = false;
  bool _pressed = false;

  Future<void> _onTap() async {
    setState(() => _loading = true);
    try {
      final started = await ref.read(apiRepositoryProvider).signInWithGoogle();
      if (!started) {
        widget.onError?.call(
          'Google sign-in did not start. Add http://127.0.0.1:8090/auth/callback '
          'to Supabase Auth → URL Configuration → Redirect URLs.',
        );
        if (mounted) setState(() => _loading = false);
      }
      // Web redirects away on success; keep spinner until navigation.
    } on AuthException catch (e) {
      widget.onError?.call(_friendlyAuthError(e.message));
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      widget.onError?.call(_friendlyAuthError('$e'));
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyAuthError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('provider is not enabled') ||
        lower.contains('unsupported provider')) {
      return 'Google is not fully enabled in Supabase yet.\n\n'
          '1. Open Authentication → Providers → Google\n'
          '2. Turn Google ON and paste Client ID + Client Secret from Google Cloud\n'
          '3. Save\n'
          '4. Add Redirect URL: ${Uri.base.origin}/auth/callback';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _loading ? null : (_) => setState(() => _pressed = true),
      onTapUp: _loading
          ? null
          : (_) {
              setState(() => _pressed = false);
              _onTap();
            },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: _pressed ? AppColors.background : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderStrong, width: 1),
        ),
        alignment: Alignment.center,
        child: _loading
            ? SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.blue),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/brand/google_logo.svg',
                    width: 22,
                    height: 22,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.borderStrong, thickness: 1.5)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(child: Divider(color: AppColors.borderStrong, thickness: 1.5)),
      ],
    );
  }
}
