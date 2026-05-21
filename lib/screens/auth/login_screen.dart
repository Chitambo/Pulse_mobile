import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(_usernameCtrl.text.trim(), _passwordCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (!ok && auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error!), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const Icon(Icons.hub_rounded, size: 64, color: Colors.white),
                const SizedBox(height: 8),
                const Text(
                  'Pulse',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const Text('W&C Computer Limited', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 40),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Sign In',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _usernameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Username or Email',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordCtrl,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: 24),
                          _loading
                              ? const Center(child: CircularProgressIndicator())
                              : ElevatedButton(
                                  onPressed: _submit,
                                  child: const Text('Sign In'),
                                ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
