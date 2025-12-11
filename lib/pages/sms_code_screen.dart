import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/phone_auth_provider.dart';

class SmsCodeScreen extends StatefulWidget {
  const SmsCodeScreen({super.key});

  @override
  State<SmsCodeScreen> createState() => _SmsCodeScreenState();
}

class _SmsCodeScreenState extends State<SmsCodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<PhoneAuthProvider>();
    await provider.confirmCode(_codeController.text.trim());

    if (!mounted) return;
    if (provider.step == PhoneAuthStep.verified) {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    }
  }

  Future<void> _resend() async {
    final provider = context.read<PhoneAuthProvider>();
    if (provider.phoneNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number missing; go back and re-enter')),
      );
      return;
    }
    await provider.sendCode(provider.phoneNumber!);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PhoneAuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Enter SMS code')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (provider.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  provider.errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '6-digit code'),
                maxLength: 6,
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.length != 6) return 'Enter the 6-digit code';
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: provider.isLoading ? null : _submit,
                child: provider.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Verify'),
              ),
            ),
            TextButton(
              onPressed: provider.isLoading ? null : _resend,
              child: const Text('Resend code'),
            ),
          ],
        ),
      ),
    );
  }
}
