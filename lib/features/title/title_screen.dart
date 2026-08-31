// lib/features/title/title_screen.dart
//
// The threshold. The app boots here and a fallen lineage returns here.
// One centred oiled-paper panel over the field — the wordmark, then a
// column of actions led by NEW RUN. The field behind is flat lacquer
// today; a full-bleed painting drops in later (see _ThresholdField)
// without touching this composition.
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../run/run_bloc.dart';
import '../run/run_event.dart';
import '../tome/hall/hall_theme.dart';
import 'almanac_screen.dart';
import 'oiled_paper_panel.dart';
import 'records_screen.dart';
import 'settings_screen.dart';
import 'threshold_button.dart';
import 'threshold_page.dart';
import 'title_wordmark.dart';

const kAppVersion = '0.0.1';

class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key});

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _in;
  late final Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    _in = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _curve = CurvedAnimation(parent: _in, curve: Curves.easeOutCubic);
    // Motion is decorative here — collapse it under the OS reduce-motion
    // setting, matching the rest of the surface.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _in.duration = MediaQuery.of(context).disableAnimations
          ? const Duration(milliseconds: 1)
          : const Duration(milliseconds: 720);
      _in.forward();
    });
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  void _openPage(Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    final curve = _curve;

    return Scaffold(
      backgroundColor: hall.lacquer,
      body: Stack(
        children: [
          const Positioned.fill(child: ThresholdField()),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              child: FadeTransition(
                opacity: curve,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.03),
                    end: Offset.zero,
                  ).animate(curve),
                  child: OiledPaperPanel(
                    padding: const EdgeInsets.fromLTRB(30, 30, 30, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: TitleWordmark(),
                        ),
                        const SizedBox(height: 26),
                        ThresholdButton(
                          label: 'New Run',
                          tone: ThresholdTone.seal,
                          onPressed: () => context
                              .read<RunBloc>()
                              .add(const NewRunRequested()),
                        ),
                        const SizedBox(height: 8),
                        ThresholdButton(
                          label: 'Almanac',
                          onPressed: () => _openPage(const AlmanacScreen()),
                        ),
                        const SizedBox(height: 8),
                        ThresholdButton(
                          label: 'Records',
                          onPressed: () => _openPage(const RecordsScreen()),
                        ),
                        const SizedBox(height: 8),
                        ThresholdButton(
                          label: 'Settings',
                          tone: ThresholdTone.quiet,
                          onPressed: () => _openPage(const SettingsScreen()),
                        ),
                        if (!kIsWeb) ...[
                          const SizedBox(height: 8),
                          ThresholdButton(
                            label: 'Quit',
                            tone: ThresholdTone.quiet,
                            onPressed: () => SystemNavigator.pop(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 20,
            bottom: 16,
            child: Text(
              'v$kAppVersion',
              style: hall.measure.copyWith(
                fontSize: 10,
                color: hall.boneDim.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
