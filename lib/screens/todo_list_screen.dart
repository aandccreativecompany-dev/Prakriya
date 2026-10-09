import 'package:flutter/material.dart';

import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Today's to-do list — unlimited items (no more 3-item cap), with an
/// explicit Save button alongside the auto-save every add/toggle already
/// does, and newly-added items appear on top as a card.
class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (_controller.text.trim().isEmpty) return;
    await store.addTask(_controller.text);
    _controller.clear();
    if (mounted) {
      FocusScope.of(context).unfocus();
      toastSaved(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final tasks = store.todaysTasks;
        return Scaffold(
          body: Container(
            decoration: Surfaces.pageBackground(dark),
            child: SafeArea(
              child: FadeSlideIn(
                child: Column(
                  children: [
                    ScreenHeader(
                      icon: Icons.edit_note_rounded,
                      title: "Today's to-do list",
                      subtitle: 'Add as many as you need — nothing here is capped.',
                      actions: [
                        IconButton(
                          onPressed: () => toastSaved(context, label: 'All saved'),
                          icon: Icon(Icons.save_outlined, color: Surfaces.accent(dark)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              onSubmitted: (_) => _add(),
                              textCapitalization: TextCapitalization.sentences,
                              style: body(14.5, Surfaces.bodyText(dark),
                                  weight: FontWeight.w500),
                              decoration: InputDecoration(
                                hintText: 'Add a to-do',
                                hintStyle: body(14, Surfaces.muted(dark)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _add,
                            icon: Icon(Icons.add_circle,
                                color: Surfaces.accent(dark), size: 30),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: tasks.isEmpty
                          ? ListView(
                              padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
                              children: [
                                Icon(Icons.wb_twilight_rounded,
                                    size: 44, color: Surfaces.accent(dark)),
                                const SizedBox(height: 12),
                                Text('A clear page. What would make today a win?',
                                    textAlign: TextAlign.center,
                                    style: body(15, Surfaces.heading(dark),
                                        weight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                Text('Type above, or tap a starter to add it in one go.',
                                    textAlign: TextAlign.center,
                                    style: body(12.5, Surfaces.muted(dark))),
                                const SizedBox(height: 16),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    for (final starter in const [
                                      'Plan my top 3',
                                      'Move for 20 minutes',
                                      'Drink 8 glasses of water',
                                      'Reach out to someone',
                                    ])
                                      ActionChip(
                                        label: Text(starter),
                                        onPressed: () => store.addTask(starter),
                                      ),
                                  ],
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                              itemCount: tasks.length,
                              itemBuilder: (context, i) {
                                return TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: 1),
                                  duration: Duration(milliseconds: 220 + i * 40),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, t, child) => Transform.translate(
                                    offset: Offset(0, (1 - t.clamp(0, 1)) * 10),
                                    child: Opacity(opacity: t.clamp(0, 1), child: child),
                                  ),
                                  child: Dismissible(
                                    key: ObjectKey(tasks[i]),
                                    background: Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.only(left: 20),
                                      alignment: Alignment.centerLeft,
                                      decoration: BoxDecoration(
                                        color: Colors.green.withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Icon(Icons.check_rounded),
                                    ),
                                    secondaryBackground: Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.only(right: 20),
                                      alignment: Alignment.centerRight,
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent.withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Icon(Icons.delete_outline),
                                    ),
                                    confirmDismiss: (direction) async {
                                      if (direction == DismissDirection.startToEnd) {
                                        await store.toggleTask(i);
                                        return false;
                                      }
                                      return true;
                                    },
                                    onDismissed: (_) => store.removeTask(i),
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: ModuleCard(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      child: Row(
                                        children: [
                                          CheckSquare(
                                            checked: tasks[i].done,
                                            onTap: () async {
                                              await store.toggleTask(i);
                                              if (context.mounted) toastSaved(context);
                                            },
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Text(
                                              tasks[i].title,
                                              style: body(
                                                14.5,
                                                tasks[i].done
                                                    ? Surfaces.muted(dark)
                                                    : Surfaces.bodyText(dark),
                                                weight: FontWeight.w500,
                                              ).copyWith(
                                                decoration: tasks[i].done
                                                    ? TextDecoration.lineThrough
                                                    : TextDecoration.none,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () async {
                                              await store.removeTask(i);
                                              if (context.mounted) {
                                                toastSaved(context, label: 'Removed');
                                              }
                                            },
                                            icon: Icon(Icons.close,
                                                size: 16, color: Surfaces.muted(dark)),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  ),
                                );
                              },
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
}
