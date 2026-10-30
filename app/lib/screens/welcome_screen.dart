import 'package:flutter/material.dart';

import '../app_state.dart';
import '../app_name.dart';
import '../brand.dart';
import '../widgets/auth_sheet.dart';
import 'feed_screen.dart';

/// First launch: continue as a guest, or log in / register (the "Open the app" activity).
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _entered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Signed in from the email link: go straight to the feed. When the sign-in
    // sheet is open it closes itself first, and _logIn continues from there.
    if (AppScope.of(context).signedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) _enter();
      });
    }
  }

  void _enter() {
    if (_entered || !mounted) return;
    _entered = true;
    AppScope.read(context).finishWelcome();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, _, _) => const FeedScreen(),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  Future<void> _logIn() async {
    if (await showAuthSheet(context)) _enter();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.45),
                radius: 1.05,
                colors: [Color(0xFF0F3B27), Brand.night],
              ),
            ),
          ),
        ),
        const Positioned.fill(
          child: PalmBackdrop(opacity: 0.07, child: SizedBox.expand()),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 3),
                const _Rise(
                  delay: 0,
                  child: Center(child: UniLogo(size: 104, glow: true)),
                ),
                const SizedBox(height: 30),
                _Rise(
                  delay: 120,
                  child: Text(
                    appName(context),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 46,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.6,
                    ),
                  ),
                ),
                const Spacer(flex: 4),
                _Rise(
                  delay: 320,
                  child: FilledButton(
                    onPressed: _logIn,
                    child: const Text('Log in or register'),
                  ),
                ),
                const SizedBox(height: 12),
                _Rise(
                  delay: 380,
                  child: OutlinedButton(
                    onPressed: _enter,
                    child: const Text('Continue as guest'),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

/// Fades a piece of the welcome screen up into place.
class _Rise extends StatelessWidget {
  const _Rise({required this.delay, required this.child});

  final int delay; // milliseconds
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final total = delay + 600;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}
