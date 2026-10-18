# Step Race privacy: public leaderboard cards

## The problem

The Step Race used to query the whole `users` collection, ordered by
`monthlyHighScore` or `dailyHistory.<today>`. Every phone downloaded the top 50
users' full profiles, including weight, height, body fat, coins, challenge
progress and weekly steps. Firestore can't return only some fields of a
document to a client, so the only fix is a separate collection.

## The fix in the app

`leaderboard/{uid}` holds one public card per user, with only what the race
shows (built by `leaderboardCard` in
`lib/features/social/models/leaderboard_card.dart`):

| Field | From `users/{uid}` |
| --- | --- |
| `name` | `name`, else "Anonymous Walker" |
| `avatarUrl` | `avatarUrl`, else empty |
| `monthlyHighScore` | `monthlyHighScore`, else 0 |
| `monthlyHighScoreMonth` | `monthlyHighScoreMonth`, else the month of `lastUpdated` |
| `currentLeague` | `currentLeague` |
| `proAvatar` | owns `avatar_pro` and `proAvatarEquipped` isn't false |
| `daySteps` | `{ <today>: dailyHistory.<today> }`, or empty |

Who writes it:

- **While the app is open** (`leaderboardCardSyncProvider`, started from
  `BuildUpApp` for the signed-in uid): listens to the user's own `users/{uid}`
  document and writes the card whenever it changes what the card holds. So
  every write to the profile reaches the card: the high-score transaction, the
  full profile sync, edit profile (name, avatar), the store (pro avatar), and
  account creation. It mirrors the server profile, never local storage, so a
  fresh install that hasn't restored the account can't publish zeros. A user
  who updates from a version without cards gets one on first open.
- **Background sync** (`lib/main.dart`, only when `localDataState` isn't
  `restore`, same as the profile sync): updates `daySteps` on an existing card.
  It doesn't create cards; the app does on the next open.

`leaderboardProvider` reads only `leaderboard`, ordered by `monthlyHighScore`
or `daySteps.<today>` (single-field indexes, created automatically).

## The switch (your decision)

Users on older versions never write cards, so they are missing from the new
race until they update. Two ways to handle it:

### Option A (recommended): a Cloud Function that mirrors `users` to `leaderboard`

Everyone appears straight away, whatever version they run, and the function
keeps working as a safety net later. Needs the Blaze (pay as you go) plan;
at this app's size it should stay within the free quota. Draft, not deployed:

```js
// functions/index.js  (Node 20, firebase-functions v6)
const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

initializeApp();
const db = getFirestore();

// Same rules as leaderboardCard in leaderboard_card.dart.
function dayKey(d) {
  // The phone keys days in its own time zone; most users are in one zone.
  // Change "Asia/Karachi" if most of them are elsewhere.
  return d.toLocaleDateString("en-CA", { timeZone: "Asia/Karachi" });
}

function cardFor(p, now) {
  const today = dayKey(now);
  const steps = p.dailyHistory?.[today];
  const month =
    p.monthlyHighScoreMonth ??
    (p.lastUpdated ? dayKey(p.lastUpdated.toDate()).slice(0, 7) : undefined);
  const card = {
    name: typeof p.name === "string" ? p.name : "Anonymous Walker",
    avatarUrl: typeof p.avatarUrl === "string" ? p.avatarUrl : "",
    monthlyHighScore: Math.trunc(p.monthlyHighScore ?? 0),
    proAvatar:
      (p.unlockedItems ?? []).includes("avatar_pro") &&
      p.proAvatarEquipped !== false,
    daySteps: typeof steps === "number" ? { [today]: Math.trunc(steps) } : {},
  };
  if (month) card.monthlyHighScoreMonth = month;
  if (p.currentLeague) card.currentLeague = p.currentLeague;
  return card;
}

exports.mirrorLeaderboardCard = onDocumentWritten("users/{uid}", async (event) => {
  const ref = db.collection("leaderboard").doc(event.params.uid);
  const after = event.data.after;
  if (!after.exists) return ref.delete();
  return ref.set(cardFor(after.data(), new Date()));
});
```

Plus a one-time backfill for users who don't write again soon (run once from
your machine with a service account, or as a temporary HTTPS function):
for each document in `users`, `set` `cardFor(data, new Date())` on
`leaderboard/<id>`.

### Option B: no function, wait for updates

Ship the app, then watch the Play Console until most active users are on this
version. Until then the race only shows updated users.

## Rollout steps (nothing here has been done)

1. Release this app version. Keep the current Firestore rules for now, so old
   versions still work, but add the `leaderboard/{uid}` block from
   `firestore.rules` so new versions can write and read cards.
2. Option A: deploy the function and run the backfill. Option B: wait.
3. Publish the full `firestore.rules`, which makes `users/{uid}` owner-only.
   Old versions' Step Race then fails to load (permission denied), so do it
   once most users have updated; the app's in-app update prompt helps.
4. Check on the Pixel 7a: the race lists other users, edit profile changes
   your name there, buying or unequipping the pro frame changes your avatar,
   and today's steps rise after a walk with the app closed.

Before step 3, compare `firestore.rules` with the rules in the console: it
replaces them all, and only `users` (with subcollections such as `routes`) and
`leaderboard` are covered.

## Known limits

- The card is written by its owner, so a modified client can still claim any
  score or the pro frame, exactly as it could on `users` before. Rules check
  only the shape. Making scores trustworthy needs the function (Option A) to
  be the only writer.
- A card stays after its account is deleted unless the function (or the app)
  deletes it.
