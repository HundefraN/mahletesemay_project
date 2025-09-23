import 'dart:ui';
import 'package:flutter/material.dart';

class SearchableDropdown<T> extends StatefulWidget {
  final String label;
  final IconData? icon;
  final T? selectedItem;
  final Function(T?) onChanged;
  final String? Function(T?)? validator;
  final Future<List<T>> Function(String)? onFind;
  final Future<Map<String, List<T>>> Function(String)? onFindWithHeaders;
  final Widget Function(T) dropdownBuilder;
  final Widget Function(T) itemBuilder;
  final String Function(T) itemToString;
  final bool isEnabled;

  const SearchableDropdown({
    super.key,
    required this.label,
    this.icon,
    this.selectedItem,
    required this.onChanged,
    this.validator,
    this.onFind,
    this.onFindWithHeaders,
    required this.dropdownBuilder,
    required this.itemBuilder,
    required this.itemToString,
    this.isEnabled = true,
  }) : assert(onFind != null || onFindWithHeaders != null, 'Either onFind or onFindWithHeaders must be provided.');

  @override
  State<SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T> extends State<SearchableDropdown<T>> {
  final TextEditingController _textEditingController = TextEditingController();

  void _showSearchBottomSheet() async {
    final result = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _SearchBottomSheet<T>(
          title: widget.label,
          onFind: widget.onFind,
          onFindWithHeaders: widget.onFindWithHeaders,
          itemBuilder: widget.itemBuilder,
        );
      },
    );
    if (result != null) {
      widget.onChanged(result);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateText();
    });
  }

  @override
  void didUpdateWidget(covariant SearchableDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedItem != oldWidget.selectedItem) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _updateText();
      });
    }
  }

  void _updateText() {
    if (widget.selectedItem != null) {
      _textEditingController.text = widget.itemToString(widget.selectedItem as T);
    } else {
      _textEditingController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: !widget.isEnabled,
      child: Opacity(
        opacity: widget.isEnabled ? 1.0 : 0.5,
        child: TextFormField(
          controller: _textEditingController,
          readOnly: true,
          onTap: _showSearchBottomSheet,
          validator: (_) => widget.validator?.call(widget.selectedItem),
          decoration: InputDecoration(
            labelText: widget.label,
            border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            prefixIcon: widget.icon != null ? Icon(widget.icon) : null,
            suffixIcon: const Icon(Icons.arrow_drop_down),
          ),
        ),
      ),
    );
  }
}

class _SearchBottomSheet<T> extends StatefulWidget {
  final String title;
  final Future<List<T>> Function(String)? onFind;
  final Future<Map<String, List<T>>> Function(String)? onFindWithHeaders;
  final Widget Function(T) itemBuilder;

  const _SearchBottomSheet({
    required this.title,
    this.onFind,
    this.onFindWithHeaders,
    required this.itemBuilder,
  });

  @override
  State<_SearchBottomSheet<T>> createState() => _SearchBottomSheetState<T>();
}

class _SearchBottomSheetState<T> extends State<_SearchBottomSheet<T>> {
  List<T> _items = [];
  Map<String, List<T>> _categorizedItems = {};
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search('');
    _searchController.addListener(() => _search(_searchController.text));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search(String filter) async {
    if(!mounted) return;
    setState(() => _isLoading = true);
    if (widget.onFindWithHeaders != null) {
      _categorizedItems = await widget.onFindWithHeaders!(filter);
      _items = _categorizedItems.values.expand((list) => list).toList();
    } else {
      _items = await widget.onFind!(filter);
      _categorizedItems = {};
    }
    if(!mounted) return;
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Container(
        margin: const EdgeInsets.all(16).copyWith(top: MediaQuery.of(context).padding.top + 32),
        decoration: BoxDecoration(
          color: isDark ? theme.cardColor.withOpacity(0.9) : theme.cardColor.withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(child: Text(widget.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                    hintText: 'Search...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: theme.scaffoldBackgroundColor.withOpacity(0.5)
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                  ? const Center(child: Text('No items found'))
                  : _buildList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (widget.onFindWithHeaders != null && _categorizedItems.isNotEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: _categorizedItems.entries.expand((entry) {
          final header = Padding(
            padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
            child: Text(
              entry.key,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
            ),
          );
          final items = entry.value.map((item) => Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.pop(context, item),
              borderRadius: BorderRadius.circular(8),
              child: widget.itemBuilder(item),
            ),
          ));
          return [header, ...items];
        }).toList(),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.pop(context, _items[index]),
            borderRadius: BorderRadius.circular(8),
            child: widget.itemBuilder(_items[index]),
          ),
        );
      },
    );
  }
}