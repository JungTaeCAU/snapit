import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class ConfirmAccountScreen extends StatefulWidget {
  final String email;
  final String password;
  const ConfirmAccountScreen(
      {super.key, required this.email, required this.password});

  @override
  State<ConfirmAccountScreen> createState() => _ConfirmAccountScreenState();
}

class _ConfirmAccountScreenState extends State<ConfirmAccountScreen> {
  final _codeController = TextEditingController();
  final _authService = AuthService.instance;
  bool _isLoading = false;
  bool _isResending = false;
  String? _message;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _confirmCode() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      await _authService.confirmSignUp(widget.email, _codeController.text);
      final session = await _authService.signIn(widget.email, widget.password);
      if (session != null && mounted) {
        Navigator.pushReplacementNamed(context, '/onboarding');
      }
    } catch (e) {
      setState(() {
        _message = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resendCode() async {
    setState(() {
      _isResending = true;
      _message = null;
    });
    try {
      await _authService.resendCode(widget.email);
      setState(() {
        _message = '인증 코드가 재전송되었습니다.';
      });
    } catch (e) {
      setState(() {
        _message = e.toString();
      });
    } finally {
      setState(() {
        _isResending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final maskedEmail = widget.email.replaceRange(
        1, widget.email.indexOf('@'), '*' * (widget.email.indexOf('@') - 1));
    return Scaffold(
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Confirm your account',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Icon(Icons.check_circle_outline,
                    size: 48, color: Color(0xFF006FFD)),
                const SizedBox(height: 16),
                Text(
                  'We have sent a code in an Email message to $maskedEmail. To confirm your account, enter your code.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Code',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isResending ? null : _resendCode,
                      child: _isResending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Resend code'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      _message!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _confirmCode,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF006FFD),
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Confirm account',
                          style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
