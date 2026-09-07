import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'dashboard_screen.dart';
import 'evening_reflection_screen.dart';
import 'exercise_timer_screen.dart';
import 'habit_detail_screen.dart';
import 'mind_map_screen.dart';
import 'monthly_goals_screen.dart';
import 'personal_care_screen.dart';
import 'reminders_screen.dart';
import 'scripting_screen.dart';
import 'spending_tracker_screen.dart';
import 'todo_list_screen.dart';
import 'vision_board_screen.dart';
import 'weekly_goals_screen.dart';

const _moods = [
  ('Rough', '😔'),
  ('Meh', '😕'),
  ('Okay', '😐'),
  ('Good', '🙂'),
  ('Amazing', '🤩'),
];

/// Short one-word bottom-nav labels — a section's full title (used as that
/// section's own screen header) is often too long for a nav bar.
String _sectionShortLabel(String key) {
  switch (key) {
    case 'productivity':
      return 'Tasks';
    case 'outcome':
      return 'Outcome';
    case 'finance':
      return 'Finance';
    case 'health':
      return 'Health';
    case 'mindset':
      return 'Mindset';
    case 'relationships':
      return 'Connect';
    default:
      return key;
  }
}

IconData _sectionIcon(String key) {
  switch (key) {
    case 'productivity':
      return Icons.checklist_rounded;
    case 'outcome':
      return Icons.auto_awesome;
    case 'finance':
      return Icons.account_balance_wallet_outlined;
    case 'health':
      return Icons.favorite_border;
    case 'mindset':
      return Icons.psychology_alt_outlined;
    case 'relationships':
      return Icons.diversity_1_outlined;
    default:
      return Icons.circle_outlined;
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// The app's shell: a Dashboard tab (greeting, mantra, quick stats — see
/// dashboard_screen.dart) plus one bottom-nav tab per visible section, each
/// its own separate, focused screen instead of a swipeable card sharing a
/// header with everything else. Up to 3 sections get their own tab; any
/// more live under "More" so the bar never gets crowded — still one tap
/// away, just not competing for space with Dashboard/Tasks/Outcome/Finance.
class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowDailyPrompts());
  }

  Future<void> _maybeShowDailyPrompts() async {
    if (!mounted) return;
    if (store.shouldShowMoodPrompt) {
      await showDialog<void>(
        context: context,
        builder: (_) => const _MoodDialog(),
      );
    }
    if (!mounted) return;
    if (store.shouldShowEveningPrompt) {
      await showDialog<void>(
        context: context,
        builder: (_) => const _EveningPromptDialog(),
      );
    }
  }

  Widget _itemFor(String id) {
    switch (id) {
      case 'priorities':
        return const _QuickLaunchButtons();
      case 'habits':
        return const _HabitsContent();
      case 'tips':
        return const _TipItem();
      case 'eveningReflection':
        return const _EveningReflectionItem();
      case 'reminders':
        return const _ReminderItem();
      case 'scripting':
        return const _ScriptingItem();
      case 'visionBoard':
        return const _VisionBoardItem();
      case 'mindMap':
        return const _MindMapItem();
      case 'financeGoals':
        return const _FinanceGoalsContent();
      case 'healthGoals':
        return const _HealthGoalsContent();
      case 'mindsetGoals':
        return const _MindsetGoalsContent();
      case 'relationshipsGoals':
        return const _RelationshipsGoalsContent();
      default:
        return const SizedBox.shrink();
    }
  }

  void _openSection(String key, List<HomePageSection> primary, List<HomePageSection> overflow) {
    final primaryIndex = primary.indexWhere((s) => s.key == key);
    if (primaryIndex >= 0) {
      setState(() => _tabIndex = primaryIndex + 1); // +1 for the Dashboard tab
      return;
    }
    final match = overflow.where((s) => s.key == key).toList();
    if (match.isEmpty) return;
    _pushSection(match.first);
  }

  void _pushSection(HomePageSection section) {
    final visible = store.visibleModuleIds;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _SectionScreen(
        title: section.title,
        sectionKey: section.key,
        items: [
          for (final id in section.moduleIds)
            if (visible.contains(id)) _itemFor(id),
        ],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final visible = store.visibleModuleIds;
        // Built from the single shared kHomePageSections list (models.dart)
        // so this order always matches the Settings > "Starting screen"
        // picker — one source of truth instead of hand-kept lists.
        final visibleSections = [
          for (final section in kHomePageSections)
            if (section.moduleIds.any(visible.contains)) section,
        ];
        // Every visible section now gets its own bottom-nav tab — none of
        // them are pushed into a "More" screen any more. A fixed-width
        // NavigationBar can't fit an open-ended number of tabs, so the bar
        // itself scrolls horizontally instead (see _ScrollableNavBar) and
        // "More" is retired as a nav destination (About Us stays reachable
        // from the Dashboard, as it already was).
        final primarySections = visibleSections;
        const overflowSections = <HomePageSection>[];

        final tabs = <Widget>[
          DashboardScreen(
            sections: visibleSections,
            onOpenSection: (key) => _openSection(key, primarySections, overflowSections),
          ),
          for (final section in primarySections)
            _SectionScreen(
              title: section.title,
              sectionKey: section.key,
              showBackButton: false,
              items: [
                for (final id in section.moduleIds)
                  if (visible.contains(id)) _itemFor(id),
              ],
            ),
        ];

        final navItems = <_NavItem>[
          const _NavItem(
              icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Dashboard'),
          for (final section in primarySections)
            _NavItem(icon: _sectionIcon(section.key), label: _sectionShortLabel(section.key)),
        ];

        final safeIndex = _tabIndex.clamp(0, tabs.length - 1);

        return Scaffold(
          body: tabs.isEmpty
              ? const SizedBox.shrink()
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: KeyedSubtree(key: ValueKey(safeIndex), child: tabs[safeIndex]),
                ),
          bottomNavigationBar: navItems.length > 1
              ? SafeArea(
                  top: false,
                  child: _ScrollableNavBar(
                    selectedIndex: safeIndex,
                    items: navItems,
                    onSelected: (i) => setState(() => _tabIndex = i),
                  ),
                )
              : null,
        );
      },
    );
  }
}

/// One entry in the bottom nav bar's model — decoupled from
/// [NavigationDestination] so the bar itself can be a plain horizontally
/// scrolling row instead of Material's fixed-width widget.
class _NavItem {
  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  const _NavItem({required this.icon, this.selectedIcon, required this.label});
}

/// A bottom nav bar that scrolls horizontally so every visible section can
/// have its own tab — Material's [NavigationBar] only ever lays out a fixed
/// row and starts squeezing labels/icons once there are more than about 5
/// destinations, which is exactly the "only 3 + More" ceiling this replaces.
/// Auto-scrolls to keep the selected tab in view when it changes off-screen
/// (e.g. after adding/removing modules in Settings).
class _ScrollableNavBar extends StatefulWidget {
  final int selectedIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onSelected;
  const _ScrollableNavBar({
    required this.selectedIndex,
    required this.items,
    required this.onSelected,
  });

  @override
  State<_ScrollableNavBar> createState() => _ScrollableNavBarState();
}

class _ScrollableNavBarState extends State<_ScrollableNavBar> {
  final _scrollController = ScrollController();
  var _keys = <GlobalKey>[];

