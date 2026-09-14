import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Showcase for the A&C Creative Ventures digital products (workbooks,
/// journals, the free challenge) — a static catalog (see [kDigitalProducts]
/// in models.dart), nothing here reads or writes AppState. The free item
/// opens straight from the hosted PDF; paid items link out to the website's
/// Products page for checkout, matching the same choice made on the website
/// itself: never bundle a paid file somewhere it could be pulled out and
/// shared for free.
class ProductsScreen extends StatelessWidget {
  /// True when this screen is one of the home bottom-nav tabs (no back
  /// button, nothing to pop to); false when pushed on its own.
  final bool embedded;
  const ProductsScreen({super.key, this.embedded = false});

  Future<void> _open(BuildContext context, DigitalProduct product) async {
    try {
      final ok =
          await launchUrl(Uri.parse(product.url), mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) _showFailure(context);
    } catch (_) {
      if (context.mounted) _showFailure(context);
    }
  }

  void _showFailure(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text("Couldn't open that link — check your connection and try again."),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        decoration: Surfaces.pageBackground(dark),
        child: SafeArea(
          child: Column(
            children: [
              ScreenHeader(
                icon: Icons.shopping_bag_outlined,
                title: 'Products',
                subtitle: 'Workbooks & journals to take your practice further.',
                showBackButton: !embedded,
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  itemCount: kDigitalProducts.length,
                  itemBuilder: (context, i) {
                    final product = kDigitalProducts[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _ProductCard(
                        product: product,
                        dark: dark,
                        onTap: () => _open(context, product),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final DigitalProduct product;
  final bool dark;
  final VoidCallback onTap;
  const _ProductCard({required this.product, required this.dark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Surfaces.sheet(dark),
          border: Border.all(color: Surfaces.cardBorder(dark)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.20 : 0.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Surfaces.accent(dark).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                product.isFree ? Icons.card_giftcard_rounded : Icons.menu_book_rounded,
                color: Surfaces.accent(dark),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.title,
                      style: body(14.5, Surfaces.heading(dark), weight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(product.blurb,
                      style: body(12, Surfaces.muted(dark)).copyWith(height: 1.4)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: product.isFree
                              ? Surfaces.accent(dark).withValues(alpha: 0.18)
                              : Surfaces.muted(dark).withValues(alpha: 0.14),
                        ),
                        child: Text(
                          product.priceLabel,
                          style: body(10.5,
                              product.isFree ? Surfaces.accent(dark) : Surfaces.muted(dark),
                              weight: FontWeight.w800),
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        product.isFree
                            ? Icons.file_download_outlined
                            : Icons.open_in_new_rounded,
                        size: 16,
                        color: Surfaces.accent(dark),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
