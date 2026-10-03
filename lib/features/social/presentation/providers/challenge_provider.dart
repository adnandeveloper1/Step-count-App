import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/notification_provider/notification_provider.dart';
import '../../../../core/services/local_storage_service.dart';

class ChallengeItem {
  final String id;
  final String title;
  final String subtitle;
  final int targetSteps;
  final int rewardCoins;
  final int durationInHours;
  final int currentSteps;
  final bool isActive;
  final bool isCompleted;
  final bool isFailed;
  final DateTime? startTime;

  const ChallengeItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.targetSteps,
    required this.rewardCoins,
    required this.durationInHours,
    this.currentSteps = 0,
    this.isActive = false,
    this.isCompleted = false,
    this.isFailed = false,
    this.startTime,
  });

  double get progress {
    if (targetSteps == 0) return 0.0;
    final val = currentSteps / targetSteps;
    return val > 1.0 ? 1.0 : val;
  }

  ChallengeItem copyWith({
    int? currentSteps,
    bool? isActive,
    bool? isCompleted,
    bool? isFailed,
    DateTime? startTime,
  }) {
    return ChallengeItem(
      id: id,
      title: title,
      subtitle: subtitle,
      targetSteps: targetSteps,
      rewardCoins: rewardCoins,
      durationInHours: durationInHours,
      currentSteps: currentSteps ?? this.currentSteps,
      isActive: isActive ?? this.isActive,
      isCompleted: isCompleted ?? this.isCompleted,
      isFailed: isFailed ?? this.isFailed,
      startTime: startTime ?? this.startTime,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'currentSteps': currentSteps,
      'isActive': isActive,
      'isCompleted': isCompleted,
      'isFailed': isFailed,
      'startTime': startTime?.toIso8601String(),
    };
  }
}

final baseChallenges = [
  const ChallengeItem(
    id: '1',
    title: 'Starter Sprint',
    subtitle: 'Walk 1,000 steps today',
    targetSteps: 1000,
    rewardCoins: 15,
    durationInHours: 24,
  ),
  const ChallengeItem(
    id: '2',
    title: 'Morning Stroll',
    subtitle: 'Walk 3,000 steps',
    targetSteps: 3000,
    rewardCoins: 45,
    durationInHours: 24,
  ),
  const ChallengeItem(
    id: '3',
    title: 'Daily Dash',
    subtitle: 'Walk 5,000 steps in 24 hours',
    targetSteps: 5000,
    rewardCoins: 75,
    durationInHours: 24,
  ),
  const ChallengeItem(
    id: '4',
    title: 'Step Master',
    subtitle: 'Walk 8,000 steps',
    targetSteps: 8000,
    rewardCoins: 120,
    durationInHours: 48,
  ),
  const ChallengeItem(
    id: '5',
    title: '10K Milestone',
    subtitle: 'Walk 10,000 steps in one day',
    targetSteps: 10000,
    rewardCoins: 150,
    durationInHours: 24,
  ),
  const ChallengeItem(
    id: '6',
    title: 'Lunchtime Loop',
    subtitle: 'Walk 12,000 steps',
    targetSteps: 12000,
    rewardCoins: 180,
    durationInHours: 48,
  ),
  const ChallengeItem(
    id: '7',
    title: 'Weekend Hiker',
    subtitle: 'Walk 15,000 steps this weekend',
    targetSteps: 15000,
    rewardCoins: 225,
    durationInHours: 72,
  ),
  const ChallengeItem(
    id: '8',
    title: 'Double Dash',
    subtitle: 'Walk 20,000 steps in 2 days',
    targetSteps: 20000,
    rewardCoins: 300,
    durationInHours: 48,
  ),
  const ChallengeItem(
    id: '9',
    title: 'City Sprinter',
    subtitle: 'Walk 26,000 steps (20km)',
    targetSteps: 26000,
    rewardCoins: 390,
    durationInHours: 240,
  ),
  const ChallengeItem(
    id: '10',
    title: 'Marathon Walker',
    subtitle: 'Walk 40,000 steps in a week',
    targetSteps: 40000,
    rewardCoins: 600,
    durationInHours: 168,
  ),
  const ChallengeItem(
    id: '11',
    title: 'Weekly Warrior',
    subtitle: 'Walk 50,000 steps in 7 days',
    targetSteps: 50000,
    rewardCoins: 750,
    durationInHours: 168,
  ),
  const ChallengeItem(
    id: '12',
    title: 'Ultra Explorer',
    subtitle: 'Walk 75,000 steps in 10 days',
    targetSteps: 75000,
    rewardCoins: 1125,
    durationInHours: 240,
  ),
  const ChallengeItem(
    id: '13',
    title: 'Century Club',
    subtitle: 'Walk 100,000 steps this month',
    targetSteps: 100000,
    rewardCoins: 1500,
    durationInHours: 720,
  ),
];

final storageProvider = Provider<LocalStorageService>((ref) {
  return LocalStorageService();
});

