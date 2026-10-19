import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/time_utils.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/glass_widgets.dart';
import '../../data/models/task_item.dart';
import '../../state/app_state.dart';

/// Reads events from the phone's calendars (this includes Google Calendar
/// when your Google account is synced) and turns picked ones into reminders.
class CalendarImportScreen extends StatefulWidget {
  const CalendarImportScreen({super.key});

  @override
  State<CalendarImportScreen> createState() => _CalendarImportScreenState();
}

class _CalendarImportScreenState extends State<CalendarImportScreen> {
  final DeviceCalendarPlugin _plugin = DeviceCalendarPlugin();
  List<Calendar> _cals = [];
  Calendar? _sel;
  List<Event> _events = [];
  final Set<String> _picked = {};
  String? _msg;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  String _id(Event e) =>
      e.eventId ?? '${e.title}-${e.start?.millisecondsSinceEpoch}';

  DateTime _start(Event e) =>
      DateTime.fromMillisecondsSinceEpoch(e.start!.millisecondsSinceEpoch);

  Future<void> _init() async {
    try {
      var p = await _plugin.hasPermissions();
      if (p.data != true) p = await _plugin.requestPermissions();
      if (p.data != true) {
        if (mounted) {
          setState(() {
            _msg =
                'Calendar permission was denied. Allow it in phone settings.';
            _busy = false;
          });
        }
        return;
      }
      final r = await _plugin.retrieveCalendars();
      final list = (r.data ?? []).cast<Calendar>().toList();
      if (!mounted) return;
      setState(() {
        _cals = list;
        _busy = false;
        if (list.isEmpty) _msg = 'No calendars found on this phone.';
      });
      if (list.isNotEmpty) await _load(list.first);
    } catch (e) {
      if (mounted) {
        setState(() {
          _msg = 'Could not read calendar: $e';
          _busy = false;
        });
      }
    }
  }

  Future<void> _load(Calendar c) async {
    setState(() {
      _sel = c;
      _busy = true;
      _picked.clear();
    });
    try {
      final now = DateTime.now();
      final r = await _plugin.retrieveEvents(
        c.id,
        RetrieveEventsParams(
            startDate: now, endDate: now.add(const Duration(days: 21))),
      );
      final ev = (r.data ?? [])
          .cast<Event>()
          .where((e) =>
              e.start != null && e.title != null && _start(e).isAfter(now))
          .toList()
        ..sort((a, b) => _start(a).compareTo(_start(b)));
      if (mounted) {
        setState(() {
          _events = ev;
          _busy = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _msg = 'Could not load events: $e';
          _busy = false;
        });
      }
    }
  }

  Future<void> _import() async {
    final st = context.read<AppState>();
    var n = 0;
    for (final e in _events) {
      if (!_picked.contains(_id(e))) continue;
      final s = _start(e);
      final allDay = e.allDay == true;
      await st.saveTask(TaskItem(
        id: const Uuid().v4(),
        title: e.title ?? 'Event',
        notes: 'Imported from calendar',
        kind: TaskKind.meeting,
        repeat: TaskItem.fromJson({'repeat': 0}).repeat,
        startDate: dayOnly(s),
        times: [TaskTime('Event', allDay ? 9 : s.hour, allDay ? 0 : s.minute)],
        remindBefore: [60, 15],
        nagCount: 0,
      ));
      n++;
    }
    if (mounted) {
      toast(context, 'Added $n reminder${n == 1 ? '' : 's'}');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return PageShell(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          const SubHeader(title: 'Calendar import'),
          if (_msg != null)
            GlassContainer(
                padding: const EdgeInsets.all(18),
                child: Text(_msg!, style: TextStyle(color: g.text))),
          if (_cals.isNotEmpty) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final c in _cals) ...[
                  GlassChip(
                      label: c.name ?? 'Calendar',
                      selected: _sel?.id == c.id,
                      onTap: () => _load(c)),
                  const SizedBox(width: 8),
                ],
              ]),
            ),
            const SizedBox(height: 16),
          ],
          if (_busy)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator())),
          if (!_busy && _events.isEmpty && _msg == null && _sel != null)
            GlassContainer(
              padding: const EdgeInsets.all(18),
              child: Text('No upcoming events in the next 3 weeks.',
                  style: TextStyle(color: g.subText)),
            ),
          for (final e in _events)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassContainer(
                radius: 18,
                blur: 12,
                child: CheckboxListTile(
                  value: _picked.contains(_id(e)),
                  onChanged: (v) => setState(() =>
                      v == true ? _picked.add(_id(e)) : _picked.remove(_id(e))),
                  title: Text(e.title ?? '',
                      style: TextStyle(
                          color: g.text, fontWeight: FontWeight.w700)),
                  subtitle: Text(fmtDateTime(_start(e)),
                      style: TextStyle(color: g.subText)),
                ),
              ),
            ),
          if (_picked.isNotEmpty) ...[
            const SizedBox(height: 8),
            GlassButton(
              label: 'Add ${_picked.length} as reminders',
              icon: Icons.check_rounded,
              filled: true,
              color: AppTheme.purple,
              onTap: _import,
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Gmail: direct inbox import needs a Google restricted-scope approval, so it is not included. '
            'Events Gmail adds to Google Calendar (flights, bookings) appear here automatically.',
            style: TextStyle(fontSize: 12, color: g.subText),
          ),
        ],
      ),
    );
  }
}
