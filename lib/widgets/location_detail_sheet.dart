import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

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
          barrierColor: Colors.black.withOpacity(0.4),
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
          heightFactor: 0.75,
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
                const SizedBox(height: 12),
                Container(
                  width: 48,
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
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
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            Material(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                onTap: () => Navigator.of(context).pop(),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.close,
                                    size: 20,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              loc.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFF1E293B),
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
                                      ? const Color(0xFFFBBF24)
                                      : const Color(0xFFE2E8F0),
                                  fill: i < loc.rating.round() ? 1.0 : 0.0,
                                ),
                              ),
                            ),
                            Text(
                              '(${loc.reviews} reviews)',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const Text(
                              '•',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                            Text(
                              loc.category,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            if (loc.price != null && loc.price!.isNotEmpty) ...[
                              const Text(
                                '•',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFCBD5E1),
                                ),
                              ),
                              Text(
                                loc.price!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          loc.description,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF475569),
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(child: _buildSaveButton(loc)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildSendSceneButton()),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Container(
                          height: 1,
                          color: const Color(0xFFF1F5F9),
                          margin: const EdgeInsets.only(bottom: 16),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.place,
                                  size: 20,
                                  color: Color(0xFF2563EB),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _openAddress,
                                      borderRadius: BorderRadius.circular(4),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        child: Text(
                                          loc.address,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF334155),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (loc.hours.isNotEmpty) ...[
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _isHoursExpanded = !_isHoursExpanded;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(4),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.access_time,
                                        size: 20,
                                        color: Color(0xFF2563EB),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Wrap(
                                                spacing: 8,
                                                crossAxisAlignment:
                                                    WrapCrossAlignment.center,
                                                children: [
                                                  Text(
                                                    loc.openStatus ??
                                                        'Hours not available',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: (loc.openStatus ??
                                                                  '')
                                                              .toLowerCase()
                                                              .contains('open')
                                                          ? const Color(
                                                              0xFF16A34A)
                                                          : (loc.openStatus ??
                                                                      '')
                                                                  .toLowerCase()
                                                                  .contains(
                                                                      'closed')
                                                              ? const Color(
                                                                  0xFFEF4444)
                                                              : const Color(
                                                                  0xFFF97316),
                                                    ),
                                                  ),
                                                  if (loc.closeTime != null &&
                                                      loc.closeTime!
                                                          .isNotEmpty)
                                                    Text(
                                                      '⋅ Closes ${loc.closeTime}',
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        color:
                                                            Color(0xFF64748B),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            Icon(
                                              _isHoursExpanded
                                                  ? Icons.keyboard_arrow_up
                                                  : Icons.keyboard_arrow_down,
                                              size: 16,
                                              color: const Color(0xFF94A3B8),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (_isHoursExpanded)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 32,
                                    top: 4,
                                    bottom: 4,
                                  ),
                                  child: Column(
                                    children: loc.hours.map((h) {
                                      final currentDay = DateFormat('EEEE').format(DateTime.now());
                                      final isToday = currentDay == h.day;
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 6,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            SizedBox(
                                              width: 112,
                                              child: Text(
                                                h.day,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: isToday
                                                      ? FontWeight.w600
                                                      : FontWeight.w400,
                                                  color: isToday
                                                      ? const Color(0xFF0F172A)
                                                      : const Color(0xFF475569),
                                                ),
                                              ),
                                            ),
                                            Text(
                                              h.time,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: isToday
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                                color: isToday
                                                    ? const Color(0xFF0F172A)
                                                    : const Color(0xFF475569),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              const SizedBox(height: 16),
                            ],
                            if (loc.website != null &&
                                loc.website!.isNotEmpty) ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.language,
                                    size: 20,
                                    color: Color(0xFF2563EB),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () async {
                                          final uri = Uri.parse(loc.website!);
                                          if (await canLaunchUrl(uri)) {
                                            await launchUrl(uri,
                                                mode: LaunchMode
                                                    .externalApplication);
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(4),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4,
                                          ),
                                          child: Text(
                                            loc.website!,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF334155),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (loc.phone != null && loc.phone!.isNotEmpty) ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.phone,
                                    size: 20,
                                    color: Color(0xFF2563EB),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () async {
                                          final uri =
                                              Uri(scheme: 'tel', path: loc.phone);
                                          if (await canLaunchUrl(uri)) {
                                            await launchUrl(uri);
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(4),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4,
                                          ),
                                          child: Text(
                                            loc.phone!,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF334155),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                          ],
                        ),
                        const SizedBox(height: 24),
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
