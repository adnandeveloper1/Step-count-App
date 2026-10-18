import 'package:build_up/features/social/presentation/providers/leaderboard_provider.dart';
import 'package:build_up/features/social/presentation/widgets/leaderboard_widgets.dart';
import 'package:build_up/features/step_tracking/presentation/providers/step_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

LeaderboardUser _walker(
  String id,
  int score, {
  String? name,
  String avatar = '',
  int today = 0,
  String? league,
}) {
  return LeaderboardUser(
    id: id,
    name: name ?? id,
    totalSteps: score,
    monthlyHighScore: score,
    avatarUrl: avatar,
    todaySteps: today,
    currentLeague: league,
  );
}

final _race = [
  _walker('ali', 14820, name: 'Ali'),
  _walker('sara', 12960, name: 'Sara'),
  _walker('omar', 11380, name: 'Omar'),
  _walker('me', 10140, name: 'Moiz'),
  _walker('hina', 8730, name: 'Hina'),
];

StepRaceBoard _board(
  List<LeaderboardUser> users, [
  LeaderboardPeriod period = LeaderboardPeriod.month,
]) => StepRaceBoard.from(users, period);

StepRaceStanding _standing(
  List<LeaderboardUser> users,
  String? myId, [
  LeaderboardPeriod period = LeaderboardPeriod.month,
]) => StepRaceStanding.from(_board(users, period), myId);

const _lime = Color(0xFFCCFF00);

