import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class ChangePasswordScreen extends StatefulWidget {
  final bool forced;
  const ChangePasswordScreen({super.key, this.forced = false});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.changePassword(_currentCtrl.text, _newCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      if (!widget.forced) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Failed'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.forced
          ? null
          : AppBar(title: const Text('Change Password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.forced) ...[
                  const SizedBox(height: 32),
                  const Icon(Icons.lock_reset, size: 64, color: Colors.orange),
                  const SizedBox(height: 12),
                  const Text('Change Your Password',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('You must change your password before continuing.',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 32),
                ],
                _PasswordField(controller: _currentCtrl, label: 'Current Password'),
                const SizedBox(height: 16),
                _PasswordField(
                  controller: _newCtrl,
                  label: 'New Password',
                  validator: (v) => v!.length < 6 ? 'Min 6 characters' : null,
                ),
                const SizedBox(height: 16),
                _PasswordField(
                  controller: _confirmCtrl,
                  label: 'Confirm New Password',
                  validator: (v) => v != _newCtrl.text ? 'Passwords do not match' : null,
                ),
                const SizedBox(height: 24),
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(onPressed: _submit, child: const Text('Update Password')),
                if (widget.forced) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.read<AuthProvider>().logout(),
                    child: const Text('Sign out instead'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;

  const _PasswordField({required this.controller, required this.label, this.validator});

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: widget.controller,
        obscureText: _obscure,
        decoration: InputDecoration(
          labelText: widget.label,
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        validator: widget.validator ?? (v) => v!.isEmpty ? 'Required' : null,
      );
}