  @override
  void initState() {
    super.initState();
    _keys = [for (var i = 0; i < widget.items.length; i++) GlobalKey()];
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  @override
  void didUpdateWidget(covariant _ScrollableNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      _keys = [for (var i = 0; i < widget.items.length; i++) GlobalKey()];
    }
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
    }
  }

  void _scrollToSelected() {
    if (widget.selectedIndex < 0 || widget.selectedIndex >= _keys.length) return;
    final ctx = _keys[widget.selectedIndex].currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: 0.5);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Surfaces.sheet(dark),
        border: Border(top: BorderSide(color: Surfaces.cardBorder(dark))),
      ),
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          children: [
            for (var i = 0; i < widget.items.length; i++)
              Container(
                key: _keys[i],
                margin: const EdgeInsets.symmetric(horizontal: 3),
                child: _NavChip(
                  item: widget.items[i],
                  selected: i == widget.selectedIndex,
                  dark: dark,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onSelected(i);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavChip extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final bool dark;
  final VoidCallback onTap;
  const _NavChip({
    required this.item,
    required this.selected,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? Surfaces.accent(dark) : Surfaces.muted(dark);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        constraints: const BoxConstraints(minWidth: 64),
        decoration: BoxDecoration(
          color: selected ? Surfaces.accentCard(dark) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? (item.selectedIcon ?? item.icon) : item.icon,
                size: 22, color: color),
            const SizedBox(height: 3),
            Text(item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: body(10.5, color,
                    weight: selected ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

/// One section as its own separate, focused screen — a header (no repeated
/// greeting/mantra), its content, and a floating jump button that appears
/// once there's more than one screenful to scroll through.
class _SectionScreen extends StatefulWidget {
  final String title;
  final String sectionKey;
  final List<Widget> items;
  final bool showBackButton;
  const _SectionScreen({
    required this.title,
    this.sectionKey = '_',
    required this.items,
    this.showBackButton = true,
  });

  @override
  State<_SectionScreen> createState() => _SectionScreenState();
}

class _SectionScreenState extends State<_SectionScreen> {
  final _scrollController = ScrollController();
  bool _overflows = false;
  bool _atBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _checkOverflow() {
    if (!mounted || !_scrollController.hasClients) return;
    final overflows = _scrollController.position.maxScrollExtent > 8;
    if (overflows != _overflows) setState(() => _overflows = overflows);
  }

  void _onScroll() {
    _checkOverflow();
    final atBottom = _scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 24;
    if (atBottom != _atBottom) setState(() => _atBottom = atBottom);
  }

  void _jump() {
    if (!_scrollController.hasClients) return;
    HapticFeedback.lightImpact();
    final target = _atBottom ? 0.0 : _scrollController.position.maxScrollExtent;
    _scrollController.animateTo(target,
        duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
  }

  Future<void> _refresh() async => store.load();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
    return Scaffold(
      body: Container(
        decoration: Surfaces.pageBackground(dark),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  ScreenHeader(
                      icon: _sectionIcon(widget.sectionKey),
                      title: widget.title,
                      showBackButton: widget.showBackButton),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _refresh,
                      color: Surfaces.accent(dark),
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                        child: ModuleCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var i = 0; i < widget.items.length; i++) ...[
                                widget.items[i],
                                if (i != widget.items.length - 1) ...[
                                  const SizedBox(height: 18),
                                  Divider(height: 1, color: Surfaces.cardBorder(dark)),
                                  const SizedBox(height: 18),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_overflows)
                Positioned(
                  right: 18,
                  bottom: 18,
                  child: FloatingActionButton.small(
                    heroTag: null,
                    onPressed: _jump,
                    backgroundColor: Surfaces.accent(dark),
                    child: Icon(_atBottom ? Icons.arrow_upward : Icons.arrow_downward,
                        color: Colors.white, size: 18),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small header row used by each item inside a section page — an icon,
/// a title, and whatever trailing summary/action the item wants.
class _ItemHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  const _ItemHeader({required this.icon, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, color: Surfaces.accent(dark), size: 20),
        const SizedBox(width: 10),
        Expanded(
          // flex:3 vs trailing's flex:2 below — without an explicit flex
          // split, an unbounded trailing widget (e.g. a long reminder-times
          // summary) can claim nearly all the Row's width and squeeze this
          // Text down to a couple of pixels, which wraps it one letter per
          // line instead of eliding it. maxLines/overflow here is a second,
          // independent safety net for the same failure mode.
          flex: 3,
          child: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: body(14, Surfaces.heading(dark), weight: FontWeight.w700)),
        ),
        if (trailing != null) Flexible(flex: 2, child: trailing!),
      ],
    );
  }
}

class _TipItem extends StatelessWidget {
  const _TipItem();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lightbulb_outline, color: Surfaces.accent(dark), size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Productivity tip',
                  style: body(14, Surfaces.heading(dark), weight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(store.tipOfTheDay, style: body(13, Surfaces.bodyText(dark))),
            ],
          ),
        ),
      ],
    );
  }
}

/// Three floating quick-launch buttons replacing the old inline "today's
/// log" list — each opens its own full screen (to-do list, weekly goals,
/// monthly goals) with its own add/save/display flow.
class _QuickLaunchButtons extends StatelessWidget {
  const _QuickLaunchButtons();

  @override
  Widget build(BuildContext context) {
    final openTodos = store.todaysTasks.where((t) => !t.done).length;
    final openWeekly = store.weeklyGoals.where((t) => !t.done).length;
    final openMonthly = store.monthlyGoals.where((t) => !t.done).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ItemHeader(icon: Icons.dashboard_customize_outlined, title: 'Goals & to-dos'),
        const SizedBox(height: 14),
        _QuickLaunchButton(
          icon: Icons.edit_note_rounded,
          label: "Today's to-do list",
          summary: openTodos == 0 ? 'All clear' : '$openTodos open',
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const TodoListScreen())),
        ),
        const SizedBox(height: 10),
        _QuickLaunchButton(
          icon: Icons.sports_score_rounded,
          label: 'Weekly goals',
          summary: openWeekly == 0 ? 'All clear' : '$openWeekly open',
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const WeeklyGoalsScreen())),
        ),
        const SizedBox(height: 10),
        _QuickLaunchButton(
          icon: Icons.calendar_month_rounded,
          label: 'Monthly goals',
          summary: openMonthly == 0 ? 'All clear' : '$openMonthly open',
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const MonthlyGoalsScreen())),
        ),
      ],
    );
  }
}

class _QuickLaunchButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String summary;
  final VoidCallback onTap;
  const _QuickLaunchButton({
    required this.icon,
    required this.label,
    required this.summary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Surfaces.accent(dark).withValues(alpha: 0.10),
          border: Border.all(color: Surfaces.accent(dark).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Surfaces.accent(dark).withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Surfaces.accent(dark), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: body(14, Surfaces.heading(dark), weight: FontWeight.w700)),
            ),
            Text(summary, style: body(11.5, Surfaces.muted(dark))),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, color: Surfaces.muted(dark), size: 18),
          ],
        ),
      ),
    );
  }
}

/// Habit tracker — each habit is a full-width, softly-gradient "story card"
/// keyed on its stable id (not object identity), so add/remove/edit stay
/// correct no matter what else has rebuilt in between.
class _HabitsContent extends StatelessWidget {
  const _HabitsContent();

