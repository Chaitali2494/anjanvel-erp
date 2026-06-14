import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_user.dart';
import 'supabase_provider.dart';

final authStateProvider = StreamProvider<AppUser?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange.asyncMap((event) async {
    final user = event.session?.user;
    if (user == null) return null;
    final data = await client
        .from('users')
        .select('*, roles(*)')
        .eq('id', user.id)
        .single();
    return AppUser.fromJson(data);
  });
});

final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authStateProvider).value;
});

final isOwnerProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider)?.role == 'OWNER';
});

final isManagerOrOwnerProvider = Provider<bool>((ref) {
  final role = ref.watch(currentUserProvider)?.role;
  return role == 'OWNER' || role == 'MANAGER';
});

class AuthNotifier extends AsyncNotifier<AppUser?> {
  @override
  Future<AppUser?> build() async {
    final client = ref.watch(supabaseClientProvider);
    final session = client.auth.currentSession;
    if (session == null) return null;
    final data = await client
        .from('users')
        .select()
        .eq('id', session.user.id)
        .single();
    return AppUser.fromJson(data);
  }

  Future<void> signInWithPhone(String phone) async {
    final client = ref.read(supabaseClientProvider);
    await client.auth.signInWithOtp(phone: phone);
  }

  Future<void> verifyOtp(String phone, String otp) async {
    final client = ref.read(supabaseClientProvider);
    await client.auth.verifyOTP(
      phone: phone,
      token: otp,
      type: OtpType.sms,
    );
  }

  Future<void> signInWithEmail(String email, String password) async {
    final client = ref.read(supabaseClientProvider);
    await client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    final client = ref.read(supabaseClientProvider);
    await client.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    final client = ref.read(supabaseClientProvider);
    await client.auth.resetPasswordForEmail(email);
  }
}

final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, AppUser?>(AuthNotifier.new);
