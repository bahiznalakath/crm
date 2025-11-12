// lib/pages/search_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lead.dart';
import '../providers/providers.dart';
import '../widgets/lead_card.dart';
import '../repositories/lead_repository.dart';

final suggestionsProvider = StreamProvider.family<List<Lead>, String>((ref, query) {
  final repo = ref.read(leadRepositoryProvider);
  return repo.suggestionsStream(query, limit: 8);
});

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});
  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  final _debouncer = _Debouncer(milliseconds: 300);
  String _q = '';
  Lead? _selected;

  @override
  void dispose() {
    _controller.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suggestionsAsync = ref.watch(suggestionsProvider(_q));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              TextFormField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: 'Search by name / mobile / project',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (val) => _debouncer.run(() => setState(() => _q = val)),
              ),
              const SizedBox(height: 12),
              suggestionsAsync.when(
                data: (items) {
                  if (items.isEmpty) return const Text('No suggestions');
                  return Card(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 0),
                      itemBuilder: (context, i) {
                        final lead = items[i];
                        return ListTile(
                          title: Text(lead.leadName),
                          subtitle: Text('${lead.mobile} • ${lead.projectName}'),
                          trailing: Text(lead.status),
                          onTap: () => setState(() => _selected = lead),
                        );
                      },
                    ),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: CircularProgressIndicator(),
                ),
                error: (e, st) => Text('Error: $e'),
              ),
              const SizedBox(height: 12),
              if (_selected != null) LeadCard(lead: _selected!),
            ],
          ),
        ),
      ),
    );
  }
}

class _Debouncer {
  final int milliseconds;
  Timer? _timer;
  _Debouncer({required this.milliseconds});
  run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  dispose() => _timer?.cancel();
}
