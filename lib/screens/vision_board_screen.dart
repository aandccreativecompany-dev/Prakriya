import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../vision_data.dart';
import '../widgets/common.dart';
import 'shared_vision_board_screen.dart';
import 'vision_layouts_screen.dart';
import 'vision_visualize_screen.dart';

/// A collage of what the user is working toward — a picked photo (saved from
/// Pinterest, a screenshot, anything in the gallery) with a word or sentence
/// captioning it, or a caption-only tile when there's no image yet. Every
/// tile can now have its own shape and size (long-press or tap "Customize"),
/// and a gallery of 25 curated layouts can restyle the whole board in one tap.
class VisionBoardScreen extends StatelessWidget {
  const VisionBoardScreen({super.key});

  static const _hatchColors = [Brand.gold, Brand.violet, Brand.goldLight, Brand.mutedDark];

  // Persists across rebuilds (the screen is StatelessWidget, rebuilt by the
  // AnimatedBuilder below on every store change) so _shareAsImage can always
  // find the same RepaintBoundary to capture.
  static final GlobalKey _boardKey = GlobalKey();

  /// Which life area is shown: 'all', an area key, or 'achieved'.
  static final ValueNotifier<String> _filter = ValueNotifier<String>('all');

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[store, _filter]),
      builder: (context, _) {
        final items = store.visionItems;
        var filter = _filter.value;
        List<VisionItem> shown = items;
        if (filter == 'achieved') {
          shown = items.where((i) => i.achieved).toList();
        } else if (filter != 'all') {
          shown = items.where((i) => i.area == filter).toList();
        }
        if (shown.isEmpty && items.isNotEmpty) {
          // The chosen filter no longer matches anything: show everything.
          filter = 'all';
          shown = items;
        }
        final achievedCount = items.where((i) => i.achieved).length;
        return Scaffold(
          body: Container(
            decoration: Surfaces.pageBackground(dark),
            child: SafeArea(
              child: FadeSlideIn(
                child: Column(
                  children: [
                    ScreenHeader(
                      icon: Icons.grid_view_rounded,
                      title: 'Vision board',
                      subtitle: items.isEmpty
                          ? 'Pin a photo with a word or sentence, or just the words.'
                          : '$achievedCount of ${items.length} dreams achieved',
                      actions: [
                        IconButton(
                          tooltip: 'Share',
                          onPressed: () => _showShareOptions(context, items),
                          icon: Icon(Icons.ios_share, color: Surfaces.accent(dark)),
                        ),
                        IconButton(
                          onPressed: () => _addItem(context),
                          icon: Icon(Icons.add_circle_outline, color: Surfaces.accent(dark)),
                        ),
                      ],
                    ),
                    if (items.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                        child: Row(
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) =>
                                      VisionVisualizeScreen(items: List<VisionItem>.of(shown)))),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  color: Surfaces.accent(dark),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.play_arrow_rounded,
                                        size: 18, color: dark ? Brand.deep : Colors.white),
                                    const SizedBox(width: 6),
                                    Text('Visualize',
                                        style: body(12.5, dark ? Brand.deep : Colors.white,
                                            weight: FontWeight.w800)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const VisionLayoutsScreen())),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    color: Surfaces.accent(dark).withValues(alpha: 0.10),
                                    border:
                                        Border.all(color: Surfaces.accent(dark).withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.dashboard_customize_outlined,
                                          size: 16, color: Surfaces.accent(dark)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          store.visionBoardLayoutName == null
                                              ? 'Layouts'
                                              : 'Layout: ${store.visionBoardLayoutName}',
                                          style: body(12.5, Surfaces.accent(dark),
                                              weight: FontWeight.w700),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Icon(Icons.chevron_right,
                                          size: 16, color: Surfaces.accent(dark)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => _openBackgroundPicker(context),
                              child: Container(
                                padding: const EdgeInsets.all(11),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  color: Surfaces.accent(dark).withValues(alpha: 0.10),
                                  border: Border.all(
                                      color: Surfaces.accent(dark).withValues(alpha: 0.3)),
                                ),
                                child: Icon(Icons.wallpaper_outlined,
                                    size: 18, color: Surfaces.accent(dark)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 44,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
                          children: [
                            _FilterChip(
                              label: 'All',
                              selected: filter == 'all',
                              dark: dark,
                              onTap: () => _filter.value = 'all',
                            ),
                            for (final area in kVisionAreas)
                              if (items.any((i) => i.area == area.key))
                                _FilterChip(
                                  label: area.label,
                                  icon: area.icon,
                                  color: area.color,
                                  selected: filter == area.key,
                                  dark: dark,
                                  onTap: () => _filter.value = area.key,
                                ),
                            if (achievedCount > 0)
                              _FilterChip(
                                label: 'Achieved',
                                icon: Icons.check_circle_outline,
                                selected: filter == 'achieved',
                                dark: dark,
                                onTap: () => _filter.value = 'achieved',
                              ),
                            _FilterChip(
                              label: 'Templates',
                              icon: Icons.auto_awesome_outlined,
                              selected: false,
                              dark: dark,
                              onTap: () => _showTemplates(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Expanded(
                      child: items.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.grid_view_rounded,
                                        color: Surfaces.accent(dark), size: 30),
                                    const SizedBox(height: 16),
                                    Text('Nothing pinned yet',
                                        style: display(18, Surfaces.heading(dark))),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Add a tile for anything you\'re working toward.',
                                      style: body(13, Surfaces.muted(dark)),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 20),
                                    GoldButton(
                                        labelText: 'Add your first tile',
                                        onPressed: () => _addItem(context)),
                                    const SizedBox(height: 10),
                                    TextButton.icon(
                                      onPressed: () => _showTemplates(context),
                                      icon: Icon(Icons.auto_awesome_outlined,
                                          size: 18, color: Surfaces.accent(dark)),
                                      label: Text('Start from a template',
                                          style: body(13.5, Surfaces.accent(dark),
                                              weight: FontWeight.w700)),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                              child: RepaintBoundary(
                                key: _boardKey,
                                child: Container(
                                  decoration: boardBackgroundDecoration(
                                      store.visionBoardBackground, dark),
                                  padding: const EdgeInsets.all(4),
                                  child: Stack(
                                    children: [
                                      if (store.visionBoardBackground == 'cork' ||
                                          store.visionBoardBackground == 'linen')
                                        Positioned.fill(
                                          child: CustomPaint(
                                            painter: _BoardTexturePainter(
                                                theme: store.visionBoardBackground),
                                          ),
                                        ),
                                      StaggeredGrid.count(
                                        crossAxisCount: 2,
                                        mainAxisSpacing: 14,
                                        crossAxisSpacing: 14,
                                        children: [
                                          for (var i = 0; i < shown.length; i++)
                                            StaggeredGridTile.count(
                                              crossAxisCellCount: shown[i].spanX.clamp(1, 2),
                                              mainAxisCellCount: shown[i].spanY.clamp(1, 2),
                                              child: _VisionTile(
                                                item: shown[i],
                                                index: i,
                                                color: _hatchColors[
                                                    shown[i].colorIndex % _hatchColors.length],
                                                dark: dark,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
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
      },
    );
  }

  Future<void> _addItem(BuildContext context) async {
    final controller = TextEditingController();
    final affirmationController = TextEditingController();
    final dark = Theme.of(context).brightness == Brightness.dark;
    String? pickedPath;
    var area = '';
    var targetDate = '';

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final keyboard = MediaQuery.of(context).viewInsets.bottom;
          return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, keyboard + 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height - keyboard - 80),
            child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            decoration: BoxDecoration(
              // Opaque — see HabitEditorSheet's note on Surfaces.sheet.
              color: Surfaces.sheet(dark),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('New tile', style: display(18, Surfaces.heading(dark))),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    final path = await _pickAndCopyImage();
                    if (path != null) setState(() => pickedPath = path);
                  },
                  child: Container(
                    height: 130,
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Brand.gold.withValues(alpha: 0.1),
                      border: Border.all(color: Brand.gold.withValues(alpha: 0.4)),
                    ),
                    child: pickedPath == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined,
                                  color: Surfaces.accent(dark)),
                              const SizedBox(height: 6),
                              Text('Add a photo from your gallery\n(optional)',
                                  textAlign: TextAlign.center,
                                  style: body(11.5, Surfaces.muted(dark))),
                            ],
                          )
                        : Image.file(File(pickedPath!), fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  autofocus: pickedPath == null,
                  textCapitalization: TextCapitalization.sentences,
                  style: body(14, Surfaces.bodyText(dark)),
                  decoration: const InputDecoration(
                      hintText: 'A word or sentence for this tile'),
                ),
                const SizedBox(height: 16),
                Text('LIFE AREA', style: label(Surfaces.eyebrow(dark))),
                const SizedBox(height: 8),
                _AreaChips(
                  selected: area,
                  dark: dark,
                  onChanged: (v) => setState(() => area = v),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: affirmationController,
                  textCapitalization: TextCapitalization.sentences,
                  style: body(14, Surfaces.bodyText(dark)),
                  decoration: const InputDecoration(
                      hintText: 'An affirmation, in the present tense (optional)'),
                ),
                const SizedBox(height: 12),
                _DateRow(
                  value: targetDate,
                  dark: dark,
                  onPick: () async {
                    final picked = await _pickVisionDate(context, targetDate);
                    if (picked != null) setState(() => targetDate = picked);
                  },
                  onClear: () => setState(() => targetDate = ''),
                ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                GoldButton(
                  labelText: 'Save tile',
                  onPressed: () => Navigator.pop(context, true),
                ),
              ],
            ),
            ),
          ),
          );
        },
      ),
    );

    if (result == true) {
      await store.addVisionItem(
        controller.text,
        imagePath: pickedPath,
        area: area,
        affirmation: affirmationController.text,
        targetDate: targetDate,
      );
      if (context.mounted) toastSaved(context);
    }
  }

  Future<void> _showTemplates(BuildContext context) async {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final chosen = await showModalBottomSheet<VisionTemplate>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        decoration: BoxDecoration(
          color: Surfaces.sheet(dark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Start from a template', style: display(17, Surfaces.heading(dark))),
            const SizedBox(height: 4),
            Text('Adds ready-made tiles with affirmations. Edit or remove any of them.',
                style: body(12.5, Surfaces.muted(dark))),
            const SizedBox(height: 10),
            for (final t in kVisionTemplates)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.auto_awesome_outlined, color: Surfaces.accent(dark)),
                title: Text(t.name,
                    style: body(14, Surfaces.bodyText(dark), weight: FontWeight.w600)),
                subtitle: Text('${t.tiles.length} tiles · ${t.blurb}',
                    style: body(11.5, Surfaces.muted(dark))),
                onTap: () => Navigator.pop(context, t),
              ),
          ],
        ),
      ),
    );
    if (chosen == null) return;
    await store.addVisionTemplate(chosen.tiles);
    if (context.mounted) toastSaved(context, label: '${chosen.tiles.length} tiles added');
  }

  /// Opens the device gallery and copies the chosen image into app-local
  /// storage, so it keeps working even if the original is deleted from the
  /// gallery. Returns null on cancel or on any picker/copy failure.
  Future<String?> _pickAndCopyImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked == null) return null;
      final dir = await getApplicationDocumentsDirectory();
      final visionDir = Directory(p.join(dir.path, 'vision_board'));
      if (!await visionDir.exists()) await visionDir.create(recursive: true);
      final ext = p.extension(picked.path).isNotEmpty ? p.extension(picked.path) : '.jpg';
      final dest = p.join(
          visionDir.path, '${DateTime.now().microsecondsSinceEpoch}$ext');
      await File(picked.path).copy(dest);
      return dest;
    } catch (_) {
      return null;
    }
  }

  Future<void> _openBackgroundPicker(BuildContext context) async {
    final dark = Theme.of(context).brightness == Brightness.dark;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        decoration: BoxDecoration(
          color: Surfaces.sheet(dark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Board background', style: display(17, Surfaces.heading(dark))),
            const SizedBox(height: 4),
            Text('A texture or theme behind your tiles.',
                style: body(12.5, Surfaces.muted(dark))),
            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: store,
              builder: (context, _) => Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final theme in kVisionBackgrounds)
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => store.setVisionBoardBackground(theme),
                      child: Column(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: store.visionBoardBackground == theme
                                    ? Surfaces.accent(dark)
                                    : Surfaces.accentBorder(dark),
                                width: store.visionBoardBackground == theme ? 2 : 1,
                              ),
                            ),
                            child: DecoratedBox(
                              decoration: boardBackgroundDecoration(theme, dark),
                              child: (theme == 'cork' || theme == 'linen')
                                  ? CustomPaint(painter: _BoardTexturePainter(theme: theme))
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(kVisionBackgroundLabels[theme] ?? theme,
                              style: body(10.5, Surfaces.muted(dark))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showShareOptions(BuildContext context, List<VisionItem> items) async {
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add something to your board first.')));
      return;
    }
    final dark = Theme.of(context).brightness == Brightness.dark;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        decoration: BoxDecoration(
          color: Surfaces.sheet(dark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Share your vision board', style: display(17, Surfaces.heading(dark))),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.image_outlined, color: Surfaces.accent(dark)),
              title: Text('Share as an image', style: body(14, Surfaces.bodyText(dark), weight: FontWeight.w600)),
              subtitle: Text('View-only — a snapshot of the board as it looks now.',
                  style: body(11.5, Surfaces.muted(dark))),
              onTap: () => Navigator.pop(context, 'image'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.text_snippet_outlined, color: Surfaces.accent(dark)),
              title: Text('Share as a text list', style: body(14, Surfaces.bodyText(dark), weight: FontWeight.w600)),
              subtitle: Text('View-only — just the captions, no images.',
                  style: body(11.5, Surfaces.muted(dark))),
              onTap: () => Navigator.pop(context, 'text'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.groups_outlined, color: Surfaces.accent(dark)),
              title: Text('Shared board others can add to', style: body(14, Surfaces.bodyText(dark), weight: FontWeight.w600)),
              subtitle: Text('A live board others join with a code and add their own points to.',
                  style: body(11.5, Surfaces.muted(dark))),
              onTap: () => Navigator.pop(context, 'collab'),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted) return;
    if (choice == 'image') {
      await _shareAsImage(context);
    } else if (choice == 'text') {
      await _shareAsText(context, items);
    } else if (choice == 'collab') {
      if (context.mounted) {
        await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SharedVisionBoardScreen()));
      }
    }
  }

  Future<void> _shareAsText(BuildContext context, List<VisionItem> items) async {
    final text = items.map((i) => '• ${i.caption}').where((l) => l != '• ').join('\n');
    await SharePlus.instance.share(ShareParams(
      text: text.isEmpty ? 'My vision board on Prakriyā' : text,
      subject: 'My vision board',
    ));
  }

  Future<void> _shareAsImage(BuildContext context) async {
    try {
      final boundary =
          _boardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text("Couldn't capture the board — try again.")));
        }
        return;
      }
      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final dir = await getTemporaryDirectory();
      final file = File(p.join(
          dir.path, 'vision_board_${DateTime.now().microsecondsSinceEpoch}.png'));
      await file.writeAsBytes(byteData.buffer.asUint8List());
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        text: 'My vision board on Prakriyā',
      ));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Couldn't share the board — try again.")));
      }
    }
  }
}

