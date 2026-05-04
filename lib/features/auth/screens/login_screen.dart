import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/routing/app_router.dart' as router;

final _authLoadingProvider = StateProvider<bool>((ref) => false);
final _authErrorProvider = StateProvider<String?>((ref) => null);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  late AnimationController _slideController;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    // Developer Offline Bypass (No Firebase API calls made)
    if (_emailController.text.trim() == 'ankit.sengupta05@gmail.com') {
      router.devModeOfflineBypass = true;
      context.go('/chat');
      return;
    }

    ref.read(_authLoadingProvider.notifier).state = true;
    ref.read(_authErrorProvider.notifier).state = null;
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on FirebaseAuthException catch (e) {
      ref.read(_authErrorProvider.notifier).state = _mapError(e.code);
    } finally {
      if (mounted) ref.read(_authLoadingProvider.notifier).state = false;
    }
  }

  Future<void> _signInWithGoogle() async {
    ref.read(_authLoadingProvider.notifier).state = true;
    ref.read(_authErrorProvider.notifier).state = null;
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        // User canceled the sign in
        if (mounted) ref.read(_authLoadingProvider.notifier).state = false;
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      ref.read(_authErrorProvider.notifier).state = _mapError(e.code);
    } catch (e) {
      ref.read(_authErrorProvider.notifier).state = 'Google Sign-In failed.';
    } finally {
      if (mounted) ref.read(_authLoadingProvider.notifier).state = false;
    }
  }

  String _mapError(String code) => switch (code) {
        'user-not-found' => 'No account found with this email.',
        'wrong-password' => 'Incorrect password.',
        'invalid-email' => 'Invalid email address.',
        'user-disabled' => 'This account has been disabled.',
        'too-many-requests' => 'Too many attempts. Try again later.',
        _ => 'Authentication failed. Please try again.',
      };

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(_authLoadingProvider);
    final error = ref.watch(_authErrorProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // ── Left branding panel ──────────────────────────────────────
          Expanded(
            flex: 2,
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(right: BorderSide(color: AppColors.border)),
              ),
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.accent.withOpacity(0.4)),
                        ),
                        child: const Icon(Icons.android,
                            color: AppColors.accent, size: 44),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'CYBORG',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 10,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Local-First AGI Platform',
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            letterSpacing: 2),
                      ),
                      const SizedBox(height: 48),
                      ...[
                        ('🧠', 'Local LLM Inference'),
                        ('🕸️', 'Knowledge Graph'),
                        ('🔒', 'Privacy-First'),
                        ('📦', '100% Offline'),
                      ].map((f) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(f.$1,
                                    style: const TextStyle(fontSize: 16)),
                                const SizedBox(width: 10),
                                Text(
                                  f.$2,
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // ── Right login form ──────────────────────────────────────────
          Expanded(
            flex: 3,
            child: Center(
              child: SlideTransition(
                position: _slideAnim,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(40),
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome back',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Sign in to your Cyborg instance',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 14),
                          ),
                          const SizedBox(height: 32),
                          // Error banner
                          if (error != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.accentRed.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color:
                                        AppColors.accentRed.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline,
                                      color: AppColors.accentRed, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      error,
                                      style: const TextStyle(
                                          color: AppColors.accentRed,
                                          fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          // Email
                          const _FieldLabel('Email'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(
                                color: AppColors.textPrimary, fontSize: 14),
                            decoration: const InputDecoration(
                              hintText: 'you@example.com',
                              prefixIcon: Icon(Icons.email_outlined, size: 18),
                            ),
                            validator: (v) =>
                                v?.isEmpty == true ? 'Email is required' : null,
                          ),
                          const SizedBox(height: 16),
                          // Password
                          const _FieldLabel('Password'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(
                                color: AppColors.textPrimary, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: '••••••••',
                              prefixIcon:
                                  const Icon(Icons.lock_outline, size: 18),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 18,
                                ),
                                onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: (v) => v?.isEmpty == true
                                ? 'Password is required'
                                : null,
                            onFieldSubmitted: (_) => _signIn(),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : _signIn,
                              child: isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Sign In'),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Expanded(
                                  child: Divider(color: AppColors.border)),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text('OR',
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12)),
                              ),
                              const Expanded(
                                  child: Divider(color: AppColors.border)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: OutlinedButton.icon(
                              onPressed: isLoading ? null : _signInWithGoogle,
                              icon: const Icon(Icons.g_mobiledata, size: 28),
                              label: const Text('Continue with Google'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                                side: const BorderSide(color: AppColors.border),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: TextButton(
                              onPressed: () => context.go('/auth/register'),
                              child: const Text(
                                "Don't have an account? Create one",
                                style: TextStyle(
                                    color: AppColors.accent, fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      );
}
