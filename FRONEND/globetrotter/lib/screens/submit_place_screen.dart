import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/constants.dart';
import '../providers/destination_provider.dart';
import '../providers/settings_provider.dart';
import '../services/location_service.dart';
import '../widgets/map3d_view.dart';

/// Permet à un utilisateur d'ajouter un nouveau lieu au catalogue, avec
/// une vraie photo prise depuis son téléphone/PC, une description, une
/// catégorie, et sa position choisie soit en tapant directement sur la
/// carte, soit via "utiliser ma position actuelle" (les deux méthodes
/// demandées : "either by their fix position or other way"). Le lieu
/// est visible par tout le monde dès l'envoi - pas de file de modération.
class SubmitPlaceScreen extends StatefulWidget {
  const SubmitPlaceScreen({super.key});

  @override
  State<SubmitPlaceScreen> createState() => _SubmitPlaceScreenState();
}

class _SubmitPlaceScreenState extends State<SubmitPlaceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _quartierController = TextEditingController();
  String _category = PlaceCategories.all.keys.first;
  LatLng? _pickedLocation;
  XFile? _photo;
  bool _submitting = false;
  bool _locating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _quartierController.dispose();
    super.dispose();
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    final pos = await LocationService.getCurrentPosition();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (pos != null) _pickedLocation = LatLng(pos.latitude, pos.longitude);
    });
    if (pos == null && mounted) {
      final s = context.read<SettingsProvider>().s;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.locationUnavailable)));
    }
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _photo = picked);
  }

  Future<void> _submit() async {
    final s = context.read<SettingsProvider>().s;
    if (!_formKey.currentState!.validate()) return;
    if (_pickedLocation == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.pickLocationFirst)));
      return;
    }
    if (_photo == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.pickPhotoFirst)));
      return;
    }

    setState(() => _submitting = true);
    try {
      final bytes = await _photo!.readAsBytes();
      final formData = FormData.fromMap({
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'category': _category,
        'quartier': _quartierController.text.trim(),
        'lat': _pickedLocation!.latitude,
        'lng': _pickedLocation!.longitude,
        'photo': MultipartFile.fromBytes(bytes, filename: _photo!.name),
      });
      await ApiClient.instance.dio.post('/destinations/submit', data: formData);

      if (!mounted) return;
      // Recharge la liste générale pour que le nouveau lieu apparaisse
      // immédiatement dans Explorer/la carte sans avoir à relancer l'app.
      await context.read<DestinationProvider>().search();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.placeSubmitted)));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ApiClient.errorMessage(e, s))));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>().s;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(s.submitPlaceTitle)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(s.submitPlaceIntro, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 20),

            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: s.placeName, border: const OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().length < 2) ? s.requiredField : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _descController,
              maxLines: 3,
              decoration: InputDecoration(labelText: s.placeDescription, border: const OutlineInputBorder()),
              validator: (v) =>
                  (v == null || v.trim().length < 10) ? s.descriptionTooShort : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _quartierController,
              decoration: InputDecoration(labelText: s.placeQuartier, border: const OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().length < 2) ? s.requiredField : null,
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: InputDecoration(labelText: s.placeCategory, border: const OutlineInputBorder()),
              items: PlaceCategories.all.keys
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Row(children: [
                          Icon(PlaceCategories.all[c], size: 18),
                          const SizedBox(width: 8),
                          Text(PlaceCategories.labels[c] ?? c),
                        ]),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 20),

            Text(s.placeLocation, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(s.placeLocationHint,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
            const SizedBox(height: 8),
            SizedBox(
              height: 240,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Map3DView(
                  initialTilt: false,
                  stops: _pickedLocation == null
                      ? []
                      : [
                          Map3DStop(
                            point: _pickedLocation!,
                            label: '📍',
                            color: theme.colorScheme.primary,
                          ),
                        ],
                  onMapTap: (point) => setState(() => _pickedLocation = point),
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _locating ? null : _useMyLocation,
              icon: _locating
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location, size: 18),
              label: Text(s.useMyLocation),
            ),
            const SizedBox(height: 24),

            Text(s.placePhoto, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickPhoto,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _photo == null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_a_photo_outlined, size: 32, color: theme.colorScheme.outline),
                            const SizedBox(height: 6),
                            Text(s.addPhoto),
                          ],
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: kIsWeb
                            ? Image.network(_photo!.path, fit: BoxFit.cover, width: double.infinity)
                            : Image.file(File(_photo!.path), fit: BoxFit.cover, width: double.infinity),
                      ),
              ),
            ),
            const SizedBox(height: 28),

            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_location_alt_outlined),
              label: Text(s.submitPlaceButton),
            ),
          ],
        ),
      ),
    );
  }
}
