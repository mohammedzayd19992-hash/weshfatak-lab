import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../brand.dart';
import '../models.dart';

/// Opens the filters: the news tags. Returns the new filters.
Future<FeedFilters?> showFilterSheet(BuildContext context) =>
    showModalBottomSheet<FeedFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const FilterSheet(),
    );

class FilterSheet extends StatefulWidget {
  const FilterSheet({super.key});

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late final AppState _app = AppScope.read(context);
  late final Set<String> _categories = {..._app.filters.categories};

  void _reset() => setState(_categories.clear);

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Filters',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(onPressed: _reset, child: const Text('Reset')),
            ],
          ),
          const SizedBox(height: 14),
          const _Label('News tags'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in app.categories)
                FilterChip(
                  avatar: Icon(
                    categoryIcons[name] ?? Icons.tag,
                    size: 18,
                    color: _categories.contains(name)
                        ? Colors.white
                        : Brand.mint,
                  ),
                  label: Text(name),
                  selected: _categories.contains(name),
                  onSelected: (selected) {
                    HapticFeedback.selectionClick();
                    setState(
                      () => selected
                          ? _categories.add(name)
                          : _categories.remove(name),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(
              _app.filters.copyWith(categories: {..._categories}),
            ),
            child: const Text('Show results'),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: Brand.sand,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    ),
  );
}
