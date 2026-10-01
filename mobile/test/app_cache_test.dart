// A cached "programs" snapshot from a previous day must never be shown as
// if it were today's — most importantly, never as a false "all done".
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ilm_mode/core/cache/app_cache.dart';
import 'package:ilm_mode/core/models/models.dart';
import 'package:ilm_mode/core/providers/providers.dart';

Map<String, dynamic> _programsJson({required bool done}) => {
      'personal': {
        'id': 'c1',
        'name': 'Social Media Detox',
        'status': 'active',
        'duration_days': 21,
        'current_day': 4,
        'progress_percent': 14.0,
        'remaining_days': 18,
        'day_complete': done,
        'tasks': [
          {'id': 't1', 'title': 'No social media today', 'type': 'personal', 'is_completed': done},
        ],
      },
      'group': null,
    };

/// Never actually called: the provider under test only reads the cache for
/// its first emission, then waits on this forever so the test can inspect
/// that first value alone.
class _NeverRespondsApi implements ApiRepository {
  @override
  Future<ActiveProgramsModel> getActivePrograms() => Completer<ActiveProgramsModel>().future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppCache.init();
  });

  test('a snapshot cached today keeps its real done state', () async {
    AppCache.savePrograms(_programsJson(done: true));

    final container = ProviderContainer(overrides: [
      apiRepositoryProvider.overrideWithValue(_NeverRespondsApi()),
    ]);
    addTearDown(container.dispose);

    final first = await container.read(activeProgramsProvider.future);
    expect(first.personal!.dayComplete, isTrue);
    expect(first.personal!.tasks.single.isCompleted, isTrue);
  });

  test('a snapshot cached on an earlier day is never shown as done', () async {
    AppCache.savePrograms(_programsJson(done: true));
    // Back-date the cache: same payload, but tagged as a previous day.
    SharedPreferences.setMockInitialValues({
      'flutter.cache_programs': (await SharedPreferences.getInstance()).getString('cache_programs')!,
      'flutter.cache_programs_day': '2000-01-01',
    });
    await AppCache.init();

    final container = ProviderContainer(overrides: [
      apiRepositoryProvider.overrideWithValue(_NeverRespondsApi()),
    ]);
    addTearDown(container.dispose);

    final first = await container.read(activeProgramsProvider.future);
    expect(first.personal!.dayComplete, isFalse);
    expect(first.personal!.tasks.single.isCompleted, isFalse);
    // The shell (name, progress) still shows instantly — only the "done
    // today" state is distrusted.
    expect(first.personal!.name, 'Social Media Detox');
  });
}
