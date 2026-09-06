import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/accessibility/accessibility_announcer.dart';
import 'core/audio/audio_cubit.dart';
import 'core/audio/sound_engine.dart';
import 'core/audio/table_audio_service.dart';
import 'core/constants/api_endpoints.dart';
import 'core/constants/app_colors.dart';
import 'core/localization/app_localizations_delegate.dart';
import 'core/localization/locale_cubit.dart';
import 'core/localization/localization_service.dart';
import 'core/localization/translation_manager.dart';
import 'core/network/api_client.dart';
import 'core/network/auth_interceptor.dart';
import 'data/datasources/auth_remote_datasource.dart';
import 'data/datasources/room_remote_datasource.dart';
import 'data/datasources/secure_storage_service.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/lobby_ws_service.dart';
import 'data/repositories/room_repository.dart';
import 'data/repositories/room_ws_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/settings/settings_store.dart';
import 'core/notifications/notification_policy.dart';
import 'data/repositories/activity_repository.dart';
import 'data/repositories/social_repository.dart';
import 'presentation/bloc/auth_bloc.dart';
import 'presentation/bloc/lobby_cubit.dart';
import 'presentation/bloc/room_cubit.dart';
import 'presentation/screens/auth/auth_screen.dart';
import 'presentation/screens/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Dynamic Localization Engine
  final translationManager = TranslationManager();
  await translationManager.initialize();

  // 2. Load persistent settings before initializing audio so the first
  // playback already uses the same settings as the Windows client.
  final prefs = await SharedPreferences.getInstance();
  final settingsStore = SettingsStore(prefs);
  final soundEngine = SoundEngine();
  await soundEngine.initialize(prefs: prefs);

  // 3. Initialize Accessibility Announcer
  final announcer = StandardAccessibilityAnnouncer();

  // 4. Initialize Storage & Network
  final storageService = SecureStorageService();
  final authInterceptor = AuthInterceptor(tokenProvider: () => storageService.getAccessToken());
  final apiClient = DioApiClient(
    baseUrl: ApiEndpoints.defaultHttpHost,
    interceptors: [authInterceptor],
  );

  // 5. Data Sources & Repositories
  final authDataSource = AuthRemoteDataSource(client: apiClient);
  final authRepository = AuthRepositoryImpl(
    remoteDataSource: authDataSource,
    storageService: storageService,
    settings: settingsStore,
  );

  final roomDataSource = RoomRemoteDataSource(client: apiClient);
  final roomRepository = RoomRepositoryImpl(remoteDataSource: roomDataSource);

  final roomWsService = RoomWsServiceImpl();
  final lobbyWsService = LobbyWsServiceImpl();
  final socialRepository = SocialRepository(client: apiClient);
  final activityRepository = ActivityRepository(client: apiClient);

  runApp(LetsFlyApp(
    localizationService: translationManager,
    audioService: soundEngine,
    announcer: announcer,
    authRepository: authRepository,
    roomRepository: roomRepository,
    roomWsService: roomWsService,
    lobbyWsService: lobbyWsService,
    socialRepository: socialRepository,
    activityRepository: activityRepository,
    settingsStore: settingsStore,
    notificationPolicy: NotificationPolicy(settings: settingsStore, announcer: announcer, audio: soundEngine),
  ));
}

/// Root Application Widget with RepositoryProvider, MultiBlocProvider, and Dynamic RTL/LTR Rebuild.
class LetsFlyApp extends StatelessWidget {
  final LocalizationService localizationService;
  final TableAudioService audioService;
  final AccessibilityAnnouncer announcer;
  final AuthRepository authRepository;
  final RoomRepository roomRepository;
  final RoomWsService roomWsService;
  final LobbyWsService lobbyWsService;
  final SocialRepository socialRepository;
  final ActivityRepository activityRepository;
  final SettingsStore settingsStore;
  final NotificationPolicy notificationPolicy;

  const LetsFlyApp({
    super.key,
    required this.localizationService,
    required this.audioService,
    required this.announcer,
    required this.authRepository,
    required this.roomRepository,
    required this.roomWsService,
    required this.lobbyWsService,
    required this.socialRepository,
    required this.activityRepository,
    required this.settingsStore,
    required this.notificationPolicy,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<LocalizationService>.value(value: localizationService),
        RepositoryProvider<TableAudioService>.value(value: audioService),
        RepositoryProvider<AccessibilityAnnouncer>.value(value: announcer),
        RepositoryProvider<AuthRepository>.value(value: authRepository),
        RepositoryProvider<RoomRepository>.value(value: roomRepository),
        RepositoryProvider<RoomWsService>.value(value: roomWsService),
        RepositoryProvider<LobbyWsService>.value(value: lobbyWsService),
        RepositoryProvider<SocialRepository>.value(value: socialRepository),
        RepositoryProvider<ActivityRepository>.value(value: activityRepository),
        RepositoryProvider<SettingsStore>.value(value: settingsStore),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<LocaleCubit>(
            create: (_) => LocaleCubit(localizationService),
          ),
          BlocProvider<AudioCubit>(
            create: (_) => AudioCubit(audioService, settings: settingsStore),
          ),
          BlocProvider<AuthBloc>(
            create: (_) => AuthBloc(
              authRepository: authRepository,
              announcer: announcer,
              settings: settingsStore,
            )..add(AuthCheckRequested()),
          ),
          BlocProvider<LobbyCubit>(
            create: (_) => LobbyCubit(
              roomRepository: roomRepository,
              lobbyWsService: lobbyWsService,
              authRepository: authRepository,
              announcer: announcer,
              activityRepository: activityRepository,
            ),
          ),
          BlocProvider<RoomCubit>(
            create: (_) => RoomCubit(
              roomRepository: roomRepository,
              roomWsService: roomWsService,
              authRepository: authRepository,
              audioService: audioService,
              announcer: announcer,
              notificationPolicy: notificationPolicy,
              settingsStore: settingsStore,
            ),
          ),
        ],
        child: BlocBuilder<LocaleCubit, LocaleState>(
          builder: (context, localeState) {
            return MaterialApp(
              title: "Let's Fly",
              debugShowCheckedModeBanner: false,
              locale: localeState.locale,
              supportedLocales: const [
                Locale('ar'),
                Locale('en'),
              ],
              localizationsDelegates: [
                AppLocalizationsDelegate(localizationService),
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) {
                return Directionality(
                  textDirection: localeState.textDirection,
                  child: child ?? const SizedBox.shrink(),
                );
              },
              theme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.dark,
                colorScheme: const ColorScheme.dark(
                  primary: AppColors.primary,
                  secondary: AppColors.accent,
                  surface: AppColors.surface,
                  error: AppColors.error,
                ),
                scaffoldBackgroundColor: AppColors.background,
                appBarTheme: const AppBarTheme(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.textPrimary,
                  elevation: 0,
                ),
              ),
              home: BlocBuilder<AuthBloc, AuthState>(
                builder: (context, authState) {
                  if (authState is Authenticated) {
                    return const HomeScreen();
                  }
                  if (authState is AuthLoading) {
                    return const Scaffold(
                      body: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: AppColors.primary),
                            SizedBox(height: 16),
                            Text('جاري التحميل...'),
                          ],
                        ),
                      ),
                    );
                  }
                  return const AuthScreen();
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
