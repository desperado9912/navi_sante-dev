// test/features/auth/cubit/auth_cubit_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:navi_sante/features/auth/cubit/auth_cubit.dart';
import 'package:navi_sante/features/auth/services/auth_services.dart';

class MockAuthServices extends Mock implements AuthServices {}

User _tempUser({String? emailConfirmedAt}) {
  return User(
    id: 'test-user-id',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: DateTime.now().toIso8601String(),
    email: 'ngwatancho0051@gmail.com',
    emailConfirmedAt: emailConfirmedAt,
  );
}

void main() {
  late MockAuthServices mockAuthServices;

  setUp(() {
    mockAuthServices = MockAuthServices();
  });

  group('AuthCubit.login', () {
    blocTest<AuthCubit, AuthState>(
      'rejects an invalid email without calling the backend',
      build: () => AuthCubit(authServices: mockAuthServices),
      act: (cubit) =>
          cubit.login(email: 'not-an-email', password: 'whatever123'),
      expect: () => [const AuthLoading(), isA<AuthError>()],
      verify: (_) {
        verifyNever(
          () => mockAuthServices.signInWithEmailPassword(any(), any()),
        );
      },
    );

    blocTest<AuthCubit, AuthState>(
      'flags an unverified account after valid credentials',
      build: () {
        when(() => mockAuthServices.signInWithEmailPassword(any(), any()))
            .thenAnswer((_) async => AuthResponse(
                  user: _tempUser(emailConfirmedAt: null),
                  session: null,
                ));
        return AuthCubit(authServices: mockAuthServices);
      },
      act: (cubit) => cubit.login(
        email: 'Ngwatancho0051@gmail.com', // deliberately mixed case + no trim
        password: 'Password123',
      ),
      expect: () => [const AuthLoading(), const AuthEmailNotVerified()],
      verify: (_) {
        // proves the cubit actually normalizes (lowercase/trim) the email
        verify(() => mockAuthServices.signInWithEmailPassword(
              'ngwatancho0051@gmail.com',
              'Password123',
            )).called(1);
      },
    );
  });
}