class _VisionTile extends StatelessWidget {
  final VisionItem item;
  final int index;
  final Color color;
  final bool dark;
  const _VisionTile({required this.item, required this.index, required this.color, required this.dark});

  @override
  Widget build(BuildContext context) {
    final shape = item.shape.isEmpty ? store.visionBoardShape : item.shape;
    final colorFilter = visionTileColorFilter(item.filter);
    Widget image = Image.file(
      File(item.imagePath ?? ''),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => CustomPaint(painter: _HatchPainter(color: color)),
    );
    if (colorFilter != null) image = ColorFiltered(colorFilter: colorFilter, child: image);

    final card = ClipPath(
      clipper: _shapeClipper(shape),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
              color: item.achieved ? Brand.gold : color.withValues(alpha: 0.35),
              width: item.achieved ? 2.5 : 1.5),
          color: color.withValues(alpha: dark ? 0.08 : 0.1),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item.imagePath != null)
              Align(
                alignment: Alignment(
                    (item.imageOffsetX - 0.5) * 2, (item.imageOffsetY - 0.5) * 2),
                child: Transform.scale(scale: item.imageZoom, child: image),
              )
            else
              CustomPaint(painter: _HatchPainter(color: color)),
            if (item.imagePath != null)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),
            if (item.caption.isNotEmpty)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Text(
                  item.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: body(13, item.imagePath != null ? Colors.white : Surfaces.heading(dark),
                      weight: FontWeight.w700),
                ),
              ),
            Positioned(
              top: 6,
              right: 6,
              child: Icon(Icons.tune, size: 15, color: Colors.white.withValues(alpha: 0.85)),
            ),
            Positioned(
              top: 6,
              left: 8,
              right: 28,
              child: _TileBadges(item: item),
            ),
          ],
        ),
      ),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _openCustomizer(context),
      onLongPress: () async {
        final remove = await _confirmRemove(context, item.caption);
        if (remove == true) {
          await store.removeVisionItem(item);
          if (context.mounted) toastSaved(context, label: 'Removed');
        }
      },
      child: _framedTile(card, item.frameStyle, dark),
    );
  }

  /// Wraps a tile's clipped card in the chosen decorative frame — a light,
  /// dependency-free approximation of a real mood-board look (polaroid
  /// border, torn-paper edge, a strip of washi tape, or just a soft drop
  /// shadow) rather than a flat clipped rectangle.
  Widget _framedTile(Widget card, String frameStyle, bool dark) {
    switch (frameStyle) {
      case 'polaroid':
        return Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 10,
                  offset: const Offset(0, 5)),
            ],
          ),
          child: card,
        );
      case 'dropShadow':
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.5 : 0.24),
                  blurRadius: 16,
                  offset: const Offset(0, 7)),
            ],
          ),
          child: card,
        );
      case 'washiTape':
        return Stack(
          clipBehavior: Clip.none,
          children: [
            card,
            Positioned(
              top: -9,
              left: 14,
              child: Transform.rotate(
                angle: -0.32,
                child: Container(
                  width: 46,
                  height: 18,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.8),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 3),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      case 'tornPaper':
        return Stack(
          children: [
            card,
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _TornEdgePainter(dark: dark)),
              ),
            ),
          ],
        );
      default:
        return card;
    }
  }

  Future<bool?> _confirmRemove(BuildContext context, String caption) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(caption.isEmpty ? 'Remove this tile?' : 'Remove "$caption"?',
            style: display(16, Surfaces.heading(dark))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep it')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
  }

  void _openCustomizer(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TileCustomizerSheet(item: item),
    );
  }
}

