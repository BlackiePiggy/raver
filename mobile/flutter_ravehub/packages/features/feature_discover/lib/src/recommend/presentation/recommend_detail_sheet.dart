import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

/// A modal bottom sheet that shows details for a recommended event.
///
/// Displayed when the user taps a recommended event card. This is a
/// static widget with no separate state management.
class RecommendDetailSheet extends StatelessWidget {
  /// Creates a [RecommendDetailSheet].
  const RecommendDetailSheet({super.key, required this.event});

  /// The event to display.
  final WebEvent event;

  /// Shows this sheet as a modal bottom sheet.
  static Future<void> show(BuildContext context, {required WebEvent event}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RecommendDetailSheet(event: event),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.card,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade500,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Cover image
              RemoteCoverImage(
                url: event.coverImageUrl,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      event.name,
                      style: RaverTypography.headline(
                        color: theme.primaryText,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Date row
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: theme.secondaryText,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          event.startDate,
                          style: RaverTypography.caption(
                            color: theme.secondaryText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Venue row
                    if (event.location != null)
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: theme.secondaryText,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              event.location!.name,
                              style: RaverTypography.caption(
                                color: theme.secondaryText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                    // Description
                    if (event.description.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        event.description,
                        style: RaverTypography.body(
                          color: theme.primaryText,
                        ),
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 24),

                    // View Details button
                    PrimaryButton(
                      label: lt('查看详情', 'View Details', '詳細を見る'),
                      isExpanded: true,
                      onPressed: () {
                        context.pop();
                        context.push('/events/${event.id}');
                      },
                    ),
                    const SizedBox(height: 8),

                    // Close button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => context.pop(),
                        child: Text(lt('关闭', 'Close', '閉じる')),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
