import '../core/utils/time_utils.dart';
import '../data/models/task_item.dart';

class StreakInfo {
  final int current;
  final int best;
  const StreakInfo(this.current, this.best);
}

/// Streak = consecutive scheduled days where every time-slot was marked done.
/// - Today still pending never breaks the streak.
/// - A "frozen" day (protected by a streak freeze) neither breaks nor adds.
StreakInfo computeStreak(
  TaskItem t,
  Map<String, Completion> comps,
  Set<String> frozen,
  DateTime asOf,
) {
  final today = dayOnly(asOf);
  var start = dayOnly(t.startDate);
  final earliest = addDays(today, -730);
  if (start.isBefore(earliest)) start = earliest;
  var run = 0;
  var best = 0;
  for (var d = start; !d.isAfter(today); d = addDays(d, 1)) {
    if (!t.isScheduledOn(d)) continue;
    final dk = dateKey(d);
    var done = t.times.isNotEmpty;
    for (var i = 0; i < t.times.length; i++) {
      if (comps[occKey(t.id, dk, i)]?.status != 'done') {
        done = false;
        break;
      }
    }
    if (done) {
      run++;
      if (run > best) best = run;
    } else if (d == today) {
      // still pending - keep the streak alive
    } else if (frozen.contains(dk)) {
      // protected by a freeze
    } else {
      run = 0;
    }
  }
  return StreakInfo(run, best);
}
