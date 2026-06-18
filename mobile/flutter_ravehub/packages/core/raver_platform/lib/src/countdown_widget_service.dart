import 'package:home_widget/home_widget.dart';

/// Selected event payload consumed by the native countdown widget.
class CountdownWidgetEvent {
  /// Creates a selected countdown widget event.
  const CountdownWidgetEvent({
    required this.id,
    required this.name,
    required this.startDateIso,
    this.venueName = '',
  });

  /// Event id used for widget deep links.
  final String id;

  /// Event display name.
  final String name;

  /// Event start date in ISO-8601 format.
  final String startDateIso;

  /// Optional venue/location label.
  final String venueName;
}

/// Writes selected event data to native home-screen countdown widgets.
class CountdownWidgetService {
  CountdownWidgetService._();

  /// App group used by the iOS WidgetKit extension.
  static const appGroupId = 'group.com.ravehub.app';

  /// WidgetKit kind configured in `RaverCountdownWidgets.swift`.
  static const iosWidgetName = 'RaverCountdownWidget';

  /// Android AppWidgetProvider class name.
  static const androidWidgetName = 'RaverCountdownWidget';

  /// Fully qualified Android AppWidgetProvider class name.
  static const qualifiedAndroidWidgetName =
      'com.ravehub.app.RaverCountdownWidget';

  static const _eventIdKey = 'upcoming_event_id';
  static const _eventNameKey = 'upcoming_event_name';
  static const _eventDateKey = 'upcoming_event_date';
  static const _eventVenueKey = 'upcoming_event_venue';

  /// Saves [event] as the selected countdown event and refreshes widgets.
  static Future<void> saveSelectedEvent(CountdownWidgetEvent event) async {
    await HomeWidget.setAppGroupId(appGroupId);
    await Future.wait([
      HomeWidget.saveWidgetData<String>(_eventIdKey, event.id),
      HomeWidget.saveWidgetData<String>(_eventNameKey, event.name),
      HomeWidget.saveWidgetData<String>(_eventDateKey, event.startDateIso),
      HomeWidget.saveWidgetData<String>(_eventVenueKey, event.venueName),
    ]);
    await _updateWidgets();
  }

  /// Clears the selected countdown event and refreshes widgets.
  static Future<void> clearSelectedEvent() async {
    await HomeWidget.setAppGroupId(appGroupId);
    await Future.wait([
      HomeWidget.saveWidgetData<String>(_eventIdKey, null),
      HomeWidget.saveWidgetData<String>(_eventNameKey, null),
      HomeWidget.saveWidgetData<String>(_eventDateKey, null),
      HomeWidget.saveWidgetData<String>(_eventVenueKey, null),
    ]);
    await _updateWidgets();
  }

  static Future<void> _updateWidgets() {
    return HomeWidget.updateWidget(
      iOSName: iosWidgetName,
      androidName: androidWidgetName,
      qualifiedAndroidName: qualifiedAndroidWidgetName,
    );
  }
}
