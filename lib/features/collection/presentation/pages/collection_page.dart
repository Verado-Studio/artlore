import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/models/painting.dart';
import '../../../../core/services/app_preferences.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/user_data_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../result/presentation/pages/result_page.dart';
import '../widgets/collection_grid_item.dart';

class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  List<Painting> _items = [];
  bool _isPro = false;
  final _searchFocusNode = FocusNode();
  String _query = '';

  late final StreamSubscription<User?> _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = AuthService.authStateChanges.listen((_) => _load());
    _load();
  }

  Future<void> _load() async {
    final saved = await UserDataRepository.savedPaintings();
    final isPro = await UserDataRepository.isPro();
    if (!mounted) return;
    setState(() {
      _items = saved.reversed.toList();
      _isPro = isPro;
    });
  }

  Future<void> _delete(Painting painting) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove from Collection?'),
        content: Text('"${painting.title}" will be removed from your collection.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;
    await UserDataRepository.deleteScan(painting);
    _load();
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _items.where((p) {
      return p.title.toLowerCase().contains(_query.toLowerCase()) ||
          p.artist.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My Collection',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 26, fontWeight: FontWeight.w700),
                  ),
                  InkWell(
                    onTap: () => _searchFocusNode.requestFocus(),
                    borderRadius: BorderRadius.circular(20),
                    child: const Icon(Icons.search, size: 24, color: AppColors.ink),
                  ),
                ],
              ),
              if (!_isPro) ...[
                const SizedBox(height: 4),
                Text(
                  'Free plan keeps your last ${AppPreferences.freeScanHistoryLimit} scans — go Pro for unlimited.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                focusNode: _searchFocusNode,
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Search by title or artist',
                  prefixIcon: Icon(Icons.search, size: 20),
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          _items.isEmpty ? 'No saved paintings yet — scan one to get started.' : 'No paintings found',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.inkSoft),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 20,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.78,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final painting = filtered[i];
                          return CollectionGridItem(
                            painting: painting,
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => ResultPage(painting: painting)),
                              );
                              _load();
                            },
                            onDelete: () => _delete(painting),
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
