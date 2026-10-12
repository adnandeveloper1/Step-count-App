# Verification

Stable widget keys for driving the app in integration tests and Flutter Driver.

| Key | Widget | Shows |
| --- | --- | --- |
| `dashboard_step_count` | Dashboard ring | Today's step count |
| `dashboard_coins` | Dashboard header | Current coin balance |
| `step_details_driving_steps` | Step details, today only | Steps removed while driving today (hidden when 0) |
| `background_access_dialog` | One-time message | Battery use is Restricted: how to allow background use |
| `background_access_open_settings` | Message button | Opens the app's settings page |
| `background_access_not_now` | Message button | Closes the message |
| `goalCongrats.steps` | Goal congrats gauge | Today's steps (counts up) |
| `goalCongrats.goal` | Goal congrats gauge | `/ <goal> GOAL` |
| `goalCongrats.continue` | Goal congrats screen | Closes the screen |
| `goalCongrats.close` | Goal congrats top bar | Closes the screen |
| `goalCongrats.share` | Goal congrats screen | Opens the story share sheet |
| `goalCongrats.challenge.<id>` | Goal congrats challenges | One active challenge row |
| `goalStory.card` | Story share sheet | The 9:16 story image |
| `goalStory.share` | Story share sheet | Shares the story PNG |
| `insights.olderWeek` / `insights.newerWeek` | Insights week selector | Previous / next week |
| `insights.weekTitle` / `insights.weekRange` | Insights week selector | `THIS WEEK`, `LAST WEEK`, `N WEEKS AGO` / date range |
| `insights.average` | Insights chart card | Daily average for the selected week |
| `insights.goalDays` | Insights chart card | `GOAL MET x OF y DAYS` |
| `insights.trend` | Insights chart card | Change vs the previous week (from day 3) |

## Background step sync on a device

The background task (WorkManager) and the running app must never both write local storage. To check on a device, build with temporary logging around `StepSyncCoordinator` and:

1. Open the app and let a background run happen: it must hand the sync to the app.
2. Kill the app process without force-stopping it (`adb shell am crash com.nexappra.buildup`) and let a background run happen: it must own storage.

Android 9+ does not deliver step counter events to an app that has been idle in the background for about a minute, so a cold background run usually cannot read the sensor (it returns `-2` and saves nothing). See issue #6.

## Driving steps (fake vehicle transitions)

Debug builds have a receiver that fakes an Activity Recognition vehicle transition, so driving-step removal can be checked without driving. Release builds don't have it.

```bash
adb shell am broadcast -a com.nexappra.buildup.DEBUG_DRIVE --es type enter -p com.nexappra.buildup
```

```bash
adb shell am broadcast -a com.nexappra.buildup.DEBUG_DRIVE --es type exit -p com.nexappra.buildup
```

Recorded drives (removed once the app or the background task has applied them):

```bash
adb shell run-as com.nexappra.buildup cat shared_prefs/step_sensor_drives.xml
```

1. Walk about 50 steps: the count goes up.
2. Send `enter`, walk about 50 steps: the count stays the same.
3. Send `exit`, walk about 50 steps: the count goes up by about 50 only.
4. The widget and Firestore `todaySteps` show the same number as the dashboard.

Always send `exit` after a test `enter`: an open drive keeps the count frozen.

## Restricted battery message

Shown once, after the Physical activity permission request, when Android has the app's battery use set to Restricted. To see it on a test phone: Settings > Apps > Build Up > App battery usage, turn off Allow background usage (Restricted), then clear the app's data or reinstall and open the app.