/// Per-tile editor: pick a shape, pick a size, and — when there's a photo —
/// drag to recentre it and use a slider to zoom, so the image stays well
/// composed no matter what shape or size the tile ends up as.
class _TileCustomizerSheet extends StatefulWidget {
  final VisionItem item;
  const _TileCustomizerSheet({required this.item});

  @override
  State<_TileCustomizerSheet> createState() => _TileCustomizerSheetState();
}

class _TileCustomizerSheetState extends State<_TileCustomizerSheet> {
  late String _shape;
  late int _spanX;
  late int _spanY;
  late double _offsetX;
  late double _offsetY;
  late double _zoom;
  late String _frameStyle;
  late String _filter;
  late final TextEditingController _captionController;
  late final TextEditingController _affirmationController;
  late String _area;
  late String _targetDate;
  late bool _achieved;

  static const _sizeOptions = [
    ('Small', 1, 1),
    ('Wide', 2, 1),
    ('Tall', 1, 2),
    ('Large', 2, 2),
  ];

  @override
  void initState() {
    super.initState();
    _shape = widget.item.shape.isEmpty ? store.visionBoardShape : widget.item.shape;
    _spanX = widget.item.spanX;
    _spanY = widget.item.spanY;
    _offsetX = widget.item.imageOffsetX;
    _offsetY = widget.item.imageOffsetY;
    _zoom = widget.item.imageZoom;
    _frameStyle = widget.item.frameStyle.isEmpty ? 'none' : widget.item.frameStyle;
    _filter = widget.item.filter.isEmpty ? 'none' : widget.item.filter;
    _captionController = TextEditingController(text: widget.item.caption);
    _affirmationController = TextEditingController(text: widget.item.affirmation);
    _area = widget.item.area;
    _targetDate = widget.item.targetDate;
    _achieved = widget.item.achieved;
  }

