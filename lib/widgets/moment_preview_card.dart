import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/moment_model.dart';

class MomentPreviewCard extends StatelessWidget {
  final String momentId;
  final MomentModel? moment;
  final VoidCallback onTap;

  const MomentPreviewCard({
    super.key,
    required this.momentId,
    this.moment,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayTitle = moment?.title ?? 'Moment';
    final dateStr = moment != null
        ? DateFormat('MMM d, yyyy').format(moment!.dateTime)
        : '';
    final timeStr = moment != null
        ? DateFormat('h:mm a').format(moment!.dateTime)
        : '';
    final locationName = moment?.locationName ?? '';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.event,
                size: 20,
                color: Colors.purple,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (dateStr.isNotEmpty || locationName.isNotEmpty)
                    Text(
                      dateStr.isNotEmpty && locationName.isNotEmpty
                          ? '$dateStr • $locationName'
                          : dateStr.isNotEmpty
                              ? dateStr
                              : locationName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
