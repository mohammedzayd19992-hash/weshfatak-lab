import 'package:flutter/material.dart';

import '../app_state.dart';
import '../brand.dart';
import '../data.dart';
import '../models.dart';
import '../widgets/auth_sheet.dart';

/// Members edit the name shown on their comments and can sign out;
/// guests are invited to sign in.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  Profile? _shown; // the saved profile the field was filled from
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.of(context);
    final profile = app.profile;
    if (profile != null && !identical(profile, _shown)) {
      _shown = profile;
      _name.text = profile.displayName;
    } else if (profile == null && _shown == null && app.signedIn) {
      _name.text = app.displayName;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final app = AppScope.read(context);
    final user = app.user;
    if (_saving || user == null || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      app.setProfile(await UniNewsApi.saveProfile(user.id, _name.text.trim()));
      messenger.showSnackBar(const SnackBar(content: Text('Profile saved')));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not save your profile. Try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    _shown = null;
    _name.clear();
    await AppScope.read(context).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: PalmBackdrop(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: app.signedIn ? _member(app) : const _GuestProfile(),
        ),
      ),
    );
  }

  Widget _member(AppState app) => ListView(
    key: const ValueKey('member'),
    padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
    children: [
      Center(
        child: InitialAvatar(
          name: app.displayName,
          seed: app.user!.id,
          size: 88,
        ),
      ),
      const SizedBox(height: 14),
      Text(
        app.displayName,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 4),
      Text(
        app.user?.email ?? '',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Brand.muted),
      ),
      const SizedBox(height: 26),
      Container(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        decoration: BoxDecoration(
          color: Brand.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Brand.line),
        ),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                maxLength: 60,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Enter your name' : null,
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      OutlinedButton.icon(
        onPressed: _signOut,
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Sign out'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Brand.danger,
          side: BorderSide(color: Brand.danger.withValues(alpha: 0.4)),
        ),
      ),
    ],
  );
}

class _GuestProfile extends StatelessWidget {
  const _GuestProfile();

  @override
  Widget build(BuildContext context) => Center(
    key: const ValueKey('guest'),
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: UniLogo(size: 88, glow: true)),
          const SizedBox(height: 24),
          const Text(
            'Reading as a guest',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Guests can read every post and comment. Sign in to write comments.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Brand.muted, fontSize: 15, height: 1.45),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: () => showAuthSheet(context),
            child: const Text('Sign in'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => showAuthSheet(context, register: true),
            child: const Text('Create account'),
          ),
        ],
      ),
    ),
  );
}
