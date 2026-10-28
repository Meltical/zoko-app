import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'household_repository.dart';

final householdProvider = AsyncNotifierProvider<HouseholdNotifier, Household?>(HouseholdNotifier.new);

final householdIdProvider = Provider<String?>((ref) => ref.watch(householdProvider).value?.id);

final memberCountProvider = FutureProvider<int>((ref) {
  ref.watch(householdIdProvider);
  return ref.watch(householdRepositoryProvider).memberCount();
});

class HouseholdNotifier extends AsyncNotifier<Household?> {
  HouseholdRepository get _repository => ref.read(householdRepositoryProvider);

  @override
  Future<Household?> build() async {
    final repository = ref.watch(householdRepositoryProvider);
    await repository.ensureSignedIn();
    return repository.fetchCurrent();
  }

  Future<void> create(String name) async => state = AsyncData(await _repository.create(name));

  Future<void> join(String code) async => state = AsyncData(await _repository.join(code));

  Future<void> rotateCode() async => state = AsyncData(await _repository.rotateCode());

  Future<void> leave() async {
    await _repository.leave();
    state = const AsyncData(null);
  }
}
