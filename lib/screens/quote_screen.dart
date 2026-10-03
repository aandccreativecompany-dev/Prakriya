import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Full-screen, shareable view of today's mantra (design ref 2j).
class QuoteScreen extends StatelessWidget {
  const QuoteScreen({super.key});

  static const _shareFooter = 'A and C Creative Ventures\n'
      'aandccreativeventures.com\n'
      'IG/Threads/YT @aandccreativeventures';

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final mantra = store.mantraEntryOfTheDay;

    return Scaffold(
      body: Container(
        decoration: Surfaces.pageBackground(dark),
        child: SafeArea(
          child: FadeSlideIn(
            child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: Surfaces.bodyText(dark)),
                    ),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('MANTRA OF THE DAY',
                            style: label(Surfaces.eyebrow(dark))),
                        const SizedBox(height: 24),
                        Text(
                          mantra.text,
                          textAlign: TextAlign.center,
                          style: display(28, Surfaces.heading(dark)),
                        ),
                        const SizedBox(height: 18),
                        Text(mantra.source,
                            textAlign: TextAlign.center,
                            style: body(13, Surfaces.muted(dark),
                                weight: FontWeight.w500)),
                        const SizedBox(height: 36),
                        Text('PRAKRIYĀ',
                            style: label(Surfaces.muted(dark))
                                .copyWith(letterSpacing: 3)),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(
                        text: '"${mantra.text}"\n${mantra.source}\n\n'
                            'Shared from Prakriyā by $_shareFooter',
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: const StadiumBorder(),
                      side: BorderSide(
                          color: Surfaces.accent(dark).withValues(alpha: 0.5),
                          width: 1.5),
                    ),
                    icon: Icon(Icons.ios_share, color: Surfaces.accent(dark), size: 18),
                    label: Text('Share this mantra',
                        style: body(14, Surfaces.heading(dark), weight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}
