import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/mock/mock_paintings.dart';
import '../../../../core/models/painting.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/user_data_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../result/presentation/pages/result_page.dart';
import '../../../scan/presentation/pages/camera_page.dart';
import '../widgets/collection_grid_item.dart';

const _featured = [
  MockPaintings.monaLisa,
  MockPaintings.prodigalSon,
  MockPaintings.nightWatch,
];

enum _CollectionFilter { all, favorites, recent }

enum _SortOption { newest, oldest, titleAz, artistAz }

extension on _SortOption {
  String get label {
    switch (this) {
      case _SortOption.newest:
        return 'Newest first';
      case _SortOption.oldest:
        return 'Oldest first';
      case _SortOption.titleAz:
        return 'Title (A-Z)';
      case _SortOption.artistAz:
        return 'Artist (A-Z)';
    }
  }
}

class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  List<Painting> _items = [];
  String _query = '';
  _CollectionFilter _filter = _CollectionFilter.all;
  _SortOption _sort = _SortOption.newest;

  late final StreamSubscription<User?> _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = AuthService.authStateChanges.listen((_) => _load());
    _load();
  }

  Future<void> _load() async {
    final saved = await UserDataRepository.savedPaintings();
    if (!mounted) return;
    setState(() {
      _items = saved.reversed.toList();
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

  Future<void> _toggleFavorite(Painting painting) async {
    await UserDataRepository.toggleFavorite(painting);
    _load();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  String _emptyMessage() {
    if (_filter == _CollectionFilter.favorites) {
      return 'No favorites yet — tap the heart on a painting to save it here.';
    }
    if (_items.isEmpty) return 'No saved paintings';
    return 'No paintings found';
  }

  int Function(Painting, Painting) _comparator() {
    switch (_sort) {
      case _SortOption.newest:
        return (a, b) {
          final aTime = a.scannedAt;
          final bTime = b.scannedAt;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        };
      case _SortOption.oldest:
        return (a, b) {
          final aTime = a.scannedAt;
          final bTime = b.scannedAt;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return aTime.compareTo(bTime);
        };
      case _SortOption.titleAz:
        return (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase());
      case _SortOption.artistAz:
        return (a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
    }
  }

  Future<void> _showSortSheet() async {
    final chosen = await showModalBottomSheet<_SortOption>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Sort by', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            for (final option in _SortOption.values)
              ListTile(
                title: Text(option.label),
                trailing: option == _sort ? const Icon(Icons.check, color: AppColors.clay) : null,
                onTap: () => Navigator.of(sheetContext).pop(option),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (chosen != null && mounted) setState(() => _sort = chosen);
  }

  @override
  Widget build(BuildContext context) {
    var filtered = _items.where((p) {
      return p.title.toLowerCase().contains(_query.toLowerCase()) ||
          p.artist.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    if (_filter == _CollectionFilter.favorites) {
      filtered = filtered.where((p) => p.isFavorite).toList();
    }
    filtered.sort(_comparator());

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Collection',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 26, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => _query = v),
                        decoration: InputDecoration(
                          hintText: 'Search',
                          hintStyle: const TextStyle(color: AppColors.inkSoft),
                          prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.inkSoft),
                          filled: true,
                          fillColor: AppColors.surface,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: AppColors.divider),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: AppColors.divider),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: AppColors.clay),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: _showSortSheet,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 52,
                        decoration: BoxDecoration(color: AppColors.clay, borderRadius: BorderRadius.circular(14)),
                        child: const Icon(Icons.tune, size: 20, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _FilterTab(
                    label: 'All',
                    selected: _filter == _CollectionFilter.all,
                    onTap: () => setState(() => _filter = _CollectionFilter.all),
                  ),
                  const SizedBox(width: 26),
                  _FilterTab(
                    label: 'Favorites',
                    selected: _filter == _CollectionFilter.favorites,
                    onTap: () => setState(() => _filter = _CollectionFilter.favorites),
                  ),
                  const SizedBox(width: 26),
                  _FilterTab(
                    label: 'Recently added',
                    selected: _filter == _CollectionFilter.recent,
                    onTap: () => setState(() => _filter = _CollectionFilter.recent),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Saved artworks',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${filtered.length} artwork${filtered.length == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    _DiscoverCard(
                      onTap: () async {
                        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CameraPage()));
                        _load();
                      },
                    ),
                    const SizedBox(height: 20),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            _emptyMessage(),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.inkSoft),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: [
                          for (final painting in filtered) ...[
                            SizedBox(
                              height: 240,
                              width: double.infinity,
                              child: CollectionGridItem(
                                painting: painting,
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => ResultPage(painting: painting)),
                                  );
                                  _load();
                                },
                                onDelete: () => _delete(painting),
                                onToggleFavorite: () => _toggleFavorite(painting),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ],
                      ),
                    if (filtered.isEmpty) ...[
                      const SizedBox(height: 28),
                      Text('Explore Masterpieces', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 230,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _featured.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 14),
                          itemBuilder: (context, i) => _ExploreCard(
                            painting: _featured[i],
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => ResultPage(painting: _featured[i])),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.clay : AppColors.inkSoft,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                height: 2,
                color: selected ? AppColors.clay : Colors.transparent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoverCard extends StatelessWidget {
  const _DiscoverCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(color: AppColors.surfaceMuted, shape: BoxShape.circle),
              child: const Icon(Icons.auto_awesome, size: 18, color: AppColors.clay),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Discover another masterpiece',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Scan a painting to add it to your gallery.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward, size: 18, color: AppColors.inkSoft),
          ],
        ),
      ),
    );
  }
}

class _ExploreCard extends StatelessWidget {
  const _ExploreCard({required this.painting, required this.onTap});

  final Painting painting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 128,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(painting.assetImagePath!, width: 128, height: 128, fit: BoxFit.cover),
            ),
            const SizedBox(height: 8),
            Text(
              painting.title,
              maxLines: 2,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              painting.artist,
              maxLines: 2,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

