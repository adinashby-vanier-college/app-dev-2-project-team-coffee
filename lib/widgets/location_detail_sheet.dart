import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/location_details.dart';
import '../providers/saved_locations_provider.dart';
import 'send_scene_sheet.dart';

class LocationDetailSheet extends StatefulWidget {
  final LocationDetails location;

  const LocationDetailSheet({
    super.key,
    required this.location,
  });

  @override
  State<LocationDetailSheet> createState() => _LocationDetailSheetState();
}

class _LocationDetailSheetState extends State<LocationDetailSheet> {
  bool _isHoursExpanded = false;

  Future<void> _toggleSave() async {
    final provider = context.read<SavedLocationsProvider>();
    try {
      if (provider.isSaved(widget.location.id)) {
        await provider.unsaveLocation(widget.location.id);
      } else {
        await provider.saveLocation(widget.location.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating saved state: $e')),
        );
      }
    }
  }

  Future<void> _openAddress() async {
    final address = widget.location.address;
    if (address.isEmpty) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }


  Widget _buildSaveButton(LocationDetails loc) {
    final provider = context.watch<SavedLocationsProvider>();
    final isSaved = provider.isSaved(loc.id);
    final borderColor =
        isSaved ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0);
    final bgColor =
        isSaved ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC);
    final textColor =
        isSaved ? const Color(0xFF15803D) : const Color(0xFF475569);

    return InkWell(
      onTap: _toggleSave,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              isSaved ? Icons.bookmark : Icons.bookmark_border,
              size: 20,
              color: borderColor,
            ),
            const SizedBox(height: 4),
            Text(
              'Save',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendSceneButton() {
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => SendSceneSheet(
            locationId: widget.location.id,
          ),
        );
      },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: const [
            Icon(
              Icons.share,
              size: 20,
              color: Color(0xFF475569),
            ),
            SizedBox(height: 4),
            Text(
              'Send Scene™',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = widget.location;

    return SafeArea(
      top: true,
      bottom: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: 0.7,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 20,
                  offset: Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                loc.name,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              loc.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(
                                5,
                                (i) => Icon(
                                  Icons.star,
                                  size: 14,
                                  color: i < loc.rating.round()
                                      ? Colors.amber
                                      : Colors.grey.shade300,
                                ),
                              ),
                            ),
                            Text(
                              '(${loc.reviews} reviews)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              '• ${loc.category}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            if (loc.price != null &&
                                loc.price!.isNotEmpty)
                              Text(
                                loc.price!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          loc.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildSaveButton(loc)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildSendSceneButton()),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading:
                              const Icon(Icons.place, color: Colors.blue),
                          title: Text(
                            loc.address,
                            style: const TextStyle(fontSize: 14),
                          ),
                          onTap: _openAddress,
                        ),
                        if (loc.phone != null && loc.phone!.isNotEmpty)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading:
                                const Icon(Icons.phone, color: Colors.blue),
                            title: Text(
                              loc.phone!,
                              style: const TextStyle(fontSize: 14),
                            ),
                            onTap: () async {
                              final uri =
                                  Uri(scheme: 'tel', path: loc.phone);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              }
                            },
                          ),
                        if (loc.website != null && loc.website!.isNotEmpty)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.language,
                                color: Colors.blue),
                            title: Text(
                              loc.website!,
                              style: const TextStyle(
                                fontSize: 14,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            onTap: () async {
                              final uri = Uri.parse(loc.website!);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri,
                                    mode: LaunchMode.externalApplication);
                              }
                            },
                          ),
                        if (loc.hours.isNotEmpty) ...[
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.access_time,
                                color: Colors.blue),
                            title: Row(
                              children: [
                                Text(
                                  loc.openStatus ?? 'Hours',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: (loc.openStatus ?? '')
                                            .toLowerCase()
                                            .contains('open')
                                        ? Colors.green
                                        : Colors.orange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (loc.closeTime != null &&
                                    loc.closeTime!.isNotEmpty) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    '· Closes ${loc.closeTime}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                _isHoursExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isHoursExpanded = !_isHoursExpanded;
                                });
                              },
                            ),
                          ),
                          if (_isHoursExpanded)
                            Padding(
                              padding: const EdgeInsets.only(left: 40),
                              child: Column(
                                children: loc.hours
                                    .map(
                                      (h) => Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            h.day,
                                            style: const TextStyle(
                                                fontSize: 13),
                                          ),
                                          Text(
                                            h.time,
                                            style: const TextStyle(
                                                fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                        ],
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
