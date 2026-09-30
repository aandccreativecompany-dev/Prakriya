import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';
import '../widgets/common.dart';

/// About Us — the brand/social links that used to sit as a small footer row
/// on every home screen tab. Pulled out into its own screen so the home
/// screens stay focused on the user's own content instead of repeating
/// branding on every page; reachable from the Dashboard and from Settings.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _links = [
    (
      'Website',
      'aandccreativeventures.com',
      Icons.language,
      'https://aandccreativeventures.com/',
    ),
    (
      'Instagram',
      '@aandccreativeventures',
      Icons.camera_alt_outlined,
      'https://www.instagram.com/aandccreativeventures/',
    ),
    (
      'YouTube',
      '@aandccreativeventures',
      Icons.play_circle_outline,
      'https://www.youtube.com/@aandccreativeventures',
    ),
    (
      'Threads',
      '@aandccreativeventures',
      Icons.tag,
      'https://www.threads.com/@aandccreativeventures',
    ),
  ];

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        decoration: Surfaces.pageBackground(dark),
        child: SafeArea(
          child: FadeSlideIn(
            child: Column(
              children: [
                const ScreenHeader(
                  icon: Icons.info_outline,
                  title: 'About us',
                  subtitle: 'Who\'s behind Prakriyā, and where to find us.',
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      ModuleCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('PRAKRIYĀ', style: label(Surfaces.eyebrow(dark))),
                            const SizedBox(height: 10),
                            Text(
                              'Prakriyā blends practical, psychology-grounded habit '
                              'building with outcome engineering — turning what you '
                              'want into daily, trackable action. Built by A and C '
                              'Creative Ventures as part of a wider mission to make '
                              'a global growth mindset accessible to everyone.',
                              textAlign: TextAlign.justify,
                              style: body(13.5, Surfaces.bodyText(dark), weight: FontWeight.w400)
                                  .copyWith(height: 1.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text('FIND US', style: label(Surfaces.muted(dark))),
                      const SizedBox(height: 10),
                      for (final (title, handle, icon, url) in _links)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _open(url),
                            child: ModuleCard(
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Surfaces.accent(dark).withValues(alpha: 0.14),
                                    ),
                                    child: Icon(icon, size: 18, color: Surfaces.accent(dark)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(title,
                                            style: body(14, Surfaces.heading(dark),
                                                weight: FontWeight.w700)),
                                        const SizedBox(height: 2),
                                        Text(handle, style: body(12, Surfaces.muted(dark))),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.open_in_new, size: 16, color: Surfaces.muted(dark)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 18),
                      Center(
                        child: Text('© A and C Creative Ventures',
                            style: body(11, Surfaces.muted(dark), weight: FontWeight.w600)),
                      ),
                    ],
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