  @override
  void dispose() {
    _captionController.dispose();
    _affirmationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    HapticFeedback.mediumImpact();
    await store.updateVisionItemStyle(
      widget.item,
      shape: _shape,
      spanX: _spanX,
      spanY: _spanY,
      imageOffsetX: _offsetX,
      imageOffsetY: _offsetY,
      imageZoom: _zoom,
      frameStyle: _frameStyle,
      filter: _filter,
    );
    await store.updateVisionItemDetails(
      widget.item,
      caption: _captionController.text,
      area: _area,
      affirmation: _affirmationController.text,
      targetDate: _targetDate,
      achieved: _achieved,
    );
    if (mounted) {
      Navigator.pop(context);
      toastSaved(context, label: 'Tile updated');
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, keyboard + 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height - keyboard - 80),
        child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        decoration: BoxDecoration(
          // Opaque — see HabitEditorSheet's note on Surfaces.sheet.
          color: Surfaces.sheet(dark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customize tile', style: display(18, Surfaces.heading(dark))),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              Text('WORDS', style: label(Surfaces.eyebrow(dark))),
              const SizedBox(height: 8),
              TextField(
                controller: _captionController,
                textCapitalization: TextCapitalization.sentences,
                style: body(14, Surfaces.bodyText(dark)),
                decoration: const InputDecoration(hintText: 'A word or sentence'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _affirmationController,
                textCapitalization: TextCapitalization.sentences,
                style: body(14, Surfaces.bodyText(dark)),
                decoration: const InputDecoration(
                    hintText: 'Affirmation, in the present tense (optional)'),
              ),
              const SizedBox(height: 16),
              Text('LIFE AREA', style: label(Surfaces.eyebrow(dark))),
              const SizedBox(height: 8),
              _AreaChips(
                selected: _area,
                dark: dark,
                onChanged: (v) => setState(() => _area = v),
              ),
              const SizedBox(height: 12),
              _DateRow(
                value: _targetDate,
                dark: dark,
                onPick: () async {
                  final picked = await _pickVisionDate(context, _targetDate);
                  if (picked != null && mounted) setState(() => _targetDate = picked);
                },
                onClear: () => setState(() => _targetDate = ''),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text('This has come true',
                    style: body(13.5, Surfaces.bodyText(dark), weight: FontWeight.w600)),
                value: _achieved,
                activeTrackColor: Surfaces.accent(dark),
                onChanged: (v) => setState(() => _achieved = v),
              ),
              const SizedBox(height: 12),
              if (widget.item.imagePath != null) ...[
                Text('DRAG TO REPOSITION · PINCH TO ZOOM',
                    style: label(Surfaces.eyebrow(dark))),
                const SizedBox(height: 8),
                ClipPath(
                  clipper: _shapeClipper(_shape),
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _offsetX = (_offsetX + details.delta.dx / 200).clamp(0.0, 1.0);
                        _offsetY = (_offsetY + details.delta.dy / 200).clamp(0.0, 1.0);
                      });
                    },
                    child: Container(
                      height: 160,
                      width: double.infinity,
                      color: Colors.black12,
                      child: Align(
                        alignment: Alignment((_offsetX - 0.5) * 2, (_offsetY - 0.5) * 2),
                        child: Transform.scale(
                          scale: _zoom,
                          child: Image.file(File(widget.item.imagePath!), fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.zoom_out, size: 16, color: Surfaces.muted(dark)),
                    Expanded(
                      child: Slider(
                        value: _zoom,
                        min: 1.0,
                        max: 2.5,
                        activeColor: Surfaces.accent(dark),
                        onChanged: (v) => setState(() => _zoom = v),
                      ),
                    ),
                    Icon(Icons.zoom_in, size: 16, color: Surfaces.muted(dark)),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Text('SHAPE', style: label(Surfaces.eyebrow(dark))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in kVisionShapes)
                    _Chip(
                      label: kVisionShapeLabels[s] ?? s,
                      selected: _shape == s,
                      dark: dark,
                      onTap: () => setState(() => _shape = s),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('SIZE', style: label(Surfaces.eyebrow(dark))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (name, sx, sy) in _sizeOptions)
                    _Chip(
                      label: name,
                      selected: _spanX == sx && _spanY == sy,
                      dark: dark,
                      onTap: () => setState(() {
                        _spanX = sx;
                        _spanY = sy;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('FRAME', style: label(Surfaces.eyebrow(dark))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in kVisionFrames)
                    _Chip(
                      label: kVisionFrameLabels[f] ?? f,
                      selected: _frameStyle == f,
                      dark: dark,
                      onTap: () => setState(() => _frameStyle = f),
                    ),
                ],
              ),
              if (widget.item.imagePath != null) ...[
                const SizedBox(height: 16),
                Text('PHOTO FILTER', style: label(Surfaces.eyebrow(dark))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final f in kVisionFilters)
                      _Chip(
                        label: kVisionFilterLabels[f] ?? f,
                        selected: _filter == f,
                        dark: dark,
                        onTap: () => setState(() => _filter = f),
                      ),
                  ],
                ),
              ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            GoldButton(labelText: 'Save changes', onPressed: _save),
          ],
        ),
        ),
      ),
    );
  }
}

/// Small badges on a tile: its life area, and either a countdown to the
/// target date or an "Achieved" mark.
class _TileBadges extends StatelessWidget {
  final VisionItem item;
  const _TileBadges({required this.item});

