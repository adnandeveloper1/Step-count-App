# Verification

Stable widget keys for driving the app in integration tests and Flutter Driver.

| Key | Widget | Shows |
| --- | --- | --- |
| `dashboard_step_count` | Dashboard ring | Today's step count |
| `dashboard_coins` | Dashboard header | Current coin balance |
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
