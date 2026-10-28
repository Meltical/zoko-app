import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'household_repository.dart';

final householdProvider = AsyncNotifierProvider<HouseholdNotifier, Membership?>(HouseholdNotifier.new);

final householdIdProvider = Provider<String?>((ref) {
  final membership = ref.watch(householdProvider).value;
  return membership != null && membership.approved ? membership.householdId : null;
});

final isAdminProvider = Provider<bool>((ref) {
  final membership = ref.watch(householdProvider).value;
  return membership != null && membership.approved && membership.isAdmin;
});

final joinCodeProvider = FutureProvider<String?>((ref) async {
  final householdId = ref.watch(householdIdProvider);
  if (householdId == null) return null;
  return ref.watch(householdRepositoryProvider).fetchJoinCode(householdId);
});

final pendingInviteProvider = NotifierProvider<PendingInviteNotifier, String?>(PendingInviteNotifier.new);

class PendingInviteNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String code) => state = code;
}

final membersProvider = AsyncNotifierProvider<MembersNotifier, List<Member>>(MembersNotifier.new);

final pendingRequestsProvider = Provider<int>((ref) {
  if (!ref.watch(isAdminProvider)) return 0;
  return (ref.watch(membersProvider).value ?? const []).where((member) => !member.approved).length;
});

class HouseholdNotifier extends AsyncNotifier<Membership?> {
  HouseholdRepository get _repository => ref.read(householdRepositoryProvider);

  @override
  Future<Membership?> build() async {
    final repository = ref.watch(householdRepositoryProvider);
    if (!repository.isSignedIn) return null;
    final membership = await repository.fetchMembership();
    if (membership != null && !membership.approved) _watchApproval(repository);
    return membership;
  }

  void _watchApproval(HouseholdRepository repository) {
    final userId = repository.currentUserId;
    if (userId == null) return;
    final channel = repository.subscribeMembers(
      'membership:$userId',
      PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
      refresh,
    );
    final poll = Timer.periodic(const Duration(seconds: 20), (_) => refresh());
    final lifecycle = AppLifecycleListener(onResume: refresh);
    ref.onDispose(() {
      poll.cancel();
      lifecycle.dispose();
      channel.unsubscribe();
    });
  }

  Future<void> refresh() async {
    try {
      final membership = await _repository.fetchMembership();
      final previous = state.value;
      if (previous?.approved != membership?.approved || previous?.householdId != membership?.householdId) {
        ref.invalidateSelf();
      }
    } catch (_) {}
  }

  Future<void> join(String code, String displayName) async {
    await _repository.join(code, displayName);
    ref.invalidateSelf();
    await future;
  }

  Future<void> leave() async {
    await _repository.leave();
    ref.invalidateSelf();
    await future;
  }
}

class MembersNotifier extends AsyncNotifier<List<Member>> {
  Timer? _debounce;

  @override
  Future<List<Member>> build() async {
    final repository = ref.watch(householdRepositoryProvider);
    final householdId = ref.watch(householdIdProvider);
    if (householdId == null) return const [];
    final channel = repository.subscribeMembers(
      'members:$householdId',
      PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'household_id', value: householdId),
      _scheduleRefresh,
    );
    final lifecycle = AppLifecycleListener(onResume: _scheduleRefresh);
    ref.onDispose(() {
      _debounce?.cancel();
      lifecycle.dispose();
      channel.unsubscribe();
    });
    return repository.fetchMembers(householdId);
  }

  void _scheduleRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), ref.invalidateSelf);
  }

  Future<void> approve(Member member) async {
    await ref.read(householdRepositoryProvider).approve(member.userId);
    ref.invalidateSelf();
  }

  Future<void> remove(Member member) async {
    await ref.read(householdRepositoryProvider).remove(member.userId);
    ref.invalidateSelf();
  }

  Future<String> rotateCode() async {
    final code = await ref.read(householdRepositoryProvider).rotateCode();
    ref.invalidate(joinCodeProvider);
    return code;
  }
}