final challengeProvider =
NotifierProvider<ChallengeNotifier, List<ChallengeItem>>(
  ChallengeNotifier.new,
);

class ChallengeNotifier extends Notifier<List<ChallengeItem>> {
  @override
  List<ChallengeItem> build() {
    final storage = ref.watch(storageProvider);
    final rawJson = storage.getChallengeData();
    Map<String, dynamic> savedMap = {};

    try {
      savedMap = jsonDecode(rawJson) as Map<String, dynamic>;
    } catch (_) {}

    final now = DateTime.now();
    bool anyFailure = false;

    final list = baseChallenges.map((item) {
      if (savedMap.containsKey(item.id)) {
        final data = savedMap[item.id] as Map<String, dynamic>;
        
        DateTime? startTime = data['startTime'] != null ? DateTime.parse(data['startTime']) : null;
        bool isActive = data['isActive'] ?? false;
        bool isFailed = data['isFailed'] ?? false;
        bool isCompleted = data['isCompleted'] ?? false;

        if (isActive && startTime != null) {
          final deadline = startTime.add(Duration(hours: item.durationInHours));
          if (now.isAfter(deadline)) {
            isActive = false;
            isFailed = true;
            anyFailure = true;
            ref.read(notificationServiceProvider).showChallengeFailed(item.title);

          }
        }

        return item.copyWith(
          currentSteps: data['currentSteps'] ?? 0,
          isActive: isActive,
          isCompleted: isCompleted,
          isFailed: isFailed,
          startTime: startTime,
        );
      }
      return item;
    }).toList();

    if (anyFailure) {
      Future.microtask(() => _persistState(list));
    }

    return list;
  }

  void startChallenge(String id) {
    state = state.map((item) {
      if (item.id == id && !item.isCompleted) {
        return item.copyWith(
          isActive: true,
          startTime: DateTime.now(),
          currentSteps: 0,
          isFailed: false,
        );
      }
      return item;
    }).toList();

    _persistState();
  }

  void stopChallenge(String id) {
    state = state.map((item) {
      if (item.id == id && item.isActive) {
        return item.copyWith(
          isActive: false,
          currentSteps: 0,
          startTime: null,
        );
      }
      return item;
    }).toList();

    _persistState();
  }

  void validateFailures() {
    final now = DateTime.now();
    bool changed = false;

    state = state.map((item) {
      if (item.isActive && item.startTime != null) {
        final deadline = item.startTime!.add(Duration(hours: item.durationInHours));
        if (now.isAfter(deadline)) {
          changed = true;
          ref.read(notificationServiceProvider).showChallengeFailed(item.title);

          return item.copyWith(isActive: false, isFailed: true);
        }
      }
      return item;
    }).toList();

    if (changed) _persistState();
  }

  int addStepsToActiveChallenges(int stepsDelta) {
    validateFailures();
    if (stepsDelta <= 0) return 0;

    bool stateChanged = false;
    int earnedCoins = 0;

    final updated = state.map((item) {
      if (!item.isActive || item.isCompleted || item.isFailed) return item;

      stateChanged = true;
      final newSteps = item.currentSteps + stepsDelta;

      if (newSteps >= item.targetSteps) {
        earnedCoins += item.rewardCoins;
        ref.read(notificationServiceProvider).showChallengeCompleted(item.title);
        return item.copyWith(
          currentSteps: item.targetSteps,
          isActive: false,
          isCompleted: true,
        );
      }

      return item.copyWith(currentSteps: newSteps);
    }).toList();

    if (stateChanged) {
      state = updated;
      _persistState();
    }
    
    return earnedCoins;
  }

  void _persistState([List<ChallengeItem>? customState]) {
    final storage = ref.read(storageProvider);
    final listToSave = customState ?? state;
    final Map<String, dynamic> dataToSave = {};

    for (var item in listToSave) {
      dataToSave[item.id] = item.toMap();
    }

    storage.saveChallengeData(jsonEncode(dataToSave));

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'challengeProgress': dataToSave,
      }, SetOptions(merge: true));
    }
  }
  // Add this inside ChallengeNotifier class in challenge_provider.dart
  Future<void> syncWithFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data()!.containsKey('challengeProgress')) {
        final cloudData = doc.data()!['challengeProgress'] as Map<String, dynamic>;

        // Update local state
        state = baseChallenges.map((item) {
          if (cloudData.containsKey(item.id)) {
            final data = cloudData[item.id] as Map<String, dynamic>;
            return item.copyWith(
              currentSteps: data['currentSteps'] ?? 0,
              isActive: data['isActive'] ?? false,
              isCompleted: data['isCompleted'] ?? false,
              isFailed: data['isFailed'] ?? false,
              startTime: data['startTime'] != null ? DateTime.parse(data['startTime']) : null,
            );
          }
          return item;
        }).toList();

        // Save to local storage
        ref.read(storageProvider).saveChallengeData(jsonEncode(cloudData));
      }
    } catch (e) {
      debugPrint("Challenge sync failed: $e");
    }
  }
}
