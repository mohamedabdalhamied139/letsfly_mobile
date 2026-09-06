import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/accessibility/accessibility_announcer.dart';
import '../../core/settings/settings_store.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';

// --- Events ---
abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class LoginSubmitted extends AuthEvent {
  final String username;
  final String password;
  const LoginSubmitted({required this.username, required this.password});
  @override
  List<Object?> get props => [username, password];
}

class RegisterSubmitted extends AuthEvent {
  final String username;
  final String displayName;
  final String password;
  const RegisterSubmitted({
    required this.username,
    required this.displayName,
    required this.password,
  });
  @override
  List<Object?> get props => [username, displayName, password];
}

class LogoutRequested extends AuthEvent {}

class SavedAccountSwitchRequested extends AuthEvent {
  final String username;
  const SavedAccountSwitchRequested(this.username);
  @override List<Object?> get props => [username];
}

// --- States ---
abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class Authenticated extends AuthState {
  final UserModel user;
  const Authenticated(this.user);
  @override
  List<Object?> get props => [user];
}

class Unauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
  @override
  List<Object?> get props => [message];
}

// --- Bloc ---
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  final AccessibilityAnnouncer _announcer;
  final SettingsStore? _settings;

  AuthBloc({
    required AuthRepository authRepository,
    AccessibilityAnnouncer? announcer,
    SettingsStore? settings,
  })  : _authRepository = authRepository,
        _announcer = announcer ?? StandardAccessibilityAnnouncer(),
        _settings = settings,
        super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<LoginSubmitted>(_onLoginSubmitted);
    on<RegisterSubmitted>(_onRegisterSubmitted);
    on<LogoutRequested>(_onLogoutRequested);
    on<SavedAccountSwitchRequested>(_onSavedAccountSwitchRequested);
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (_settings?.autoLogin == false) {
      emit(Unauthenticated());
      return;
    }
    emit(AuthLoading());
    try {
      final user = await _authRepository.checkAuth();
      if (user != null) {
        emit(Authenticated(user));
        _announcer.announce('تم تسجيل الدخول تلقائيًا للمستخدم ${user.displayName}');
      } else {
        emit(Unauthenticated());
      }
    } catch (_) {
      emit(Unauthenticated());
    }
  }

  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await _authRepository.login(event.username, event.password);
      emit(Authenticated(user));
      _announcer.announce('تم تسجيل الدخول بنجاح. مرحبًا ${user.displayName}');
    } catch (e) {
      final err = e.toString().replaceAll('Exception: ', '');
      emit(AuthError(err));
      _announcer.announce('فشل تسجيل الدخول: $err', priority: AnnouncePriority.assertive);
    }
  }

  Future<void> _onRegisterSubmitted(
    RegisterSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await _authRepository.register(
        event.username,
        event.displayName,
        event.password,
      );
      emit(Authenticated(user));
      _announcer.announce('تم إنشاء الحساب وتسجيل الدخول بنجاح. مرحبًا ${user.displayName}');
    } catch (e) {
      final err = e.toString().replaceAll('Exception: ', '');
      emit(AuthError(err));
      _announcer.announce('فشل إنشاء الحساب: $err', priority: AnnouncePriority.assertive);
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    await _authRepository.logout();
    emit(Unauthenticated());
    _announcer.announce('تم تسجيل الخروج بنجاح');
  }
  Future<void> _onSavedAccountSwitchRequested(SavedAccountSwitchRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _authRepository.switchSavedAccount(event.username);
      final user = _authRepository.currentUser;
      if (user == null) throw Exception('تعذر تسجيل الدخول بالحساب المحفوظ.');
      emit(Authenticated(user));
      _announcer.announce('تم تسجيل الدخول بالحساب ${user.displayName}');
    } catch(e) {
      final err=e.toString().replaceAll('Exception: ','');
      emit(AuthError(err));
      _announcer.announce('تعذر تبديل الحساب: $err', priority: AnnouncePriority.assertive);
    }
  }

}
