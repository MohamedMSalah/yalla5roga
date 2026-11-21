import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:yalla_5roga/core/maps/location_repository.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_alert.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/discover/domain/repositories/discover_repository.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_map_provider.dart';

class PrivatePlaceSheet extends StatefulWidget {
  const PrivatePlaceSheet({
    super.key,
    required this.owner,
    required this.point,
    required this.catalog,
    this.existing,
  });
  final String owner;
  final LatLng point;
  final DiscoverMapProvider catalog;
  final SuggestedPlace? existing;
  @override
  State<PrivatePlaceSheet> createState() => _PrivatePlaceSheetState();
}

class _PrivatePlaceSheetState extends State<PrivatePlaceSheet> {
  late final name = TextEditingController(text: widget.existing?.name);
  late String category = widget.existing?.categoryId ?? '';
  late final id = widget.existing?.id ?? _id();
  bool busy = false, failed = false, resolving = false;
  late String address = widget.existing?.address ?? '';
  Completer<void>? _lookup;

  Future<void> resolveAddress() async {
    if (resolving) return;
    final geocoding = context.read<LocationRepository?>();
    if (geocoding == null) return;
    final request = _lookup = Completer<void>();
    setState(() => resolving = true);
    try {
      final result = await geocoding.reverseGeocode(
        latitude: widget.point.latitude,
        longitude: widget.point.longitude,
        language: context.l10n.locale.languageCode,
        cancelled: request.future,
      );
      if (!mounted || context.read<AuthProvider>().user?.id != widget.owner) {
        return;
      }
      final hit = result.hits.firstOrNull;
      if (hit != null) {
        address = [hit.name, hit.area]
            .where((s) => s.isNotEmpty)
            .toSet()
            .join(', ')
            .characters
            .take(500)
            .join();
      }
    } catch (_) {
      // Coordinates remain selectable without geocoding.
    } finally {
      if (mounted) setState(() => resolving = false);
    }
  }

  String _id() {
    final rng = Random.secure();
    final bytes = List.generate(16, (_) => rng.nextInt(256));
    bytes[6] = bytes[6] & 15 | 64;
    bytes[8] = bytes[8] & 63 | 128;
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'private:${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  SuggestedPlace get place => SuggestedPlace(
    id: id,
    name: name.text.trim(),
    area: widget.existing?.area ?? '',
    address: address,
    categoryId: category,
    source: 'private',
    vibe: OutingVibe.food,
    coverImageUrl: '',
    latitude: widget.point.latitude,
    longitude: widget.point.longitude,
  );
  Future<void> persist({bool remove = false}) async {
    if (busy || context.read<AuthProvider>().user?.id != widget.owner) return;
    setState(() => busy = true);
    if (remove) {
      final l = context.l10n;
      final confirmed = await AppAlert.confirm(
        title: l.removePrivatePlace,
        message: l.deviceLocalPlace,
        confirmText: l.removePrivatePlace,
        cancelText: l.cancel,
        destructive: true,
      );
      if (!mounted || context.read<AuthProvider>().user?.id != widget.owner) {
        return;
      }
      if (!confirmed) {
        setState(() => busy = false);
        return;
      }
    }
    try {
      final repo = widget.catalog.repository as ViewportCatalog;
      if (remove) {
        await repo.deletePrivate(widget.owner, id);
      } else {
        await repo.savePrivate(widget.owner, place);
      }
      if (!mounted || context.read<AuthProvider>().user?.id != widget.owner) {
        return;
      }
      widget.catalog.load(force: true);
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          failed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _lookup?.complete();
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (context.select((AuthProvider p) => p.user?.id) != widget.owner) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          Navigator.pop(context);
        }
      });
      return const SizedBox.shrink();
    }
    final l = context.l10n;
    final valid = name.text.trim().isNotEmpty && name.text.trim().length <= 100;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.customPlace, style: Theme.of(context).textTheme.titleLarge),
            Text(
              '${widget.point.latitude.toStringAsFixed(5)}, ${widget.point.longitude.toStringAsFixed(5)}',
            ),
            if (address.isNotEmpty) Text(address),
            if (address.isEmpty && context.read<LocationRepository?>() != null)
              TextButton(
                onPressed: resolving || busy ? null : resolveAddress,
                child: Text(
                  resolving ? l.lookingUpLocation : l.findPlaceAddress,
                ),
              ),
            TextField(
              controller: name,
              enabled: !busy,
              maxLength: 100,
              decoration: InputDecoration(labelText: l.customPlace),
              onChanged: (_) => setState(() {}),
            ),
            DropdownButton<String>(
              value: category,
              isExpanded: true,
              items: [
                DropdownMenuItem(value: '', child: Text(l.customPlace)),
                if (category.isNotEmpty &&
                    !widget.catalog.categories.any((c) => c.id == category))
                  DropdownMenuItem(value: category, child: Text(category)),
                for (final c in widget.catalog.categories)
                  DropdownMenuItem(
                    value: c.id,
                    child: Text(c.label(l.locale.languageCode)),
                  ),
              ],
              onChanged: busy
                  ? null
                  : (v) => setState(() => category = v ?? ''),
            ),
            Text(l.deviceLocalPlace),
            if (failed) Text(l.savedPlaceFailed),
            FilledButton(
              onPressed: valid && !busy ? persist : null,
              child: Text(l.savePlace),
            ),
            TextButton(
              onPressed: valid && !busy
                  ? () => Navigator.pop(context, place)
                  : null,
              child: Text(l.selectMapLocation),
            ),
            if (widget.existing != null)
              TextButton(
                onPressed: busy ? null : () => persist(remove: true),
                child: Text(l.removePrivatePlace),
              ),
          ],
        ),
      ),
    );
  }
}