  Future<void> _addHabit(BuildContext context) async {
    final result = await showModalBottomSheet<(String, int, int)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const HabitEditorSheet(),
    );
    if (result != null) {
      await store.addHabit(result.$1, iconIndex: result.$2, colorIndex: result.$3);
      if (context.mounted) toastSaved(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final today = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ItemHeader(icon: Icons.self_improvement, title: 'Habits'),
        const SizedBox(height: 14),
        if (store.habits.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('Nothing tracked yet — add the first one below.',
                style: body(13, Surfaces.muted(dark))),
          ),
        for (final habit in store.habits)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Dismissible(
              key: ValueKey(habit.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 18),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.delete_outline, color: Colors.white),
              ),
              confirmDismiss: (_) => showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Remove "${habit.name}"?',
                      style: display(16, Surfaces.heading(dark))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Keep it')),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Remove')),
                  ],
                ),
              ),
              onDismissed: (_) async {
                await store.removeHabit(habit);
                if (context.mounted) toastSaved(context);
              },
              child: _HabitCard(habit: habit, today: today),
            ),
          ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => _addHabit(context),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Surfaces.accent(dark).withValues(alpha: 0.5),
                width: 1.4,
                style: BorderStyle.solid,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle_outline, color: Surfaces.accent(dark), size: 18),
                const SizedBox(width: 8),
                Text('Add a habit',
                    style: body(13, Surfaces.accent(dark), weight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HabitCard extends StatefulWidget {
  final Habit habit;
  final DateTime today;
  const _HabitCard({required this.habit, required this.today});

  @override
  State<_HabitCard> createState() => _HabitCardState();
}

class _HabitCardState extends State<_HabitCard> {
  Future<void> _toggle() async {
    HapticFeedback.lightImpact();
    await store.toggleHabit(widget.habit);
    if (mounted) toastSaved(context);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final habit = widget.habit;
    final color = habitColorFor(habit.colorIndex);
    final done = habit.isDoneOn(widget.today);
    final streak = habit.streak(widget.today);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => HabitDetailScreen(habit: habit))),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: done ? 0.30 : 0.14),
              color.withValues(alpha: done ? 0.12 : 0.05),
            ],
          ),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            HabitBadge(iconIndex: habit.iconIndex, colorIndex: habit.colorIndex, size: 42),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(habit.name,
                      style: body(14.5, Surfaces.heading(dark), weight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                    streak > 0 ? '🔥 $streak day streak' : 'Tap to start a streak',
                    style: body(11.5, Surfaces.muted(dark)),
                  ),
                  const SizedBox(height: 8),
                  _WeekDots(habit: habit, today: widget.today, color: color),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _toggle,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 180),
                scale: done ? 1.08 : 1.0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? color : Colors.transparent,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: done
                      ? const Icon(Icons.check, color: Brand.deep, size: 18)
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A week-at-a-glance strip — filled dot for a day this habit was done,
/// hollow for a miss, today ringed — the small daily-progress cue several
/// of the reference trackers use (water glasses, sleep-hour ticks), reworked
/// here as a compact row that fits inline in the habit card.
class _WeekDots extends StatelessWidget {
  final Habit habit;
  final DateTime today;
  final Color color;
  const _WeekDots({required this.habit, required this.today, required this.color});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        for (var i = 6; i >= 0; i--) ...[
          Builder(builder: (context) {
            final day = DateTime(today.year, today.month, today.day)
                .subtract(Duration(days: i));
            final done = habit.isDoneOn(day);
            final isToday = i == 0;
            return Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? color : Colors.transparent,
                border: Border.all(
                  color: done
                      ? color
                      : Surfaces.muted(dark).withValues(alpha: isToday ? 0.7 : 0.3),
                  width: isToday && !done ? 1.6 : 1,
                ),
              ),
            );
          }),
          if (i != 0) const SizedBox(width: 4),
        ],
      ],
    );
  }
}

class _ScriptingItem extends StatelessWidget {
  const _ScriptingItem();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final count = store.scripts.length;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const ScriptingScreen())),
      child: _ItemHeader(
        icon: Icons.auto_awesome,
        title: 'Journaling (Brain Dump)',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(count == 0 ? 'Not started' : '$count written',
                style: body(12, Surfaces.muted(dark))),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, color: Surfaces.muted(dark), size: 18),
          ],
        ),
      ),
    );
  }
}

class _EveningReflectionItem extends StatelessWidget {
  const _EveningReflectionItem();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final done = !store.todaysJournal.isEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      // A single app-wide lock (asked once at launch/resume) is enough —
      // no second PIN gate for a screen you're already inside the app to see.
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const EveningReflectionScreen())),
      child: _ItemHeader(
        icon: Icons.nights_stay_outlined,
        title: 'Evening reflection',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(done ? 'Written for today' : 'Not written yet',
                style: body(12, Surfaces.muted(dark))),
            if (store.hasPin) ...[
              const SizedBox(width: 6),
              Icon(Icons.lock_outline, size: 15, color: Surfaces.muted(dark)),
            ],
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, color: Surfaces.muted(dark), size: 18),
          ],
        ),
      ),
    );
  }
}

class _VisionBoardItem extends StatelessWidget {
  const _VisionBoardItem();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final count = store.visionItems.length;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const VisionBoardScreen())),
      child: _ItemHeader(
        icon: Icons.grid_view_rounded,
        title: 'Vision board',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(count == 0 ? 'Nothing pinned yet' : '$count pinned',
                style: body(12, Surfaces.muted(dark))),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, color: Surfaces.muted(dark), size: 18),
          ],
        ),
      ),
    );
  }
}

class _MindMapItem extends StatelessWidget {
  const _MindMapItem();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const MindMapScreen())),
      child: _ItemHeader(
        icon: Icons.account_tree_outlined,
        title: 'Organized mind map',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Day · week · month',
                style: body(12, Surfaces.muted(dark))),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, color: Surfaces.muted(dark), size: 18),
          ],
        ),
      ),
    );
  }
}

/// Simple checklist for money-related intentions — savings targets, debt
/// payoff steps, budget checkpoints — same interaction as weekly/monthly
/// goals, its own swipeable home card.
/// A generic goal checklist — add, check off, remove, all with a save
/// confirmation — reused by Finance & money, Health & body, Mindset &
/// growth, and Relationships & connection so those four cards share one
/// implementation instead of four near-identical copies.
class _GoalListContent extends StatefulWidget {
  final IconData icon;
  final String title;
  final String hint;
  final String emptyText;
  final List<Task> Function() goals;
  final Future<void> Function(String title) onAdd;
  final Future<void> Function(int index) onToggle;
  final Future<void> Function(int index) onRemove;

  const _GoalListContent({
    required this.icon,
    required this.title,
    required this.hint,
    required this.emptyText,
    required this.goals,
    required this.onAdd,
    required this.onToggle,
    required this.onRemove,
  });

  @override
  State<_GoalListContent> createState() => _GoalListContentState();
}

