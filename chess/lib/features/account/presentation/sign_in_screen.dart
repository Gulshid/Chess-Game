import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import 'auth_provider.dart';

enum _Mode { signIn, signUp }

/// Email/password sign in, sign up, and password reset — plus, when
/// opened while the current session is still an anonymous guest, an
/// "upgrade this guest account" mode that calls
/// [AuthProvider.upgradeGuestAccount] instead of [AuthProvider.signUp]
/// so the player's existing rating/stats/saved games carry over (see
/// that method's doc).
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  _Mode _mode = _Mode.signIn;
  bool _isSubmitting = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _isUpgradingGuest =>
      _mode == _Mode.signUp && !context.read<AuthProvider>().hasPermanentAccount;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final auth = context.read<AuthProvider>();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;
    final String name = _nameController.text.trim();

    final bool success = switch (_mode) {
      _Mode.signIn => await auth.signIn(email: email, password: password),
      _Mode.signUp when !auth.hasPermanentAccount =>
        await auth.upgradeGuestAccount(email: email, password: password, displayName: name),
      _Mode.signUp => await auth.signUp(email: email, password: password, displayName: name),
    };

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      Navigator.of(context).pop();
    } else if (auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.error!)));
    }
  }

  Future<void> _forgotPassword() async {
    final String email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter your email above first.')));
      return;
    }
    final bool sent = await context.read<AuthProvider>().sendPasswordReset(email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(sent ? 'Password reset email sent.' : 'Could not send reset email.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool signingUp = _mode == _Mode.signUp;
    return Scaffold(
      appBar: AppBar(title: Text(signingUp ? 'Create account' : 'Sign in')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.w),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (signingUp && _isUpgradingGuest) ...[
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'This keeps your current rating and game history — you\'re just adding a '
                      'password so you can sign back in on another device.',
                      style: TextStyle(fontSize: 12.sp),
                    ),
                  ),
                  SizedBox(height: 16.h),
                ],
                if (signingUp) ...[
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                  ),
                  SizedBox(height: 12.h),
                ],
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                ),
                SizedBox(height: 12.h),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
                ),
                if (!signingUp)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _forgotPassword,
                      child: const Text('Forgot password?'),
                    ),
                  ),
                SizedBox(height: 20.h),
                FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? SizedBox(
                          height: 18.h,
                          width: 18.h,
                          child: const CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(signingUp ? 'Create account' : 'Sign in'),
                ),
                SizedBox(height: 12.h),
                TextButton(
                  onPressed: () => setState(() => _mode = signingUp ? _Mode.signIn : _Mode.signUp),
                  child: Text(signingUp
                      ? 'Already have an account? Sign in'
                      : 'New here? Create an account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