Future<void> _pumpInApp(
  WidgetTester tester,
  Widget child, {
  double textScale = 1,
  Brightness brightness = Brightness.dark,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness, primaryColor: _lime),
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

  group('StepRaceBoard', () {
    test('sorts by the period score, highest first', () {
      final board = _board([
        _walker('a', 100),
        _walker('b', 900),
        _walker('c', 500),
      ]);
      expect(board.users.map((u) => u.id), ['b', 'c', 'a']);
      expect(board.ranks, [1, 2, 3]);
    });

    test('equal scores keep their incoming order and share a rank', () {
      final board = _board([
        _walker('a', 500),
        _walker('b', 900),
        _walker('c', 500),
      ]);
      expect(board.users.map((u) => u.id), ['b', 'a', 'c']);
      expect(board.ranks, [1, 2, 2]);
    });

    test('Today sorts by today\'s steps, not the monthly best', () {
      final board = _board([
        _walker('a', 99999, today: 10),
        _walker('b', 1, today: 500),
      ], LeaderboardPeriod.today);
      expect(board.users.map((u) => u.id), ['b', 'a']);
    });
  });

  group('StepRaceStanding', () {
    test('mid-table: rank, steps to pass the walker ahead, progress', () {
      final s = _standing(_race, 'me');
      expect(s.rank, 4);
      expect(s.score, 10140);
      expect(s.stepsToPass, 11380 - 10140 + 1);
      expect(s.aheadName, 'Omar');
      expect(s.progress, closeTo(10140 / 11380, 1e-9));
      expect(stepRaceHint(s), '1,241 STEPS TO PASS OMAR');
    });

    test('leader has full progress and no one to pass', () {
      final s = _standing(_race, 'ali');
      expect(s.isLeader, isTrue);
      expect(s.stepsToPass, isNull);
      expect(s.progress, 1);
      expect(stepRaceHint(s), 'YOU ARE IN THE LEAD');
    });

    test('last place points at the walker just ahead', () {
      final s = _standing(_race, 'hina');
      expect(s.rank, 5);
      expect(s.aheadName, 'Moiz');
    });

    test('signed out: no rank, no score, asks to sign in', () {
      final s = _standing(_race, null);
      expect(s.isSignedIn, isFalse);
      expect(s.isRanked, isFalse);
      expect(s.isLeader, isFalse);
      expect(s.score, isNull);
      expect(s.progress, 0);
      expect(stepRaceHint(s), 'SIGN IN TO JOIN THE RACE');
    });

    test('signed in but outside the top 50: no score, asks to walk', () {
      final s = _standing(_race, 'stranger');
      expect(s.isSignedIn, isTrue);
      expect(s.isRanked, isFalse);
      expect(s.score, isNull);
      expect(stepRaceHint(s), 'WALK MORE TO JOIN THE RACE');
    });

    test('empty board is unranked, no crash', () {
      expect(_standing(const [], 'me').isRanked, isFalse);
    });

    test('tie: shares the rank and targets the walker above the tie', () {
      final users = [
        _walker('a', 9000, name: 'Ann'),
        _walker('b', 5000, name: 'Bob'),
        _walker('me', 5000),
      ];
      final s = _standing(users, 'me');
      expect(s.rank, 2);
      expect(s.isTied, isTrue);
      expect(s.aheadName, 'Ann');
      expect(s.stepsToPass, 4001);
    });

    test('tied for first says so', () {
      final s = _standing([_walker('a', 5000), _walker('me', 5000)], 'me');
      expect(s.rank, 1);
      expect(s.isLeader, isTrue);
      expect(stepRaceHint(s), 'TIED FOR THE LEAD');
    });

    test('passing takes one step more than the gap', () {
      final s = _standing([
        _walker('a', 5001, name: 'Ann'),
        _walker('me', 5000),
      ], 'me');
      expect(s.stepsToPass, 2);
      expect(stepRaceHint(s), '2 STEPS TO PASS ANN');
    });

    test('everyone on zero: tied lead, progress full, not NaN', () {
      final s = _standing([_walker('a', 0), _walker('me', 0)], 'me');
      expect(s.isLeader, isTrue);
      expect(s.progress, 1);
    });

    test('blank name ahead falls back to generic copy', () {
      final s = _standing([
        _walker('a', 900, name: '   '),
        _walker('me', 100),
      ], 'me');
      expect(stepRaceHint(s), '801 STEPS TO PASS THE NEXT WALKER');
    });

    test('out-of-order data: rank and lead agree after sorting', () {
      final s = _standing([
        _walker('a', 100, name: 'Ann'),
        _walker('me', 900),
      ], 'me');
      expect(s.rank, 1);
      expect(s.isLeader, isTrue);
      expect(s.progress, 1);

      final behind = _standing([
        _walker('me', 100),
        _walker('a', 900, name: 'Ann'),
      ], 'me');
      expect(behind.rank, 2);
      expect(behind.aheadName, 'Ann');
      expect(behind.stepsToPass, 801);
    });

    test('Today period uses today\'s steps, not the monthly best', () {
      final users = [
        _walker('a', 100, name: 'Ann', today: 4000),
        _walker('me', 99999, today: 2500),
      ];
      final s = _standing(users, 'me', LeaderboardPeriod.today);
      expect(s.score, 2500);
      expect(s.stepsToPass, 1501);
      expect(stepRaceHint(s), '1,501 STEPS TO PASS ANN');
    });
  });

  group('leagueColor', () {
    test('saved league wins, any case', () {
      expect(
        leagueColor(_walker('x', 0, league: 'Diamond')),
        LeagueTier.diamond.color,
      );
      expect(
        leagueColor(_walker('x', 0, league: 'GOLD')),
        LeagueTier.gold.color,
      );
      expect(
        leagueColor(_walker('x', 0, league: 'silver')),
        LeagueTier.silver.color,
      );
      expect(
        leagueColor(_walker('x', 99999, league: 'bronze')),
        LeagueTier.bronze.color,
      );
    });

    test('no saved league falls back to the monthly best', () {
      expect(leagueColor(_walker('x', 12000)), LeagueTier.diamond.color);
      expect(leagueColor(_walker('x', 8000)), LeagueTier.gold.color);
      expect(leagueColor(_walker('x', 5000)), LeagueTier.silver.color);
      expect(
        leagueColor(_walker('x', 4999, league: 'unknown')),
        LeagueTier.bronze.color,
      );
    });
  });

  group('StepRaceRankCard', () {
    testWidgets('shows rank, formatted score, bar and hint', (tester) async {
      await _pumpInApp(
        tester,
        StepRaceRankCard(standing: _standing(_race, 'me')),
      );
      expect(find.text('#4'), findsOneWidget);
      expect(find.text('10,140'), findsOneWidget);
      expect(find.text('1,241 STEPS TO PASS OMAR'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, closeTo(10140 / 11380, 1e-9));
    });

    testWidgets('unranked shows dashes and no score', (tester) async {
      await _pumpInApp(
        tester,
        StepRaceRankCard(standing: _standing(_race, 'stranger')),
      );
      expect(find.text('--'), findsOneWidget);
      expect(find.text('steps'), findsNothing);
      expect(find.text('0'), findsNothing);
      expect(find.text('WALK MORE TO JOIN THE RACE'), findsOneWidget);
    });

    testWidgets('light theme darkens the lime bar for contrast', (
      tester,
    ) async {
      await _pumpInApp(
        tester,
        StepRaceRankCard(standing: _standing(_race, 'me')),
        brightness: Brightness.light,
      );
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.color, isNot(_lime));
      expect(bar.color!.computeLuminance(), lessThan(_lime.computeLuminance()));
    });

    for (final brightness in Brightness.values) {
      testWidgets('huge numbers at 2x text do not overflow ($brightness)', (
        tester,
      ) async {
        final users = [
          _walker('a', 999999999, name: 'A really long display name here'),
          _walker('me', 123456789),
        ];
        await _pumpInApp(
          tester,
          StepRaceRankCard(standing: _standing(users, 'me')),
          textScale: 2,
          brightness: brightness,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('StepRaceList', () {
    Widget list(List<LeaderboardUser> users, String? myId) =>
        StepRaceList(board: _board(users), myId: myId);

    BoxDecoration? rowTint(WidgetTester tester, String id) {
      final inner = find.descendant(
        of: find.byKey(Key('leaderboard-row-$id')),
        matching: find.byType(Container),
      );
      return tester.widget<Container>(inner.first).decoration as BoxDecoration?;
    }

    for (final brightness in Brightness.values) {
      testWidgets('own row says You and is tinted ($brightness)', (
        tester,
      ) async {
        await _pumpInApp(tester, list(_race, 'me'), brightness: brightness);
        expect(find.text('You'), findsOneWidget);
        expect(find.text('Moiz'), findsNothing);
        expect(find.text('Ali'), findsOneWidget);
        expect(find.text('14,820'), findsOneWidget);
        expect(rowTint(tester, 'me')?.color, isNotNull);
        expect(rowTint(tester, 'ali'), isNull);
      });
    }

    testWidgets('avatar fill follows the theme', (tester) async {
      const navy = Color(0xFF1E293B);
      const lightPage = Color(0xFFEDEFF1);
      Color fill() => tester
          .widget<CircleAvatar>(
            find.descendant(
              of: find.byKey(const Key('leaderboard-row-ali')),
              matching: find.byType(CircleAvatar),
            ),
          )
          .backgroundColor!;

      await _pumpInApp(tester, list(_race, null));
      expect(fill(), navy);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: _lime,
            scaffoldBackgroundColor: lightPage,
          ),
          home: Scaffold(body: SingleChildScrollView(child: list(_race, null))),
        ),
      );
      await tester.pumpAndSettle();
      expect(fill(), lightPage);
    });

    testWidgets('rows follow the score order, not the incoming order', (
      tester,
    ) async {
      await _pumpInApp(
        tester,
        list([_walker('low', 10), _walker('high', 900)], null),
      );
      final highY = tester
          .getTopLeft(find.byKey(const Key('leaderboard-row-high')))
          .dy;
      final lowY = tester
          .getTopLeft(find.byKey(const Key('leaderboard-row-low')))
          .dy;
      expect(highY, lessThan(lowY));
    });

    testWidgets('tied walkers show the same rank', (tester) async {
      final users = [_walker('a', 900), _walker('b', 500), _walker('c', 500)];
      await _pumpInApp(tester, list(users, null));
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
      await _pumpInApp(
        tester,
        list([
          _walker('a', 99999999, avatar: '🏃', name: 'x' * 80),
          _walker('b', 5),
          _walker('c', 1, avatar: 'https://invalid.example/none.png'),
        ], 'b'),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.person), findsOneWidget);
    });
  });
}