class _GoalListContentState extends State<_GoalListContent> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (_controller.text.trim().isEmpty) return;
    await widget.onAdd(_controller.text);
    _controller.clear();
    if (mounted) {
      FocusScope.of(context).unfocus();
      toastSaved(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final goals = widget.goals();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ItemHeader(icon: widget.icon, title: widget.title),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                onSubmitted: (_) => _add(),
                textCapitalization: TextCapitalization.sentences,
                style: body(13.5, Surfaces.bodyText(dark), weight: FontWeight.w500),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: widget.hint,
                  hintStyle: body(13, Surfaces.muted(dark)),
                ),
              ),
            ),
            IconButton(
              onPressed: _add,
              icon: Icon(Icons.add_circle, color: Surfaces.accent(dark), size: 28),
            ),
          ],
        ),
        if (goals.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(widget.emptyText, style: body(13, Surfaces.muted(dark))),
          ),
        for (var i = 0; i < goals.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                CheckSquare(
                  checked: goals[i].done,
                  onTap: () async {
                    await widget.onToggle(i);
                    if (context.mounted) toastSaved(context);
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    goals[i].title,
                    style: body(13.5,
                            goals[i].done ? Surfaces.muted(dark) : Surfaces.bodyText(dark),
                            weight: FontWeight.w500)
                        .copyWith(
                            decoration:
                                goals[i].done ? TextDecoration.lineThrough : TextDecoration.none),
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    await widget.onRemove(i);
                    if (context.mounted) toastSaved(context, label: 'Removed');
                  },
                  icon: Icon(Icons.close, size: 16, color: Surfaces.muted(dark)),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FinanceGoalsContent extends StatefulWidget {
  const _FinanceGoalsContent();
  @override
  State<_FinanceGoalsContent> createState() => _FinanceGoalsContentState();
}

class _FinanceGoalsContentState extends State<_FinanceGoalsContent> {
  final _dreamCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _monthsCtrl = TextEditingController(text: '12');
  final _incomeCtrl = TextEditingController();
  bool _editingRoadmap = false;

  @override
  void initState() {
    super.initState();
    // Prefill from the wallet's own budget when the user hasn't set a
    // calculator income yet — one number entered once (in the wallet)
    // carries over here instead of asking for it twice.
    final prefill = store.financeBudgetIncome ?? store.spendBudgetAmount;
    if (prefill != null) {
      _incomeCtrl.text = prefill.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _dreamCtrl.dispose();
    _amountCtrl.dispose();
    _monthsCtrl.dispose();
    _incomeCtrl.dispose();
    super.dispose();
  }

  void _startEditingRoadmap() {
    final roadmap = store.financeRoadmap;
    _dreamCtrl.text = roadmap?.dreamGoal ?? '';
    _amountCtrl.text = roadmap == null ? '' : roadmap.targetAmount.toStringAsFixed(0);
    _monthsCtrl.text = roadmap == null ? '12' : roadmap.months.toString();
    setState(() => _editingRoadmap = true);
  }

  Future<void> _createRoadmap() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    final monthsRaw = int.tryParse(_monthsCtrl.text.trim()) ?? 12;
    final months = monthsRaw.clamp(1, 360);
    if (_dreamCtrl.text.trim().isEmpty || amount == null || amount <= 0 || monthsRaw <= 0) return;
    await store.setFinanceRoadmap(_dreamCtrl.text, amount, months);
    _dreamCtrl.clear();
    _amountCtrl.clear();
    _monthsCtrl.text = '12';
    if (mounted) {
      FocusScope.of(context).unfocus();
      setState(() => _editingRoadmap = false);
      toastSaved(context);
    }
  }

  void _applyIncome() {
    final income = double.tryParse(_incomeCtrl.text.trim());
    if (income == null || income < 0) return;
    store.setFinanceBudgetIncome(income);
    setState(() {});
    FocusScope.of(context).unfocus();
    toastSaved(context);
  }

  Future<void> _adjustSplit({required String moved, required double value}) async {
    // Move the dragged slider to `value`, then redistribute the remaining
    // budget proportionally across the other two so all three keep summing
    // to 100 — e.g. dragging Needs up shrinks Wants and Savings together,
    // in whatever ratio they already had to each other.
    var needs = store.financeBudgetNeedsPct;
    var wants = store.financeBudgetWantsPct;
    var savings = store.financeBudgetSavingsPct;

    double a, b;
    switch (moved) {
      case 'needs':
        needs = value;
        a = wants;
        b = savings;
        final remaining = 100 - needs;
        final otherSum = a + b;
        if (otherSum <= 0) {
          wants = remaining / 2;
          savings = remaining / 2;
        } else {
          wants = remaining * (a / otherSum);
          savings = remaining * (b / otherSum);
        }
        break;
      case 'wants':
        wants = value;
        a = needs;
        b = savings;
        final remaining = 100 - wants;
        final otherSum = a + b;
        if (otherSum <= 0) {
          needs = remaining / 2;
          savings = remaining / 2;
        } else {
          needs = remaining * (a / otherSum);
          savings = remaining * (b / otherSum);
        }
        break;
      default:
        savings = value;
        a = needs;
        b = wants;
        final remaining = 100 - savings;
        final otherSum = a + b;
        if (otherSum <= 0) {
          needs = remaining / 2;
          wants = remaining / 2;
        } else {
          needs = remaining * (a / otherSum);
          wants = remaining * (b / otherSum);
        }
    }
    await store.setFinanceBudgetSplit(needs, wants, savings);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final roadmap = store.financeRoadmap;
    final income = store.financeBudgetIncome;
    final needsPct = store.financeBudgetNeedsPct;
    final wantsPct = store.financeBudgetWantsPct;
    final savingsPct = store.financeBudgetSavingsPct;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ItemHeader(icon: Icons.savings_outlined, title: 'Finance & money goals'),
        const SizedBox(height: 12),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SpendingTrackerScreen())),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Surfaces.accent(dark).withValues(alpha: 0.10),
              border: Border.all(color: Surfaces.accent(dark).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined, size: 18, color: Surfaces.accent(dark)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Wallet & spending tracker — Need vs Want',
                      style: body(12.5, Surfaces.accent(dark), weight: FontWeight.w700)),
                ),
                Icon(Icons.chevron_right, size: 16, color: Surfaces.accent(dark)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ---- Goal Roadmap: Dream Goal -> 12-Month Goal -> Monthly Milestones ----
        Text('GOAL ROADMAP', style: label(Surfaces.eyebrow(dark))),
        const SizedBox(height: 10),
        if (roadmap == null || _editingRoadmap) ...[
          TextField(
            controller: _dreamCtrl,
            textCapitalization: TextCapitalization.sentences,
            style: body(13.5, Surfaces.bodyText(dark), weight: FontWeight.w500),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Your dream goal — e.g. Down payment on a home',
              hintStyle: body(12.5, Surfaces.muted(dark)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: body(13.5, Surfaces.bodyText(dark), weight: FontWeight.w500),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixText: '₹ ',
                    hintText: 'Target amount',
                    hintStyle: body(12.5, Surfaces.muted(dark)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 90,
                child: TextField(
                  controller: _monthsCtrl,
                  keyboardType: TextInputType.number,
                  style: body(13.5, Surfaces.bodyText(dark), weight: FontWeight.w500),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Months',
                    hintStyle: body(12.5, Surfaces.muted(dark)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GoldButton(
                    labelText: roadmap == null ? 'Create roadmap' : 'Save changes',
                    onPressed: _createRoadmap),
              ),
              if (roadmap != null) ...[
                const SizedBox(width: 10),
                TextButton(
                  onPressed: () => setState(() => _editingRoadmap = false),
                  child: Text('Cancel',
                      style: body(12.5, Surfaces.muted(dark), weight: FontWeight.w600)),
                ),
              ],
            ],
          ),
        ] else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(roadmap.dreamGoal, style: display(15, Surfaces.heading(dark))),
              ),
              IconButton(
                onPressed: _startEditingRoadmap,
                icon: Icon(Icons.edit_outlined, size: 18, color: Surfaces.muted(dark)),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '₹${roadmap.savedSoFar.toStringAsFixed(0)} of ₹${roadmap.targetAmount.toStringAsFixed(0)} · ₹${roadmap.perMonth.toStringAsFixed(0)}/month for ${roadmap.months} months',
            style: body(12, Surfaces.muted(dark)),
          ),
          const SizedBox(height: 10),
          _ProgressBar(
            progress: roadmap.targetAmount == 0
                ? 0
                : (roadmap.savedSoFar / roadmap.targetAmount).clamp(0, 1).toDouble(),
            dark: dark,
          ),
          const SizedBox(height: 4),
          Text(
            roadmap.targetAmount == 0
                ? '0% there'
                : '${((roadmap.savedSoFar / roadmap.targetAmount) * 100).clamp(0, 100).toStringAsFixed(0)}% there — keep going!',
            style: body(11.5, Surfaces.accent(dark), weight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < roadmap.months; i++)
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () async {
                    await store.toggleRoadmapMonth(i);
                    setState(() {});
                  },
                  child: Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: roadmap.monthsDone[i]
                          ? _milestoneColor(i, roadmap.months)
                          : _milestoneColor(i, roadmap.months).withValues(alpha: 0.12),
                      border: Border.all(color: _milestoneColor(i, roadmap.months), width: 1.2),
                    ),
                    child: roadmap.monthsDone[i]
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : Text('${i + 1}',
                            style: body(12, _milestoneColor(i, roadmap.months),
                                weight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () async {
              await store.clearFinanceRoadmap();
              setState(() {});
            },
            child: Text('Clear and start a new roadmap',
                style: body(12, Surfaces.muted(dark), weight: FontWeight.w600)),
          ),
        ],

        const SizedBox(height: 18),
        Divider(height: 1, color: Surfaces.cardBorder(dark)),
        const SizedBox(height: 18),

        // ---- Budget calculator, split adjustable by the user ----
        Row(
          children: [
            Expanded(
              child: Text('BUDGET CALCULATOR', style: label(Surfaces.eyebrow(dark))),
            ),
            TextButton(
              onPressed: () async {
                await store.resetFinanceBudgetSplit();
                setState(() {});
              },
              child: Text('Reset to 50/30/20',
                  style: body(11, Surfaces.muted(dark), weight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _incomeCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onSubmitted: (_) => _applyIncome(),
                style: body(13.5, Surfaces.bodyText(dark), weight: FontWeight.w500),
                decoration: InputDecoration(
                  isDense: true,
                  prefixText: '₹ ',
                  hintText: 'Monthly income',
                  hintStyle: body(12.5, Surfaces.muted(dark)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GoldButton(labelText: 'Split it', onPressed: _applyIncome),
          ],
        ),
        const SizedBox(height: 14),
        _BudgetSliderRow(
          label: 'Needs',
          color: const Color(0xFF6FDCA8),
          pct: needsPct,
          amount: income == null ? null : income * needsPct / 100,
          dark: dark,
          onChanged: (v) => _adjustSplit(moved: 'needs', value: v),
        ),
        const SizedBox(height: 10),
        _BudgetSliderRow(
          label: 'Wants',
          color: const Color(0xFF7FC8F8),
          pct: wantsPct,
          amount: income == null ? null : income * wantsPct / 100,
          dark: dark,
          onChanged: (v) => _adjustSplit(moved: 'wants', value: v),
        ),
        const SizedBox(height: 10),
        _BudgetSliderRow(
          label: 'Savings & debt',
          color: const Color(0xFFF08BA0),
          pct: savingsPct,
          amount: income == null ? null : income * savingsPct / 100,
          dark: dark,
          onChanged: (v) => _adjustSplit(moved: 'savings', value: v),
        ),
        const SizedBox(height: 14),
        _BudgetStackedBar(needsPct: needsPct, wantsPct: wantsPct, savingsPct: savingsPct),

        if (income != null && income > 0) ...[
          const SizedBox(height: 16),
          Text('ACTUAL VS PLANNED — WALLET SPENDING', style: label(Surfaces.eyebrow(dark))),
          const SizedBox(height: 10),
          _ActualVsPlannedRow(
            label: 'Needs',
            color: const Color(0xFF6FDCA8),
            actual: store.totalNeedSpent,
            planned: income * needsPct / 100,
            dark: dark,
          ),
          const SizedBox(height: 8),
          _ActualVsPlannedRow(
            label: 'Wants',
            color: const Color(0xFF7FC8F8),
            actual: store.totalWantSpent,
            planned: income * wantsPct / 100,
            dark: dark,
          ),
          const SizedBox(height: 6),
          Text(
            'From your wallet & spending tracker — logged expenses tagged Need or Want, compared against this split.',
            textAlign: TextAlign.justify,
            style: body(11, Surfaces.muted(dark)).copyWith(height: 1.4),
          ),
        ],

        const SizedBox(height: 18),
        Divider(height: 1, color: Surfaces.cardBorder(dark)),
        const SizedBox(height: 18),

        _GoalListContent(
          icon: Icons.checklist_outlined,
          title: 'Other money goals',
          hint: 'e.g. Save ₹500 this month',
          emptyText: 'Nothing set yet — add a money goal above.',
          goals: () => store.financeGoals,
          onAdd: store.addFinanceGoal,
          onToggle: store.toggleFinanceGoal,
          onRemove: store.removeFinanceGoal,
        ),
      ],
    );
  }
}

/// Cycles a small, cheerful palette across roadmap milestones so the whole
/// row reads as playful progress rather than a plain numbered list.
Color _milestoneColor(int index, int total) {
  const palette = [
    Color(0xFFF2B93B),
    Color(0xFF6FDCA8),
    Color(0xFF7FC8F8),
    Color(0xFFF08BA0),
    Color(0xFFC79BF0),
    Color(0xFFFF9770),
  ];
  return palette[index % palette.length];
}

class _ProgressBar extends StatelessWidget {
  final double progress;
  final bool dark;
  const _ProgressBar({required this.progress, required this.dark});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => Stack(
          children: [
            Container(height: 14, color: Surfaces.accent(dark).withValues(alpha: 0.12)),
            FractionallySizedBox(
              widthFactor: value.clamp(0, 1),
              child: Container(
                height: 14,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6FDCA8), Color(0xFFF2B93B)],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetSliderRow extends StatelessWidget {
  final String label;
  final Color color;
  final double pct;
  final double? amount;
  final bool dark;
  final ValueChanged<double> onChanged;
  const _BudgetSliderRow({
    required this.label,
    required this.color,
    required this.pct,
    required this.amount,
    required this.dark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
                width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(
              child: Text('$label (${pct.round()}%)',
                  style: body(13, Surfaces.bodyText(dark), weight: FontWeight.w600)),
            ),
            if (amount != null)
              Text('₹${amount!.toStringAsFixed(0)}',
                  style: body(13, color, weight: FontWeight.w700)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            thumbColor: color,
            inactiveTrackColor: color.withValues(alpha: 0.15),
            overlayColor: color.withValues(alpha: 0.15),
            trackHeight: 4,
          ),
          child: Slider(
            value: pct.clamp(0, 100),
            min: 0,
            max: 100,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _BudgetStackedBar extends StatelessWidget {
  final double needsPct;
  final double wantsPct;
  final double savingsPct;
  const _BudgetStackedBar(
      {required this.needsPct, required this.wantsPct, required this.savingsPct});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 18,
        child: Row(
          children: [
            Expanded(
                flex: (needsPct * 10).round().clamp(1, 1000),
                child: Container(color: const Color(0xFF6FDCA8))),
            Expanded(
                flex: (wantsPct * 10).round().clamp(1, 1000),
                child: Container(color: const Color(0xFF7FC8F8))),
            Expanded(
                flex: (savingsPct * 10).round().clamp(1, 1000),
                child: Container(color: const Color(0xFFF08BA0))),
          ],
        ),
      ),
    );
  }
}

/// Compares one budget category's planned allocation (income × its %) with
/// what's actually been logged in the wallet tracker tagged that way — the
/// link between the budget calculator and real spending the user asked for.
class _ActualVsPlannedRow extends StatelessWidget {
  final String label;
  final Color color;
  final double actual;
  final double planned;
  final bool dark;
  const _ActualVsPlannedRow({
    required this.label,
    required this.color,
    required this.actual,
    required this.planned,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final pct = planned <= 0 ? 0.0 : (actual / planned).clamp(0.0, 1.5);
    final over = planned > 0 && actual > planned;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, style: body(12.5, Surfaces.bodyText(dark), weight: FontWeight.w600)),
            ),
            Text('₹${actual.toStringAsFixed(0)} / ₹${planned.toStringAsFixed(0)}',
                style: body(12, over ? Colors.redAccent : color, weight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct.clamp(0, 1),
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.15),
            color: over ? Colors.redAccent : color,
          ),
        ),
      ],
    );
  }
}

/// One suggested daily habit for a body system — tap to add/remove straight
/// from the Health & Body goal list below; still fully editable there too.
/// Carries its own icon + color so the chip row reads as colorful and
/// "alive" rather than a flat list of plain-text pills.
class HealthSuggestion {
  final String title;
  final IconData icon;
  final Color color;
  const HealthSuggestion(this.title, this.icon, this.color);
}

const kHealthBodySuggestions = [
  HealthSuggestion('Daily walking (heart)', Icons.directions_walk, Color(0xFFF08BA0)),
  HealthSuggestion('Quality sleep (brain)', Icons.psychology, Color(0xFFC79BF0)),
  HealthSuggestion('Deep breathing exercises (lungs)', Icons.air, Color(0xFF7FC8F8)),
  HealthSuggestion('Weight-bearing exercise (bones)', Icons.fitness_center, Color(0xFFFF9770)),
  HealthSuggestion('Drink water regularly (blood)', Icons.water_drop, Color(0xFF2E9BE6)),
  HealthSuggestion('Daily sunscreen (skin)', Icons.wb_sunny, Color(0xFFF2B93B)),
  HealthSuggestion('Quality sleep (immune system)', Icons.shield, Color(0xFF6FDCA8)),
  HealthSuggestion('Limit processed foods (liver)', Icons.no_food, Color(0xFFB07E10)),
  HealthSuggestion('Eat probiotics (gut)', Icons.eco, Color(0xFF23A870)),
  HealthSuggestion('Floss daily (teeth)', Icons.brush, Color(0xFFD9536F)),
  HealthSuggestion('Natural daylight exposure (eyes)', Icons.visibility, Color(0xFF2E9BE6)),
  HealthSuggestion('Regular hand-washing (hands)', Icons.clean_hands, Color(0xFF9B5DE5)),
  HealthSuggestion('Strength training twice a week (muscles)', Icons.sports_gymnastics, Color(0xFFB8481F)),
  HealthSuggestion('Meditation (nervous system)', Icons.self_improvement, Color(0xFF9B5DE5)),
  HealthSuggestion('Consistent sleep-wake cycle (hormones)', Icons.schedule, Color(0xFFE0A419)),
  HealthSuggestion('Learn something new (memory)', Icons.lightbulb, Color(0xFF17754D)),
];

class _HealthGoalsContent extends StatefulWidget {
  const _HealthGoalsContent();
  @override
  State<_HealthGoalsContent> createState() => _HealthGoalsContentState();
}

class _HealthGoalsContentState extends State<_HealthGoalsContent> {
  Future<void> _toggle(HealthSuggestion s) async {
    final goals = store.healthGoals;
    final index = goals.indexWhere((t) => t.title == s.title);
    if (index >= 0) {
      await store.removeHealthGoal(index);
    } else {
      await store.addHealthGoal(s.title);
      if (mounted) toastSaved(context);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final selectedTitles = store.healthGoals.map((t) => t.title).toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ItemHeader(icon: Icons.favorite_border, title: 'Health & body'),
        const SizedBox(height: 12),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ExerciseTimerScreen())),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Surfaces.accent(dark).withValues(alpha: 0.10),
              border: Border.all(color: Surfaces.accent(dark).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, size: 18, color: Surfaces.accent(dark)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Exercise interval bell — customize & start',
                      style: body(12.5, Surfaces.accent(dark), weight: FontWeight.w700)),
                ),
                Icon(Icons.chevron_right, size: 16, color: Surfaces.accent(dark)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PersonalCareScreen())),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Surfaces.accent(dark).withValues(alpha: 0.10),
              border: Border.all(color: Surfaces.accent(dark).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.spa_outlined, size: 18, color: Surfaces.accent(dark)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Personal Care — Skin Health',
                      style: body(12.5, Surfaces.accent(dark), weight: FontWeight.w700)),
                ),
                Icon(Icons.chevron_right, size: 16, color: Surfaces.accent(dark)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('TAP TO ADD · TAP AGAIN TO REMOVE', style: label(Surfaces.eyebrow(dark))),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final suggestion in kHealthBodySuggestions)
              _HealthChip(
                suggestion: suggestion,
                selected: selectedTitles.contains(suggestion.title),
                dark: dark,
                onTap: () => _toggle(suggestion),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Divider(height: 1, color: Surfaces.cardBorder(dark)),
        const SizedBox(height: 18),
        _GoalListContent(
          icon: Icons.checklist_outlined,
          title: 'Your health goals',
          hint: 'e.g. Drink 8 glasses of water',
          emptyText: 'Nothing set yet — tap a suggestion above or add your own.',
          goals: () => store.healthGoals,
          onAdd: store.addHealthGoal,
          onToggle: store.toggleHealthGoal,
          onRemove: store.removeHealthGoal,
        ),
      ],
    );
  }
}