  @override
  Widget build(BuildContext context) {
    final area = visionAreaFor(item.area);
    final countdown = item.achieved ? '' : visionCountdownLabel(item);
    if (area == null && countdown.isEmpty && !item.achieved) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (area != null)
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(color: area.color, shape: BoxShape.circle),
            child: Icon(area.icon, size: 13, color: Colors.white),
          ),
        if (item.achieved)
          _pill('Achieved', Brand.gold, Brand.deep)
        else if (countdown.isNotEmpty)
          _pill(countdown, Colors.black.withValues(alpha: 0.55), Colors.white),
      ],
    );
  }

  Widget _pill(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(text,
          style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final bool selected;
  final bool dark;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.dark,
    required this.onTap,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final accent = color ?? Surfaces.accent(dark);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? accent : Surfaces.accentBorder(dark),
                width: selected ? 1.4 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: selected ? accent : Surfaces.muted(dark)),
                const SizedBox(width: 5),
              ],
              Text(label,
                  style: body(11.5, selected ? accent : Surfaces.muted(dark),
                      weight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Life-area picker. Tapping the selected area again clears it.
class _AreaChips extends StatelessWidget {
  final String selected;
  final bool dark;
  final ValueChanged<String> onChanged;
  const _AreaChips(
      {required this.selected, required this.dark, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final a in kVisionAreas)
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => onChanged(selected == a.key ? '' : a.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: selected == a.key
                    ? a.color.withValues(alpha: 0.18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: selected == a.key ? a.color : Surfaces.accentBorder(dark),
                    width: selected == a.key ? 1.4 : 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(a.icon,
                      size: 14,
                      color: selected == a.key ? a.color : Surfaces.muted(dark)),
                  const SizedBox(width: 5),
                  Text(a.label,
                      style: body(11.5,
                          selected == a.key ? a.color : Surfaces.muted(dark),
                          weight: FontWeight.w600)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DateRow extends StatelessWidget {
  final String value;
  final bool dark;
  final VoidCallback onPick;
  final VoidCallback onClear;
  const _DateRow(
      {required this.value,
      required this.dark,
      required this.onPick,
      required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.event_outlined, size: 18),
            label: Text(
              value.isEmpty
                  ? 'Set a target date (optional)'
                  : 'By ${formatVisionDate(value)}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (value.isNotEmpty)
          IconButton(
            tooltip: 'Clear date',
            onPressed: onClear,
            icon: Icon(Icons.close, size: 18, color: Surfaces.muted(dark)),
          ),
      ],
    );
  }
}

/// Picks a future date and returns it as `yyyy-MM-dd`, or null if cancelled.
Future<String?> _pickVisionDate(BuildContext context, String current) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  var initial = DateTime.tryParse(current) ?? today.add(const Duration(days: 90));
  if (initial.isBefore(today)) initial = today;
  final picked = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: today,
    lastDate: DateTime(today.year + 15, 12, 31),
  );
  if (picked == null) return null;
  return dayKey(picked);
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool dark;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.dark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? Surfaces.accent(dark).withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Surfaces.accent(dark) : Surfaces.accentBorder(dark),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Text(label,
            style: body(11.5, selected ? Surfaces.accent(dark) : Surfaces.muted(dark),
                weight: FontWeight.w600)),
      ),
    );
  }
}

/// Decoration for the whole board's background — a plain colour by default,
/// or one of a few textured/atmospheric themes (paired with
/// [_BoardTexturePainter] for the ones that need a drawn texture on top).
BoxDecoration boardBackgroundDecoration(String theme, bool dark) {
  switch (theme) {
    case 'cork':
      return const BoxDecoration(color: Color(0xFFC9A268));
    case 'linen':
      return BoxDecoration(color: dark ? const Color(0xFF3B372F) : const Color(0xFFEEE7D7));
    case 'gradient':
      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [Brand.violet.withValues(alpha: 0.85), Brand.deep]
              : [Brand.goldLight.withValues(alpha: 0.55), Brand.cream],
        ),
      );
    case 'dark':
      return const BoxDecoration(color: Color(0xFF14101F));
    default:
      return BoxDecoration(color: dark ? Brand.deep : Brand.cream);
  }
}

