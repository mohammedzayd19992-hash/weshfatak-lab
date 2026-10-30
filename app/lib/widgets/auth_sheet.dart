import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_state.dart';
import '../brand.dart';
import '../config.dart';

/// Opens the sign in / create account sheet. Returns true once signed in.
Future<bool> showAuthSheet(
  BuildContext context, {
  bool register = false,
  String? reason,
}) async {
  final signedIn = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => AuthSheet(register: register, reason: reason),
  );
  return signedIn ?? false;
}

class AuthSheet extends StatefulWidget {
  const AuthSheet({super.key, this.register = false, this.reason});

  final bool register;
  final String? reason;

  @override
  State<AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends State<AuthSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late bool _register = widget.register;
  bool _busy = false;
  bool _hidePassword = true;
  bool _canResend = false; // the account exists but its email is not confirmed
  bool _closed = false;
  String? _error;
  String? _notice;

  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Signed in from the email link while this sheet was open: close it.
    if (AppScope.of(context).signedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _close());
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _close() {
    if (_closed || !mounted || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _closed = true;
    Navigator.of(context).pop(true);
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _canResend = false;
      _error = null;
      _notice = null;
    });
    final auth = Supabase.instance.client.auth;
    final email = _email.text.trim();
    try {
      if (_register) {
        final response = await auth.signUp(
          email: email,
          password: _password.text,
          data: {'display_name': _name.text.trim()},
          emailRedirectTo: authRedirectUrl,
        );
        // With email confirmation on, the account has no session until the link is opened.
        if (response.session == null) {
          setState(() {
            _register = false;
            _notice =
                'Account created. Open the link we sent to $email on this phone to finish.';
          });
          return;
        }
      } else {
        await auth.signInWithPassword(email: email, password: _password.text);
      }
      _close();
    } on AuthException catch (error) {
      setState(() {
        _canResend = error.code == 'email_not_confirmed';
        _error = _friendly(error);
      });
    } catch (_) {
      setState(
        () => _error =
            'Could not connect. Check your internet connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    final email = _email.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: authRedirectUrl,
      );
      setState(() {
        _canResend = false;
        _notice = 'We sent a new link to $email. Open it on this phone.';
      });
    } on AuthException catch (error) {
      setState(() => _error = _friendly(error));
    } catch (_) {
      setState(
        () => _error =
            'Could not connect. Check your internet connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendly(AuthException error) => switch (error.code) {
    'invalid_credentials' => 'Email or password is incorrect.',
    'user_already_exists' ||
    'email_exists' => 'This email already has an account. Sign in instead.',
    'email_not_confirmed' =>
      'Confirm your email first: open the link we sent you on this phone.',
    'weak_password' => 'Choose a stronger password with at least 8 characters.',
    'over_email_send_rate_limit' || 'over_request_rate_limit' =>
      'Too many attempts. Wait a minute and try again.',
    _ => error.message,
  };

  void _switchMode() => setState(() {
    _register = !_register;
    _canResend = false;
    _error = null;
    _notice = null;
  });

  @override
  Widget build(BuildContext context) {
    final subtitle =
        widget.reason ??
        (_register
            ? 'Join the conversation about campus news.'
            : 'Sign in to comment and keep your profile.');
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: AutofillGroup(
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    _register ? 'Create your account' : 'Welcome back',
                    key: ValueKey(_register),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(color: Brand.muted, fontSize: 15),
                ),
                const SizedBox(height: 22),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.topCenter,
                  child: _register
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextFormField(
                            controller: _name,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            maxLength: 60,
                            decoration: const InputDecoration(
                              labelText: 'Name',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                              counterText: '',
                            ),
                            validator: (value) => (value ?? '').trim().isEmpty
                                ? 'Enter your name'
                                : null,
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                  validator: (value) =>
                      _emailPattern.hasMatch((value ?? '').trim())
                      ? null
                      : 'Enter a valid email',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: _hidePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: [
                    _register
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    helperText: _register ? 'At least 8 characters' : null,
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _hidePassword = !_hidePassword),
                      icon: Icon(
                        _hidePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      tooltip: _hidePassword
                          ? 'Show password'
                          : 'Hide password',
                    ),
                  ),
                  validator: (value) {
                    final password = value ?? '';
                    if (password.isEmpty) return 'Enter your password';
                    if (_register && password.length < 8) {
                      return 'Use at least 8 characters';
                    }
                    return null;
                  },
                ),
                if (_error != null)
                  _Message(
                    text: _error!,
                    color: Brand.danger,
                    icon: Icons.error_outline,
                  ),
                if (_canResend)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: _busy ? null : _resend,
                      icon: const Icon(Icons.forward_to_inbox_rounded),
                      label: const Text('Send the link again'),
                    ),
                  ),
                if (_notice != null)
                  _Message(
                    text: _notice!,
                    color: Brand.mint,
                    icon: Icons.mark_email_read_outlined,
                  ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : Text(_register ? 'Create account' : 'Sign in'),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: _busy ? null : _switchMode,
                  child: Text(
                    _register
                        ? 'I already have an account'
                        : 'New here? Create an account',
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

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.color, required this.icon});

  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 14),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: TextStyle(color: color, height: 1.35)),
        ),
      ],
    ),
  );
}
