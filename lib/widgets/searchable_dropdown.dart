import 'package:flutter/material.dart';
import 'package:mahlete_semay_project/widgets/cached_image.dart';

class SearchableDropdown<T> extends StatefulWidget {
  final String label;
  final IconData icon;
  final T? selectedItem;
  final Future<List<T>> Function(String filter) onFind;
  final Function(T?) onChanged;
  final String? Function(T?)? validator;
  final Widget Function(T) dropdownBuilder;
  final Widget Function(T) itemBuilder;
  final bool isEnabled;

  const SearchableDropdown({
    super.key,
    required this.label,
    required this.icon,
    this.selectedItem,
    required this.onFind,
    required this.onChanged,
    this.validator,
    required this.dropdownBuilder,
    required this.itemBuilder,
    this.isEnabled = true,
  });

  @override
  State<SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T> extends State<SearchableDropdown<T>> {
  void _showModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return _SearchableModal<T>(
              label: widget.label,
              onFind: widget.onFind,
              itemBuilder: widget.itemBuilder,
              onChanged: (item) {
                widget.onChanged(item);
                Navigator.pop(context);
              },
              scrollController: scrollController,
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FormField<T>(
      validator: widget.validator,
      initialValue: widget.selectedItem,
      builder: (FormFieldState<T> state) {
        return InkWell(
          onTap: widget.isEnabled ? _showModal : null,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: widget.label,
              border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              prefixIcon: Icon(widget.icon),
              errorText: state.errorText,
              enabled: widget.isEnabled,
            ),
            child: widget.selectedItem == null
                ? Text('Select an option', style: TextStyle(color: widget.isEnabled ? null : Colors.grey))
                : widget.dropdownBuilder(widget.selectedItem as T),
          ),
        );
      },
    );
  }
}

class _SearchableModal<T> extends StatefulWidget {
  final String label;
  final Future<List<T>> Function(String filter) onFind;
  final Widget Function(T) itemBuilder;
  final Function(T) onChanged;
  final ScrollController scrollController;

  const _SearchableModal({
    required this.label,
    required this.onFind,
    required this.itemBuilder,
    required this.onChanged,
    required this.scrollController,
  });

  @override
  State<_SearchableModal<T>> createState() => _SearchableModalState<T>();
}

class _SearchableModalState<T> extends State<_SearchableModal<T>> {
  List<T> _items = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchItems('');
    _searchController.addListener(() => _fetchItems(_searchController.text));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchItems(String filter) async {
    setState(() => _isLoading = true);
    final items = await widget.onFind(filter);
    if(mounted) {
      setState(() {
        _items = items;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text(widget.label, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
            controller: widget.scrollController,
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final item = _items[index];
              return InkWell(
                onTap: () => widget.onChanged(item),
                child: widget.itemBuilder(item),
              );
            },
          ),
        ),
      ],
    );
  }
}