/// Colour-grading for a tile's photo — a small, dependency-free stand-in for
/// a real filter engine: a saturation/hue matrix rather than a texture or
/// blur, so it stays cheap to apply to every tile on every rebuild.
ColorFilter? visionTileColorFilter(String filter) {
  switch (filter) {
    case 'warm':
      return const ColorFilter.matrix([
        1.12, 0, 0, 0, 14,
        0, 1.02, 0, 0, 6,
        0, 0, 0.86, 0, 0,
        0, 0, 0, 1, 0,
      ]);
    case 'dreamy':
      // Softened contrast + a light lift — a gentle, hazy look without
      // needing an actual blur/bloom pass.
      return const ColorFilter.matrix([
        0.85, 0.06, 0.06, 0, 18,
        0.06, 0.85, 0.06, 0, 18,
        0.08, 0.08, 0.82, 0, 20,
        0, 0, 0, 1, 0,
      ]);
    case 'bw':
      return const ColorFilter.matrix([
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0, 0, 0, 1, 0,
      ]);
    default:
      return null;
  }
}

/// Cork-board dot texture / linen crosshatch, drawn once behind the tiles.
class _BoardTexturePainter extends CustomPainter {
  final String theme;
  const _BoardTexturePainter({required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    if (theme == 'cork') {
      final paint = Paint()..color = const Color(0x226B4F2A);
      const gap = 9.0;
      for (var y = gap / 2; y < size.height; y += gap) {
        for (var x = gap / 2; x < size.width; x += gap) {
          // Fixed jitter (not random) so the texture is stable across
          // rebuilds instead of sparkling every frame.
          final jitter = ((x + y) % 5) - 2;
          canvas.drawCircle(Offset(x + jitter, y), 1.1, paint);
        }
      }
    } else if (theme == 'linen') {
      final paint = Paint()
        ..color = const Color(0x14000000)
        ..strokeWidth = 0.6;
      const gap = 6.0;
      for (var x = 0.0; x < size.width; x += gap) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
      for (var y = 0.0; y < size.height; y += gap) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BoardTexturePainter oldDelegate) => oldDelegate.theme != theme;
}

CustomClipper<Path> _shapeClipper(String shape) {
  switch (shape) {
    case 'circle':
      return const _CircleClipper();
    case 'star':
      return const _StarClipper();
    case 'heart':
      return const _HeartClipper();
    case 'hexagon':
      return const _HexagonClipper();
    case 'diamond':
      return const _DiamondClipper();
    case 'roundedRect':
      return const _RoundedSquareClipper();
    case 'cloud':
      return const _CloudClipper();
    case 'flower':
      return const _FlowerClipper();
    case 'arch':
      return const _ArchClipper();
    case 'blob':
      return const _BlobClipper();
    default:
      return const _RoundedSquareClipper();
  }
}

class _RoundedSquareClipper extends CustomClipper<Path> {
  const _RoundedSquareClipper();
  @override
  Path getClip(Size size) => Path()
    ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(18)));
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _CircleClipper extends CustomClipper<Path> {
  const _CircleClipper();
  @override
  Path getClip(Size size) {
    final side = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);
    return Path()..addOval(Rect.fromCenter(center: center, width: side, height: side));
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Five-point star, inscribed in the tile so it still reads clearly at
/// grid-tile size.
class _StarClipper extends CustomClipper<Path> {
  const _StarClipper();
  @override
  Path getClip(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.shortestSide / 2;
    final innerRadius = outerRadius * 0.42;
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final radius = i.isEven ? outerRadius : innerRadius;
      final angle = (-90 + i * 36) * math.pi / 180;
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// A heart shape built from two circular lobes and two curves to a bottom
/// point, scaled to fill the tile.
class _HeartClipper extends CustomClipper<Path> {
  const _HeartClipper();
  @override
  Path getClip(Size size) {
    final w = size.width, h = size.height;
    final path = Path();
    path.moveTo(w / 2, h * 0.30);
    path.cubicTo(w * 0.1, -h * 0.05, -w * 0.1, h * 0.45, w / 2, h * 0.98);
    path.cubicTo(w * 1.1, h * 0.45, w * 0.9, -h * 0.05, w / 2, h * 0.30);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _HexagonClipper extends CustomClipper<Path> {
  const _HexagonClipper();
  @override
  Path getClip(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = (-90 + i * 60) * math.pi / 180;
      final point = Offset(center.dx + radius * math.cos(angle), center.dy + radius * math.sin(angle));
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _DiamondClipper extends CustomClipper<Path> {
  const _DiamondClipper();
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width, size.height / 2);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(0, size.height / 2);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// A soft cloud shape — several overlapping circular lobes along the top of
/// a rounded base, one of the newer "whimsical" tile options.
class _CloudClipper extends CustomClipper<Path> {
  const _CloudClipper();
  @override
  Path getClip(Size size) {
    final w = size.width, h = size.height;
    final path = Path();
    path.moveTo(w * 0.15, h * 0.75);
    path.cubicTo(w * -0.05, h * 0.75, w * -0.05, h * 0.4, w * 0.18, h * 0.4);
    path.cubicTo(w * 0.18, h * 0.12, w * 0.55, h * 0.08, w * 0.62, h * 0.3);
    path.cubicTo(w * 0.8, h * 0.15, w * 1.05, h * 0.35, w * 0.92, h * 0.55);
    path.cubicTo(w * 1.08, h * 0.6, w * 1.05, h * 0.85, w * 0.85, h * 0.85);
    path.lineTo(w * 0.15, h * 0.85);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// A simple six-petal flower, inscribed in the tile.
class _FlowerClipper extends CustomClipper<Path> {
  const _FlowerClipper();
  @override
  Path getClip(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final petalRadius = size.shortestSide * 0.30;
    final orbit = size.shortestSide * 0.26;
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = i * 60 * math.pi / 180;
      final petalCenter = Offset(
        center.dx + orbit * math.cos(angle),
        center.dy + orbit * math.sin(angle),
      );
      final petal = Path()
        ..addOval(Rect.fromCenter(center: petalCenter, width: petalRadius * 2, height: petalRadius * 2));
      path.addPath(petal, Offset.zero);
    }
    path.addOval(Rect.fromCenter(
        center: center, width: petalRadius * 1.3, height: petalRadius * 1.3));
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// A rounded-top "storybook" arch — flat bottom, semicircular top.
class _ArchClipper extends CustomClipper<Path> {
  const _ArchClipper();
  @override
  Path getClip(Size size) {
    final w = size.width, h = size.height;
    final radius = w / 2;
    final straightTop = (h - radius).clamp(0.0, h);
    final path = Path();
    path.moveTo(0, h);
    path.lineTo(0, straightTop);
    path.arcToPoint(Offset(w, straightTop), radius: Radius.circular(radius), clockwise: true);
    path.lineTo(w, h);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// An organic, hand-drawn-looking "blob" — an irregular closed curve built
/// from cubic segments around a wobbly radius, so it never reads as a
/// precise geometric shape the way the other tiles do.
class _BlobClipper extends CustomClipper<Path> {
  const _BlobClipper();
  @override
  Path getClip(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final base = size.shortestSide / 2;
    // Fixed wobble pattern (not random) so the shape is stable across
    // rebuilds/relayouts instead of jittering every frame.
    const wobble = [1.0, 0.85, 1.1, 0.9, 1.15, 0.8, 1.05, 0.92];
    final points = <Offset>[];
    for (var i = 0; i < wobble.length; i++) {
      final angle = i * (360 / wobble.length) * math.pi / 180;
      final r = base * wobble[i];
      points.add(Offset(center.dx + r * math.cos(angle), center.dy + r * math.sin(angle)));
    }
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (var i = 0; i < points.length; i++) {
      final next = points[(i + 1) % points.length];
      final mid = Offset((points[i].dx + next.dx) / 2, (points[i].dy + next.dy) / 2);
      path.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// A jagged, hand-torn-paper-look edge drawn just inside a tile's border —
/// a purely decorative overlay, so it works with any of the tile's own
/// shapes instead of needing its own clip.
class _TornEdgePainter extends CustomPainter {
  final bool dark;
  const _TornEdgePainter({required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (dark ? Colors.white : Colors.black).withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    const jag = 7.0;
    // Fixed jitter pattern (not random) so the edge is stable across
    // rebuilds, matching the approach used by _BlobClipper/_BoardTexturePainter.
    const wobble = [0.0, 1.6, -1.2, 2.0, -1.8, 1.2, -0.6, 1.8];
    final path = Path();
    var toggle = 0;
    for (var x = 0.0; x <= size.width; x += jag) {
      final y = wobble[toggle % wobble.length];
      if (x == 0) {
        path.moveTo(x, y.abs());
      } else {
        path.lineTo(x, y.abs());
      }
      toggle++;
    }
    for (var y = 0.0; y <= size.height; y += jag) {
      final x = size.width - wobble[toggle % wobble.length].abs();
      path.lineTo(x, y);
      toggle++;
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TornEdgePainter oldDelegate) => oldDelegate.dark != dark;
}

/// Diagonal hatch lines standing in for a photo, used when a tile has no
/// image yet.
class _HatchPainter extends CustomPainter {
  final Color color;
  const _HatchPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.22)
      ..strokeWidth = 1;
    const gap = 10.0;
    for (var x = -size.height; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HatchPainter oldDelegate) => oldDelegate.color != color;
}
