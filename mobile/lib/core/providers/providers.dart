import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cache/app_cache.dart';
import '../config/env.dart';
import '../models/models.dart';
import '../network/dio_client.dart';

class ApiRepository {
  ApiRepository(this._dio, this._supabase);

  final Dio _dio;
  final SupabaseClient _supabase;

  Future<String?> signUp(String email, String password, String fullName) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
    if (response.user == null) {
      throw Exception('Could not create account');
    }
    if (response.session == null) {
      return 'confirm_email';
    }
    try {
      await _dio.post('/profiles', data: {
        'id': response.user!.id,
        'email': email,
        'full_name': fullName,
      });
    } catch (_) {
      // Profile may be auto-created on first /me call
    }
    return null;
  }

  Future<void> signIn(String email, String password) async {
    await _supabase.auth.signInWithPassword(email: email, password: password);
  }

  /// Starts Google OAuth via Supabase. On web this redirects the browser.
  Future<bool> signInWithGoogle() async {
    final redirectTo = kIsWeb
        ? '${Uri.base.origin}${AppConfig.authCallbackPath}'
        : AppConfig.oauthDeepLink;
    return _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectTo,
      authScreenLaunchMode:
          kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      queryParams: const {
        'access_type': 'offline',
        'prompt': 'select_account',
      },
    );
  }

  Future<void> signOut() async {
    await AppCache.clear();
    await _supabase.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  Future<ProfileModel> getProfile() async {
    final res = await _dio.get('/me');
    final json = res.data as Map<String, dynamic>;
    AppCache.saveProfile(json);
    return ProfileModel.fromJson(json);
  }

  Future<ProfileModel> updateProfile(Map<String, dynamic> data) async {
    final res = await _dio.patch('/me', data: data);
    return ProfileModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> getOnboarding() async {
    final res = await _dio.get('/onboarding');
    return res.data as Map<String, dynamic>;
  }

  Future<void> saveOnboardingStep(int step, Map<String, dynamic> data) async {
    await _dio.put('/onboarding/step/$step', data: {'data': data});
  }

  Future<void> completeOnboarding() async {
    await _dio.post('/onboarding/complete');
  }

  Future<void> skipOnboarding() async {
    await _dio.post('/onboarding/skip');
  }

  Future<ChallengeCatalog> getChallengeCatalog() async {
    final res = await _dio.get('/challenge-templates');
    return ChallengeCatalog.fromJson(res.data as Map<String, dynamic>);
  }

  /// Starts a personal challenge, today or on [startDate].
  Future<void> createChallenge({
    String? templateId,
    required String name,
    required int durationDays,
    required DateTime startDate,
    required List<String> tasks,
    required bool includeFoundation,
  }) async {
    String two(int n) => n.toString().padLeft(2, '0');
    await _dio.post('/challenges', data: {
      if (templateId != null) 'template_id': templateId,
      'name': name,
      'duration_days': durationDays,
      'start_date': '${startDate.year}-${two(startDate.month)}-${two(startDate.day)}',
      'personal_tasks': tasks,
      'include_foundation': includeFoundation,
    });
  }

  Future<List<GoalModel>> getGoals() async {
    final res = await _dio.get('/goals');
    return (res.data as List).map((e) => GoalModel.fromJson(e)).toList();
  }

  Future<List<String>> getTaskTemplates(String goal) async {
    final res = await _dio.get('/tasks/templates', queryParameters: {'goal': goal});
    return List<String>.from(res.data['templates'] as List);
  }

  Future<ChallengeModel?> getActiveChallenge() async {
    final res = await _dio.get('/challenges/active');
    if (res.data == null) return null;
    return ChallengeModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<ActiveProgramsModel> getActivePrograms() async {
    final res = await _dio.get('/challenges/active-all');
    final json = res.data as Map<String, dynamic>;
    AppCache.savePrograms(json);
    return ActiveProgramsModel.fromJson(json);
  }

  Future<List<ChallengeSummaryModel>> listChallenges() async {
    final res = await _dio.get('/challenges');
    return (res.data as List)
        .map((e) => ChallengeSummaryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ChallengeModel> getChallenge(String challengeId) async {
    final res = await _dio.get('/challenges/$challengeId');
    return ChallengeModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> completeTask(String challengeId, String taskId) async {
    final res = await _dio.post(
      '/challenges/$challengeId/complete-task',
      data: {'task_id': taskId},
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getChallengeDay(String challengeId, int dayNumber) async {
    final res = await _dio.get('/challenges/$challengeId/days/$dayNumber');
    return res.data as Map<String, dynamic>;
  }

  Future<void> cancelChallenge(String challengeId) async {
    await _dio.post('/challenges/$challengeId/cancel');
  }

  Future<Map<String, dynamic>> getActivity(String month) async {
    final res = await _dio.get('/me/activity', queryParameters: {'month': month});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMyRank(String metric) async {
    final res = await _dio.get('/leaderboard/me', queryParameters: {'metric': metric});
    return res.data as Map<String, dynamic>;
  }

  Future<List<GroupRankModel>> getGroupsLeaderboard(String metric) async {
    final res = await _dio.get('/leaderboard/groups', queryParameters: {'metric': metric});
    return (res.data as List)
        .map((e) => GroupRankModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> getGroupTasks(String groupId) async {
    final res = await _dio.get('/groups/$groupId/tasks');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addGroupTask(String groupId, String title) async {
    final res = await _dio.post('/groups/$groupId/tasks', data: {'title': title});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> removeGroupTask(String groupId, String title) async {
    final res = await _dio.delete('/groups/$groupId/tasks', queryParameters: {'title': title});
    return res.data as Map<String, dynamic>;
  }

  Future<void> leaveGroup(String groupId) async {
    await _dio.post('/groups/$groupId/leave');
  }

  Future<void> endGroup(String groupId) async {
    await _dio.delete('/groups/$groupId');
  }

  /// Chat: latest page, or only messages after/before a known message id.
  Future<({List<ChatMessageModel> messages, bool hasMore})> getGroupMessages(
    String groupId, {
    String? after,
    String? before,
    int limit = 50,
  }) async {
    final res = await _dio.get('/groups/$groupId/messages', queryParameters: {
      if (after != null) 'after': after,
      if (before != null) 'before': before,
      'limit': limit,
    });
    final data = res.data as Map<String, dynamic>;
    return (
      messages: (data['messages'] as List)
          .map((e) => ChatMessageModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasMore: data['has_more'] as bool? ?? false,
    );
  }

  Future<ChatMessageModel> postGroupMessage(String groupId, String body) async {
    final res = await _dio.post('/groups/$groupId/messages', data: {'body': body});
    return ChatMessageModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteGroupMessage(String groupId, String messageId) async {
    await _dio.delete('/groups/$groupId/messages/$messageId');
  }

  Future<List<LeaderboardEntryModel>> getLeaderboard(String metric) async {
    final res = await _dio.get('/leaderboard', queryParameters: {'metric': metric});
    return (res.data as List).map((e) => LeaderboardEntryModel.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> getPersonalStats() async {
    final res = await _dio.get('/statistics/me');
    return res.data as Map<String, dynamic>;
  }

  Future<List<GroupModel>> getGroups() async {
    final res = await _dio.get('/groups');
    return (res.data as List).map((e) => GroupModel.fromJson(e)).toList();
  }

  Future<GroupModel> createGroup(Map<String, dynamic> data) async {
    final res = await _dio.post('/groups', data: data);
    return GroupModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> previewGroupInvite(String inviteCode) async {
    final res = await _dio.get('/groups/preview/${inviteCode.toUpperCase()}');
    return res.data as Map<String, dynamic>;
  }

  Future<GroupModel> joinGroup(
    String inviteCode, {
    List<String>? personalTasks,
  }) async {
    final res = await _dio.post('/groups/join', data: {
      'invite_code': inviteCode,
      if (personalTasks != null) 'personal_tasks': personalTasks,
    });
    return GroupModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> getGroupDashboard(String groupId) async {
    final res = await _dio.get('/groups/$groupId/dashboard');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getGroupDayRoster(
    String groupId, {
    String? date,
  }) async {
    final res = await _dio.get(
      '/groups/$groupId/day-roster',
      queryParameters: {
        if (date != null) 'date': date,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addChallengeTask(
    String challengeId,
    String title,
  ) async {
    final res = await _dio.post('/challenges/$challengeId/tasks', data: {
      'title': title,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getGroupStatistics(String groupId) async {
    final res = await _dio.get('/groups/$groupId/statistics');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getGroupMemberProfile(
    String groupId,
    String memberId,
  ) async {
    final res = await _dio.get('/groups/$groupId/members/$memberId');
    return res.data as Map<String, dynamic>;
  }

  Future<void> postGroupAnnouncement(
    String groupId, {
    required String body,
    String? title,
    bool isPinned = false,
  }) async {
    await _dio.post('/groups/$groupId/announcements', data: {
      'body': body,
      if (title != null) 'title': title,
      'is_pinned': isPinned,
    });
  }

  Future<void> updateGroup(String groupId, Map<String, dynamic> data) async {
    await _dio.patch('/groups/$groupId', data: data);
  }

  Future<void> removeGroupMember(String groupId, String memberId) async {
    await _dio.delete('/groups/$groupId/members/$memberId');
  }

  Future<void> createGroupSession(String groupId, Map<String, dynamic> data) async {
    await _dio.post('/groups/$groupId/sessions', data: data);
  }

  Future<List<BadgeModel>> getBadges() async {
    final res = await _dio.get('/me/badges');
    return (res.data as List).map((e) => BadgeModel.fromJson(e)).toList();
  }

  Future<List<CertificateModel>> getCertificates() async {
    final res = await _dio.get('/me/certificates');
    return (res.data as List).map((e) => CertificateModel.fromJson(e)).toList();
  }
}

final apiRepositoryProvider = Provider<ApiRepository>((ref) {
  return ApiRepository(ref.watch(dioProvider), ref.watch(supabaseProvider));
});

/// Emits the cached profile immediately (if any), then the fresh one, so the
/// app opens instantly even when the API is slow or asleep.
final profileProvider = StreamProvider<ProfileModel>((ref) async* {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  final cached = AppCache.profileFor(userId);
  if (cached != null) yield ProfileModel.fromJson(cached);
  try {
    yield await ref.watch(apiRepositoryProvider).getProfile();
  } catch (_) {
    if (cached == null) rethrow; // keep showing cached data while offline
  }
});

final activeChallengeProvider = FutureProvider<ChallengeModel?>((ref) async {
  return ref.watch(apiRepositoryProvider).getActiveChallenge();
});

final activeProgramsProvider = StreamProvider<ActiveProgramsModel>((ref) async* {
  final cached = AppCache.programs;
  ActiveProgramsModel? first;
  if (cached != null) {
    try {
      first = ActiveProgramsModel.fromJson(cached);
      yield first;
    } catch (_) {}
  }
  try {
    yield await ref.watch(apiRepositoryProvider).getActivePrograms();
  } catch (_) {
    if (first == null) rethrow;
  }
});

final challengesListProvider = FutureProvider<List<ChallengeSummaryModel>>((ref) async {
  return ref.watch(apiRepositoryProvider).listChallenges();
});

final challengeDetailProvider =
    FutureProvider.family<ChallengeModel, String>((ref, id) async {
  return ref.watch(apiRepositoryProvider).getChallenge(id);
});

final challengeCatalogProvider = FutureProvider<ChallengeCatalog>((ref) async {
  return ref.watch(apiRepositoryProvider).getChallengeCatalog();
});

final goalsProvider = FutureProvider<List<GoalModel>>((ref) async {
  return ref.watch(apiRepositoryProvider).getGoals();
});

final taskTemplatesProvider =
    FutureProvider.family<List<String>, String>((ref, goal) async {
  return ref.watch(apiRepositoryProvider).getTaskTemplates(goal);
});

final leaderboardProvider =
    FutureProvider.family<List<LeaderboardEntryModel>, String>((ref, metric) async {
  return ref.watch(apiRepositoryProvider).getLeaderboard(metric);
});

final groupsProvider = FutureProvider<List<GroupModel>>((ref) async {
  return ref.watch(apiRepositoryProvider).getGroups();
});

final badgesProvider = FutureProvider<List<BadgeModel>>((ref) async {
  return ref.watch(apiRepositoryProvider).getBadges();
});

final certificatesProvider = FutureProvider<List<CertificateModel>>((ref) async {
  return ref.watch(apiRepositoryProvider).getCertificates();
});

final personalStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(apiRepositoryProvider).getPersonalStats();
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseProvider).auth.onAuthStateChange;
});

/// The calendar month key used by the activity provider, e.g. `2026-09`.
final activityProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, month) async {
  return ref.watch(apiRepositoryProvider).getActivity(month);
});

final myRankProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, metric) async {
  return ref.watch(apiRepositoryProvider).getMyRank(metric);
});

/// [metric] is `total` or `average`.
final groupsLeaderboardProvider =
    FutureProvider.autoDispose.family<List<GroupRankModel>, String>((ref, metric) async {
  return ref.watch(apiRepositoryProvider).getGroupsLeaderboard(metric);
});

final groupTasksProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, groupId) async {
  return ref.watch(apiRepositoryProvider).getGroupTasks(groupId);
});