/// A colorful, icon-led suggestion pill for the Health & Body section.
/// Selected state is unmissable — a solid color fill, a checkmark badge,
/// and a soft glow — so users can always tell at a glance what they've
/// already added, fixing the "did that actually save?" confusion.
class _HealthChip extends StatelessWidget {
  final HealthSuggestion suggestion;
  final bool selected;
  final bool dark;
  final VoidCallback onTap;

  const _HealthChip({
    required this.suggestion,
    required this.selected,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = suggestion.color;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.only(left: 10, right: 14, top: 7, bottom: 7),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: dark ? 0.30 : 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Surfaces.accentBorder(dark), width: selected ? 1.6 : 1),
          boxShadow: selected
              ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 10, spreadRadius: 0.5)]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? color : color.withValues(alpha: dark ? 0.22 : 0.16),
              ),
              child: Icon(
                selected ? Icons.check : suggestion.icon,
                size: 13,
                color: selected ? (dark ? Brand.deep : Colors.white) : color,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              suggestion.title,
              style: body(
                11.5,
                selected ? Surfaces.heading(dark) : Surfaces.muted(dark),
                weight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MindsetGoalsContent extends StatefulWidget {
  const _MindsetGoalsContent();
  @override
  State<_MindsetGoalsContent> createState() => _MindsetGoalsContentState();
}

class _MindsetGoalsContentState extends State<_MindsetGoalsContent> {
  final _negativeCtrl = TextEditingController();
  final _positiveCtrl = TextEditingController();

  @override
  void dispose() {
    _negativeCtrl.dispose();
    _positiveCtrl.dispose();
    super.dispose();
  }

  Future<void> _addReframe() async {
    await store.addCustomReframe(_negativeCtrl.text, _positiveCtrl.text);
    _negativeCtrl.clear();
    _positiveCtrl.clear();
    if (mounted) {
      FocusScope.of(context).unfocus();
      setState(() {});
      toastSaved(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ItemHeader(icon: Icons.psychology_outlined, title: 'Mindset & growth'),
        const SizedBox(height: 16),

        // ---- Thought reframe ----
        Text('CHANGE YOUR WORDS, CHANGE YOUR MINDSET',
            style: label(Surfaces.eyebrow(dark))),
        const SizedBox(height: 10),
        for (final pair in kReframePairs)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ReframeRow(negative: pair.$1, positive: pair.$2, dark: dark),
          ),
        for (var i = 0; i < store.customReframes.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: _ReframeRow(
                    negative: store.customReframes[i].negative,
                    positive: store.customReframes[i].positive,
                    dark: dark,
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    await store.removeCustomReframe(i);
                    setState(() {});
                  },
                  icon: Icon(Icons.close, size: 16, color: Surfaces.muted(dark)),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        TextField(
          controller: _negativeCtrl,
          textCapitalization: TextCapitalization.sentences,
          style: body(13, Surfaces.bodyText(dark), weight: FontWeight.w500),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'A thought you keep having…',
            hintStyle: body(12.5, Surfaces.muted(dark)),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _positiveCtrl,
                textCapitalization: TextCapitalization.sentences,
                style: body(13, Surfaces.bodyText(dark), weight: FontWeight.w500),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Reframe it as…',
                  hintStyle: body(12.5, Surfaces.muted(dark)),
                ),
              ),
            ),
            IconButton(
              onPressed: _addReframe,
              icon: Icon(Icons.add_circle, color: Surfaces.accent(dark), size: 28),
            ),
          ],
        ),

        const SizedBox(height: 18),
        Divider(height: 1, color: Surfaces.cardBorder(dark)),
        const SizedBox(height: 18),

        // ---- Stress bucket ----
        Text('STRESS BUCKET — TODAY', style: label(Surfaces.eyebrow(dark))),
        const SizedBox(height: 4),
        Text('What\'s filling it, and what\'s emptying it?',
            style: body(12, Surfaces.muted(dark))),
        const SizedBox(height: 10),
        Text('FILLS IT UP', style: body(11, Surfaces.muted(dark), weight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in kStressFillItems)
              _ToggleChip(
                label: item,
                selected: store.todaysStressFills.contains(item),
                dark: dark,
                onTap: () async {
                  await store.toggleStressFill(item);
                  setState(() {});
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text('EMPTIES IT', style: body(11, Surfaces.muted(dark), weight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in kStressEmptyItems)
              _ToggleChip(
                label: item,
                selected: store.todaysStressEmpties.contains(item),
                dark: dark,
                onTap: () async {
                  await store.toggleStressEmpty(item);
                  setState(() {});
                },
              ),
          ],
        ),

        const SizedBox(height: 18),
        Divider(height: 1, color: Surfaces.cardBorder(dark)),
        const SizedBox(height: 18),

        // ---- Daily DOSE ----
        Text('GET YOUR DAILY DOSE', style: label(Surfaces.eyebrow(dark))),
        const SizedBox(height: 10),
        for (final category in kDoseCategories)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${category.$1} · ${category.$2}',
                    style: body(12, Surfaces.accent(dark), weight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final activity in category.$3)
                      _ToggleChip(
                        label: activity,
                        selected: store.todaysDose.contains(activity),
                        dark: dark,
                        onTap: () async {
                          await store.toggleDoseActivity(activity);
                          setState(() {});
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),

        const SizedBox(height: 4),
        Divider(height: 1, color: Surfaces.cardBorder(dark)),
        const SizedBox(height: 18),

        _GoalListContent(
          icon: Icons.checklist_outlined,
          title: 'Other mindset goals',
          hint: 'e.g. Reframe one limiting belief',
          emptyText: 'Nothing set yet — add a mindset goal above.',
          goals: () => store.mindsetGoals,
          onAdd: store.addMindsetGoal,
          onToggle: store.toggleMindsetGoal,
          onRemove: store.removeMindsetGoal,
        ),
      ],
    );
  }
}

class _ReframeRow extends StatelessWidget {
  final String negative;
  final String positive;
  final bool dark;
  const _ReframeRow({required this.negative, required this.positive, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Surfaces.accent(dark).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Surfaces.accentBorder(dark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(negative,
              style: body(12, Surfaces.muted(dark), weight: FontWeight.w500)
                  .copyWith(decoration: TextDecoration.lineThrough)),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.arrow_forward, size: 13, color: Surfaces.accent(dark)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(positive,
                    style: body(13, Surfaces.accent(dark), weight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool dark;
  final VoidCallback onTap;
  const _ToggleChip(
      {required this.label, required this.selected, required this.dark, required this.onTap});

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

/// One "learn to connect better" tip — tapping a card turns it into a
/// concrete practice goal in the list below, the same "tap to add" pattern
/// as Health & Body, so the tips aren't just decorative reading material.
class ConnectionTip {
  final String title;
  final String blurb;
  final IconData icon;
  final Color color;
  const ConnectionTip(this.title, this.blurb, this.icon, this.color);
}

const kConnectionTips = [
  ConnectionTip('Listen actively', 'Put the phone down and really hear them out.',
      Icons.hearing, Color(0xFF7FC8F8)),
  ConnectionTip('Ask meaningful questions', 'Go past small talk — ask what they care about.',
      Icons.question_answer, Color(0xFFC79BF0)),
  ConnectionTip('Remember important details', "Note birthdays, big days, little things they've said.",
      Icons.bookmark, Color(0xFFF2B93B)),
  ConnectionTip('Show genuine interest', "Ask about their world, not just your own updates.",
      Icons.favorite, Color(0xFFF08BA0)),
  ConnectionTip('Maintain eye contact', 'A small habit that says "you have my full attention."',
      Icons.visibility, Color(0xFF2E9BE6)),
  ConnectionTip('Offer support when needed', "Show up for the hard days, not just the easy ones.",
      Icons.volunteer_activism, Color(0xFFFF9770)),
  ConnectionTip('Communicate openly', 'Say what you actually think and feel, kindly and clearly.',
      Icons.forum, Color(0xFF6FDCA8)),
  ConnectionTip('Express appreciation', "A genuine thank-you costs nothing and means a lot.",
      Icons.card_giftcard, Color(0xFFE0A419)),
  ConnectionTip('Be consistent and reliable', 'Follow through on the small things you say you will.',
      Icons.event_available, Color(0xFF23A870)),
  ConnectionTip("Respect each other's boundaries", 'Space and consent keep connection healthy.',
      Icons.shield_outlined, Color(0xFF9B5DE5)),
  ConnectionTip('Spend quality time together', 'Undistracted time together is the bond itself.',
      Icons.groups, Color(0xFFD9536F)),
  ConnectionTip('Resolve conflicts healthily', 'Focus on the problem, not on winning the argument.',
      Icons.handshake, Color(0xFFB8481F)),
];

class _RelationshipsGoalsContent extends StatefulWidget {
  const _RelationshipsGoalsContent();
  @override
  State<_RelationshipsGoalsContent> createState() => _RelationshipsGoalsContentState();
}

class _RelationshipsGoalsContentState extends State<_RelationshipsGoalsContent> {
  Future<void> _toggle(ConnectionTip tip) async {
    final goals = store.relationshipsGoals;
    final index = goals.indexWhere((t) => t.title == tip.title);
    if (index >= 0) {
      await store.removeRelationshipsGoal(index);
    } else {
      await store.addRelationshipsGoal(tip.title);
      if (mounted) toastSaved(context);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final selectedTitles = store.relationshipsGoals.map((t) => t.title).toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ItemHeader(icon: Icons.diversity_1_outlined, title: 'Relationships & connection'),
        const SizedBox(height: 14),
        Text('LEARN & PRACTICE — TAP TO ADD', style: label(Surfaces.eyebrow(dark))),
        const SizedBox(height: 10),
        SizedBox(
          height: 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kConnectionTips.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final tip = kConnectionTips[i];
              final selected = selectedTitles.contains(tip.title);
              return _ConnectionTipCard(
                tip: tip,
                selected: selected,
                dark: dark,
                onTap: () => _toggle(tip),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        Divider(height: 1, color: Surfaces.cardBorder(dark)),
        const SizedBox(height: 18),
        const _RelationshipContactsSection(),
        const SizedBox(height: 18),
        Divider(height: 1, color: Surfaces.cardBorder(dark)),
        const SizedBox(height: 18),
        _GoalListContent(
          icon: Icons.checklist_outlined,
          title: 'Your connection goals',
          hint: 'e.g. Call someone you miss',
          emptyText: 'Nothing set yet — tap a tip above or add your own.',
          goals: () => store.relationshipsGoals,
          onAdd: store.addRelationshipsGoal,
          onToggle: store.toggleRelationshipsGoal,
          onRemove: store.removeRelationshipsGoal,
        ),
      ],
    );
  }
}

/// "Who to reach out to" — pick people you're intentionally staying in
/// touch with, how often, and log when you last did. Whoever's overdue
/// surfaces with a clear "Reach out" badge, the way contact-care apps
/// nudge relationship maintenance instead of leaving it to memory.
class _RelationshipContactsSection extends StatefulWidget {
  const _RelationshipContactsSection();
  @override
  State<_RelationshipContactsSection> createState() => _RelationshipContactsSectionState();
}

class _RelationshipContactsSectionState extends State<_RelationshipContactsSection> {
  final _nameCtrl = TextEditingController();
  String _relation = 'friend';
  int _cadenceDays = 7;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    await store.addRelationshipContact(_nameCtrl.text,
        relation: _relation, cadenceDays: _cadenceDays);
    _nameCtrl.clear();
    if (mounted) {
      FocusScope.of(context).unfocus();
      setState(() {});
      toastSaved(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final contacts = store.relationshipContacts;
    final overdue = contacts.where((c) => c.isOverdue).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('WHO TO REACH OUT TO', style: label(Surfaces.eyebrow(dark))),
        const SizedBox(height: 4),
        Text(
          'Add the people you want to intentionally stay close to — you\'ll see who\'s overdue for a check-in.',
          style: body(11.5, Surfaces.muted(dark)),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                style: body(13.5, Surfaces.bodyText(dark), weight: FontWeight.w500),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Name — e.g. Mom, Priya',
                  hintStyle: body(12.5, Surfaces.muted(dark)),
                ),
                onSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _add,
              icon: Icon(Icons.add_circle, color: Surfaces.accent(dark)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final r in kRelationTypes)
              _MiniChip(
                label: kRelationTypeLabels[r] ?? r,
                selected: _relation == r,
                dark: dark,
                onTap: () => setState(() => _relation = r),
              ),
            const SizedBox(width: 6),
            for (final (label, days) in const [('Weekly', 7), ('Biweekly', 14), ('Monthly', 30)])
              _MiniChip(
                label: label,
                selected: _cadenceDays == days,
                dark: dark,
                onTap: () => setState(() => _cadenceDays = days),
              ),
          ],
        ),
        if (contacts.isNotEmpty) ...[
          const SizedBox(height: 14),
          if (overdue.isNotEmpty) ...[
            Text('REACH OUT SOON', style: label(Surfaces.eyebrow(dark))),
            const SizedBox(height: 8),
            for (final c in overdue)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ContactRow(contact: c, dark: dark, overdue: true, onChanged: () => setState(() {})),
              ),
            const SizedBox(height: 6),
          ],
          for (final c in contacts.where((c) => !c.isOverdue))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ContactRow(contact: c, dark: dark, overdue: false, onChanged: () => setState(() {})),
            ),
        ],
      ],
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool dark;
  final VoidCallback onTap;
  const _MiniChip({required this.label, required this.selected, required this.dark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Surfaces.accent(dark).withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Surfaces.accent(dark) : Surfaces.accentBorder(dark),
          ),
        ),
        child: Text(label,
            style: body(11, selected ? Surfaces.accent(dark) : Surfaces.muted(dark),
                weight: FontWeight.w600)),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final RelationshipContact contact;
  final bool dark;
  final bool overdue;
  final VoidCallback onChanged;
  const _ContactRow({
    required this.contact,
    required this.dark,
    required this.overdue,
    required this.onChanged,
  });

  String get _lastContactLabel {
    final last = contact.lastContactAt;
    if (last == null) return 'Never logged';
    final days = DateTime.now().difference(last).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    return '$days days ago';
  }

  @override
  Widget build(BuildContext context) {
    return ModuleCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: (overdue ? Colors.redAccent : Surfaces.accent(dark)).withValues(alpha: 0.16),
            child: Text(contact.name.isEmpty ? '?' : contact.name[0].toUpperCase(),
                style: body(13, overdue ? Colors.redAccent : Surfaces.accent(dark), weight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact.name, style: body(13.5, Surfaces.heading(dark), weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${kRelationTypeLabels[contact.relation] ?? contact.relation} · $_lastContactLabel',
                  style: body(11, Surfaces.muted(dark)),
                ),
              ],
            ),
          ),
          if (overdue)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Reach out',
                    style: body(10, Colors.redAccent, weight: FontWeight.w700)),
              ),
            ),
          IconButton(
            tooltip: 'Log contact today',
            onPressed: () async {
              await store.logContactNow(contact);
              onChanged();
            },
            icon: Icon(Icons.check_circle_outline, size: 20, color: Surfaces.accent(dark)),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: () async {
              await store.removeRelationshipContact(contact);
              onChanged();
            },
            icon: Icon(Icons.close, size: 16, color: Surfaces.muted(dark)),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// A colorful, icon-led "learn to connect better" card. Selected state
/// (already added as a goal) gets a solid fill, glow and checkmark badge —
/// same visual language as the Health & Body chips, for consistency.
class _ConnectionTipCard extends StatelessWidget {
  final ConnectionTip tip;
  final bool selected;
  final bool dark;
  final VoidCallback onTap;

  const _ConnectionTipCard({
    required this.tip,
    required this.selected,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = tip.color;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 160,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: dark ? 0.28 : 0.14) : Surfaces.card(dark),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? color : Surfaces.cardBorder(dark), width: selected ? 1.6 : 1),
          boxShadow: selected
              ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 10, spreadRadius: 0.5)]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? color : color.withValues(alpha: dark ? 0.22 : 0.16),
                  ),
                  child: Icon(
                    selected ? Icons.check : tip.icon,
                    size: 15,
                    color: selected ? (dark ? Brand.deep : Colors.white) : color,
                  ),
                ),
                const Spacer(),
                if (selected)
                  Icon(Icons.push_pin, size: 13, color: color),
              ],
            ),
            const SizedBox(height: 8),
            Text(tip.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: body(12, Surfaces.heading(dark), weight: FontWeight.w700)),
            const SizedBox(height: 4),
            Expanded(
              child: Text(tip.blurb,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.justify,
                  style: body(10.5, Surfaces.muted(dark))),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderItem extends StatelessWidget {
  const _ReminderItem();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // 'spendAlerts' has no fixed fire time (it's a live threshold check, not
    // a scheduled reminder — see Notifications.scheduleAll) so its clockLabel
    // is a meaningless "12:00 AM"; leave it out of this summary.
    final on = store.reminders
        .where((ReminderSetting r) => r.enabled && r.id != 'spendAlerts')
        .toList();
    final summary = on.isEmpty
        ? 'Reminders are off'
        : on.length <= 2
            ? on.map((r) => r.clockLabel).join(' · ')
            : '${on.length} reminders on';

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const RemindersScreen())),
      child: _ItemHeader(
        icon: Icons.notifications_none,
        title: 'Daily reminders',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: body(12, Surfaces.muted(dark))),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, color: Surfaces.muted(dark), size: 18),
          ],
        ),
      ),
    );
  }
}

