import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/providers/providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shared_widgets.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _acceptedTerms = false;
  bool _loading = false;
  String? _error;

  Future<void> _signup() async {
    if (!_acceptedTerms) {
      setState(() => _error = 'Please accept the terms');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final confirm = await ref.read(apiRepositoryProvider).signUp(
            _email.text.trim(),
            _password.text,
            _name.text.trim(),
          );
      if (!mounted) return;
      if (confirm == 'confirm_email') {
        setState(() =>
            _error = 'Account created! Check your email to confirm, then login.');
        return;
      }
      context.go(AppRoutes.onboarding);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not create account: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
              const AppIconMark(size: 72)
                  .animate()
                  .fadeIn()
                  .moveY(begin: 12, end: 0),
              const SizedBox(height: 16),
              Text(
                'Create your 21 account',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Join ILM HUB and start building discipline',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _email,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _password,
                decoration: const InputDecoration(
                  labelText: 'Password (min 6 chars)',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              SoftCard(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: CheckboxListTile(
                  value: _acceptedTerms,
                  onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                  activeColor: AppColors.teal,
                  title: const Text(
                    'I agree to Terms & Privacy Policy',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                SoftCard(
                  color: AppColors.orange.withValues(alpha: 0.08),
                  borderColor: AppColors.orange.withValues(alpha: 0.35),
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.orange,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Create Account',
                color: AppColors.teal,
                depthColor: AppColors.tealDepth,
                onPressed: _signup,
                isLoading: _loading,
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: () => context.push(AppRoutes.login),
                child: const Text(
                  'Already have an account? Login',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }
}
