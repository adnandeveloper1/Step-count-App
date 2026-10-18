import 'package:build_up/features/social/presentation/providers/leaderboard_provider.dart';
import 'package:build_up/features/social/presentation/widgets/leaderboard_widgets.dart';
import 'package:build_up/features/step_tracking/presentation/providers/step_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

LeaderboardUser walker(
  String id,
  int score, {
  String? name,
  String avatar = '',
  int today = 0,
}) {
  return LeaderboardUser(
    id: id,
    name: name ?? id,
    totalSteps: score,
    monthlyHighScore: score,
    avatarUrl: avatar,
    todaySteps: today,
  );
}

final race = [
  walker('ali', 14820, name: 'Ali'),
  walker('sara', 12960, name: 'Sara'),
  walker('omar', 11380, name: 'Omar'),
  walker('me', 10140, name: 'Moiz'),
  walker('hina', 8730, name: 'Hina'),
];

StepRaceStanding standing(
  List<LeaderboardUser> users,
  String? myId, [
  LeaderboardPeriod period = LeaderboardPeriod.month,
]) =>
    StepRaceStanding.from(users, leaderboardRanks(users, period), period, myId);

Future<void> pumpInApp(
  WidgetTester tester,
  Widget child, {
  double textScale = 1,
  Brightness brightness = Brightness.dark,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        brightness: brightness,
        primaryColor: const Color(0xFFCCFF00),
      ),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 780),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('StepRaceStanding', () {
    test('mid-table: rank, steps to pass the walker ahead, progress', () {
      final s = standing(race, 'me');
      expect(s.rank, 4);
      expect(s.score, 10140);
      expect(s.stepsToPass, 11380 - 10140 + 1);
      expect(s.aheadName, 'Omar');
      expect(s.progress, closeTo(10140 / 11380, 1e-9));
      expect(s.hint, '1,241 STEPS TO PASS OMAR');
    });

    test('leader has full progress and no one to pass', () {
      final s = standing(race, 'ali');
      expect(s.isLeader, isTrue);
      expect(s.stepsToPass, isNull);
      expect(s.progress, 1);
      expect(s.hint, 'YOU ARE IN THE LEAD');
    });

    test('last place points at the walker just ahead', () {
      final s = standing(race, 'hina');
      expect(s.rank, 5);
      expect(s.aheadName, 'Moiz');
    });

    test('signed out (null id) is unranked', () {
      final s = standing(race, null);
      expect(s.isRanked, isFalse);
      expect(s.isLeader, isFalse);
      expect(s.score, 0);
      expect(s.progress, 0);
      expect(s.hint, 'WALK MORE TO JOIN THE RACE');
    });

    test('user outside the top 50 is unranked', () {
      expect(standing(race, 'stranger').isRanked, isFalse);
    });

    test('empty board is unranked, no crash', () {
      expect(standing(const [], 'me').isRanked, isFalse);
    });

    test('tie: shares the rank and targets the walker above the tie', () {
      final users = [
        walker('a', 9000, name: 'Ann'),
        walker('b', 5000, name: 'Bob'),
        walker('me', 5000),
      ];
      final s = standing(users, 'me');
      expect(s.rank, 2);
      expect(s.isTied, isTrue);
      expect(s.aheadName, 'Ann');
      expect(s.stepsToPass, 4001);
    });

    test('tied for first says so', () {
      final s = standing([walker('a', 5000), walker('me', 5000)], 'me');
      expect(s.rank, 1);
      expect(s.isLeader, isTrue);
      expect(s.hint, 'TIED FOR THE LEAD');
    });

    test('passing takes one step more than the gap', () {
      final s = standing([
        walker('a', 5001, name: 'Ann'),
        walker('me', 5000),
      ], 'me');
      expect(s.hint, '2 STEPS TO PASS ANN');
      final one = standing([
        walker('a', 5000, name: 'Ann'),
        walker('me', 4999),
      ], 'me');
      expect(one.stepsToPass, 2);
      final exact = standing([
        walker('a', 1, name: 'Ann'),
        walker('me', 0),
      ], 'me');
      expect(exact.stepsToPass, 2);
    });

    test('everyone on zero: tied lead, progress full, not NaN', () {
      final s = standing([walker('a', 0), walker('me', 0)], 'me');
      expect(s.isLeader, isTrue);
      expect(s.progress, 1);
    });

    test('blank name ahead falls back to generic copy', () {
      final s = standing([
        walker('a', 900, name: '   '),
        walker('me', 100),
      ], 'me');
      expect(s.hint, '801 STEPS TO PASS THE NEXT WALKER');
    });

    test('out-of-order data never gives a bad gap or progress', () {
      final s = standing([walker('a', 100), walker('me', 900)], 'me');
      expect(s.isLeader, isTrue);
      expect(s.progress, 1);
    });

    test('Today period uses today\'s steps, not the monthly best', () {
      final users = [
        walker('a', 100, name: 'Ann', today: 4000),
        walker('me', 99999, today: 2500),
      ];
      final s = standing(users, 'me', LeaderboardPeriod.today);
      expect(s.score, 2500);
      expect(s.stepsToPass, 1501);
      expect(s.hint, '1,501 STEPS TO PASS ANN');
    });
  });

  group('leagueColor', () {
    LeaderboardUser leagued(int score, String? league) => LeaderboardUser(
      id: 'x',
      name: 'x',
      totalSteps: 0,
      monthlyHighScore: score,
      avatarUrl: '',
      currentLeague: league,
    );

    test('saved league wins, any case', () {
      expect(leagueColor(leagued(0, 'Diamond')), LeagueTier.diamond.color);
      expect(leagueColor(leagued(0, 'GOLD')), LeagueTier.gold.color);
      expect(leagueColor(leagued(0, 'silver')), LeagueTier.silver.color);
      expect(leagueColor(leagued(99999, 'bronze')), LeagueTier.bronze.color);
    });

    test('no saved league falls back to the monthly best', () {
      expect(leagueColor(leagued(12000, null)), LeagueTier.diamond.color);
      expect(leagueColor(leagued(8000, null)), LeagueTier.gold.color);
      expect(leagueColor(leagued(5000, null)), LeagueTier.silver.color);
      expect(leagueColor(leagued(4999, 'unknown')), LeagueTier.bronze.color);
    });
  });

  group('StepRaceRankCard', () {
    testWidgets('shows rank, formatted score, bar and hint', (tester) async {
      await pumpInApp(tester, StepRaceRankCard(standing: standing(race, 'me')));
      expect(find.text('#4'), findsOneWidget);
      expect(find.text('10,140'), findsOneWidget);
      expect(find.text('1,241 STEPS TO PASS OMAR'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, closeTo(10140 / 11380, 1e-9));
    });

    testWidgets('unranked shows dashes', (tester) async {
      await pumpInApp(tester, StepRaceRankCard(standing: standing(race, null)));
      expect(find.text('--'), findsOneWidget);
      expect(find.text('WALK MORE TO JOIN THE RACE'), findsOneWidget);
    });

    for (final brightness in Brightness.values) {
      testWidgets('huge numbers at 2x text do not overflow ($brightness)', (
        tester,
      ) async {
        final users = [
          walker('a', 999999999, name: 'A really long display name here'),
          walker('me', 123456789),
        ];
        await pumpInApp(
          tester,
          StepRaceRankCard(standing: standing(users, 'me')),
          textScale: 2,
          brightness: brightness,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('StepRaceList', () {
    Widget list(List<LeaderboardUser> users, String? myId) => StepRaceList(
      users: users,
      ranks: leaderboardRanks(users),
      period: LeaderboardPeriod.month,
      myId: myId,
    );

    testWidgets('own row says You instead of the name', (tester) async {
      await pumpInApp(tester, list(race, 'me'));
      expect(find.text('You'), findsOneWidget);
      expect(find.text('Moiz'), findsNothing);
      expect(find.text('Ali'), findsOneWidget);
      expect(find.text('14,820'), findsOneWidget);
    });

    testWidgets('tied walkers show the same rank', (tester) async {
      final users = [walker('a', 900), walker('b', 500), walker('c', 500)];
      await pumpInApp(tester, list(users, null));
      for (final id in ['b', 'c']) {
        final rank = tester.widget<Text>(
          find.byKey(Key('leaderboard-rank-$id')),
        );
        expect(rank.data, '2');
      }
    });

    testWidgets('emoji, empty and broken-photo avatars at 2x text', (
      tester,
    ) async {
      await pumpInApp(
        tester,
        list([
          walker('a', 99999999, avatar: '🏃', name: 'x' * 80),
          walker('b', 5),
          walker('c', 1, avatar: 'https://invalid.example/none.png'),
        ], 'b'),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.person), findsOneWidget);
    });
  });
}