/// Morning check-in — a light mood pulse, not a journal. Shown at most once
/// a day, purely informational (feeds nothing else yet beyond the log).
class _MoodDialog extends StatelessWidget {
  const _MoodDialog();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: Surfaces.sheet(dark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How are you feeling this morning?',
                style: display(18, Surfaces.heading(dark))),
            const SizedBox(height: 6),
            Text('A quick pulse-check — takes one tap.',
                style: body(12.5, Surfaces.muted(dark))),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final (moodLabel, emoji) in _moods)
                  InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: () async {
                      await store.setTodaysMood(moodLabel);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(emoji, style: const TextStyle(fontSize: 28)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () async {
                  await store.recordMoodPromptShown();
                  if (context.mounted) Navigator.pop(context);
                },
                child: Text('Skip for today',
                    style: body(12.5, Surfaces.muted(dark), weight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Evening pop-up — the same achievements + gratitude capture as the full
/// Evening reflection screen, surfaced proactively instead of waiting for
/// the user to remember to open it.
class _EveningPromptDialog extends StatefulWidget {
  const _EveningPromptDialog();

  @override
  State<_EveningPromptDialog> createState() => _EveningPromptDialogState();
}

class _EveningPromptDialogState extends State<_EveningPromptDialog> {
  late final List<TextEditingController> _achievements;
  late final TextEditingController _gratitude;

  @override
  void initState() {
    super.initState();
    final entry = store.todaysJournal;
    _achievements = List.generate(
        3, (i) => TextEditingController(text: i < entry.achievements.length ? entry.achievements[i] : ''));
    _gratitude = TextEditingController(text: entry.gratitude);
  }

  @override
  void dispose() {
    for (final c in _achievements) {
      c.dispose();
    }
    _gratitude.dispose();
    super.dispose();
  }

  Future<void> _saveAndClose() async {
    await store.saveTodaysJournal(
        _achievements.map((c) => c.text).toList(), _gratitude.text);
    await store.recordEveningPromptShown();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _dismiss() async {
    await store.recordEveningPromptShown();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: Surfaces.sheet(dark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Close the day', style: display(18, Surfaces.heading(dark))),
              const SizedBox(height: 4),
              Text('Two minutes — what counted today?',
                  style: body(12.5, Surfaces.muted(dark))),
              const SizedBox(height: 16),
              Text('THREE THINGS I ACHIEVED', style: label(Surfaces.eyebrow(dark))),
              const SizedBox(height: 8),
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: TextField(
                    controller: _achievements[i],
                    textCapitalization: TextCapitalization.sentences,
                    style: body(13.5, Surfaces.bodyText(dark)),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixText: '${i + 1}.  ',
                      hintText: 'Something that counted',
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Text('GRATEFUL FOR', style: label(Surfaces.eyebrow(dark))),
              const SizedBox(height: 8),
              TextField(
                controller: _gratitude,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                style: body(13.5, Surfaces.bodyText(dark)),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'What are you grateful for today?',
                ),
              ),
              const SizedBox(height: 18),
              GoldButton(labelText: 'Save', onPressed: _saveAndClose),
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  onPressed: _dismiss,
                  child: Text('Not now',
                      style: body(12.5, Surfaces.muted(dark), weight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Brand footer (website/Instagram/YouTube links) moved to its own
// About Us screen (about_screen.dart) — reachable from the Dashboard —
// instead of repeating on every section.
