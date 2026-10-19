// When the app sends today's steps to Firestore.

/// The day (yyyy-MM-dd) and step count last sent to Firestore.
typedef SentSteps = ({String day, int steps});

/// Whether [todaySteps] on [today] (yyyy-MM-dd) should be sent: always when
/// nothing was sent yet or the last send was on another day (it also carries
/// yesterday's final total), otherwise once [minNewSteps] more steps were
/// taken since [sent], or at once when the total went down (a ride or
/// vehicle bumps took steps back out).
///
/// Comparing counts across days would hold today back until it passed
/// yesterday's total.
bool needsStepUpload({
  required int todaySteps,
  required String today,
  required SentSteps? sent,
  required int minNewSteps,
}) {
  if (sent == null || sent.day != today) return true;
  return todaySteps < sent.steps || todaySteps - sent.steps >= minNewSteps;
}
