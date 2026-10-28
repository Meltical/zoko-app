import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase.dart';

final householdRepositoryProvider = Provider<HouseholdRepository>(
  (ref) => HouseholdRepository(ref.watch(supabaseProvider)),
);

class Household {
  const Household({required this.id, required this.name, required this.joinCode});

  factory Household.fromJson(Map<String, dynamic> json) =>
      Household(id: json['id'] as String, name: json['name'] as String, joinCode: json['join_code'] as String);

  final String id;
  final String name;
  final String joinCode;

  String get formattedCode => [
    for (var i = 0; i < joinCode.length; i += 4)
      joinCode.substring(i, i + 4 > joinCode.length ? joinCode.length : i + 4),
  ].join('-');
}

class HouseholdException implements Exception {
  const HouseholdException(this.message);

  final String message;

  @override
  String toString() => message;
}

class HouseholdRepository {
  HouseholdRepository(this._client);

  final SupabaseClient _client;

  Future<void> ensureSignedIn() async {
    if (_client.auth.currentSession != null) return;
    await _client.auth.signInAnonymously();
  }

  Future<Household?> fetchCurrent() async {
    final row = await _client.from('households').select().maybeSingle();
    return row == null ? null : Household.fromJson(row);
  }

  Future<int> memberCount() async {
    final response = await _client.from('household_members').select('user_id').count(CountOption.exact);
    return response.count;
  }

  Future<Household> create(String name) => _call('create_household', {'household_name': name});

  Future<Household> join(String code) => _call('join_household', {'code': code});

  Future<Household> rotateCode() => _call('rotate_join_code');

  Future<void> leave() => _client.rpc<void>('leave_household');

  Future<Household> _call(String function, [Map<String, dynamic>? params]) async {
    try {
      final row = await _client.rpc<Map<String, dynamic>>(function, params: params);
      return Household.fromJson(row);
    } on PostgrestException catch (error) {
      throw HouseholdException(switch (error.message) {
        'invalid_code' => 'Code inconnu. Vérifiez-le auprès d’un membre du foyer.',
        'too_many_attempts' => 'Trop d’essais. Réessayez dans une heure.',
        'already_in_household' => 'Ce téléphone fait déjà partie d’un foyer.',
        _ => 'Erreur du serveur : ${error.message}',
      });
    }
  }
}
