import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase.dart';

final householdRepositoryProvider = Provider<HouseholdRepository>(
  (ref) => HouseholdRepository(ref.watch(supabaseProvider)),
);

class Membership {
  const Membership({
    required this.householdId,
    required this.householdName,
    required this.approved,
    required this.isAdmin,
  });

  factory Membership.fromJson(Map<String, dynamic> json) => Membership(
    householdId: json['household_id'] as String,
    householdName: json['household_name'] as String,
    approved: json['status'] == 'approved',
    isAdmin: json['role'] == 'admin',
  );

  final String householdId;
  final String householdName;
  final bool approved;
  final bool isAdmin;
}

class Member {
  const Member({
    required this.userId,
    required this.displayName,
    required this.approved,
    required this.isAdmin,
    required this.isMe,
  });

  final String userId;
  final String? displayName;
  final bool approved;
  final bool isAdmin;
  final bool isMe;

  String get label => displayName ?? 'Téléphone sans nom';
}

Uri inviteLink(String code) => Uri.parse('https://meltical.github.io/zoko-app/rejoindre/#${code.toUpperCase()}');

String formatJoinCode(String code) =>
    [for (var i = 0; i < code.length; i += 4) code.substring(i, i + 4 > code.length ? code.length : i + 4)].join('-');

class HouseholdException implements Exception {
  const HouseholdException(this.message);

  final String message;

  @override
  String toString() => message;
}

class HouseholdRepository {
  HouseholdRepository(this._client);

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  bool get isSignedIn => _client.auth.currentSession != null;

  Future<void> _signInWithCode(String code) async {
    if (isSignedIn) return;
    try {
      await _client.auth.signInAnonymously(data: {'join_code': code});
    } on AuthException catch (error) {
      throw HouseholdException(
        error.message.contains('invalid_join_code') || error.statusCode == '403'
            ? 'Code inconnu. Vérifiez-le auprès d’un membre du foyer.'
            : 'Connexion impossible : ${error.message}',
      );
    }
  }

  Future<Membership?> fetchMembership() async {
    final json = await _client.rpc<Map<String, dynamic>?>('my_membership');
    return json == null ? null : Membership.fromJson(json);
  }

  Future<String> fetchJoinCode(String householdId) async {
    final row = await _client.from('households').select('join_code').eq('id', householdId).single();
    return row['join_code'] as String;
  }

  Future<List<Member>> fetchMembers(String householdId) async {
    final rows = await _client
        .from('household_members')
        .select('user_id, display_name, role, status')
        .eq('household_id', householdId)
        .order('joined_at');
    return [
      for (final row in rows)
        Member(
          userId: row['user_id'] as String,
          displayName: row['display_name'] as String?,
          approved: row['status'] == 'approved',
          isAdmin: row['role'] == 'admin',
          isMe: row['user_id'] == currentUserId,
        ),
    ];
  }

  RealtimeChannel subscribeMembers(String channelName, PostgresChangeFilter filter, void Function() onChange) => _client
      .channel(channelName)
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'household_members',
        filter: filter,
        callback: (_) => onChange(),
      )
      .subscribe();

  Future<Membership> join(String code, String displayName) async {
    await _signInWithCode(code);
    final membership = Membership.fromJson(await _call('join_household', {'code': code, 'display_name': displayName}));
    if (_client.auth.currentUser?.userMetadata?.containsKey('join_code') ?? false) {
      await _client.auth.updateUser(UserAttributes(data: {'join_code': null}));
    }
    return membership;
  }

  Future<String> rotateCode() async => (await _call('rotate_join_code'))['join_code'] as String;

  Future<void> approve(String userId) => _call('approve_member', {'member': userId});

  Future<void> remove(String userId) => _call('remove_member', {'member': userId});

  Future<void> leave() => _call('leave_household');

  Future<Map<String, dynamic>> _call(String function, [Map<String, dynamic>? params]) async {
    try {
      return await _client.rpc<Map<String, dynamic>?>(function, params: params) ?? const {};
    } on PostgrestException catch (error) {
      throw HouseholdException(switch (error.message) {
        'invalid_code' => 'Code inconnu. Vérifiez-le auprès d’un membre du foyer.',
        'too_many_attempts' => 'Trop d’essais. Réessayez dans une heure.',
        'admin_only' => 'Seul un admin du foyer peut faire ça.',
        'cannot_remove_self' => 'Utilisez « Quitter le foyer » pour ce téléphone.',
        _ => 'Erreur du serveur : ${error.message}',
      });
    }
  }
}
