import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/accessibility/accessible_widgets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/locale_cubit.dart';
import '../../bloc/auth_bloc.dart';
import '../../../data/repositories/auth_repository.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _loginUsernameController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  final _regUsernameController = TextEditingController();
  final _regDisplayNameController = TextEditingController();
  final _regPasswordController = TextEditingController();

  final _loginFormKey = GlobalKey<FormState>();
  final _regFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _restoreSavedLoginFields();
  }


  Future<void> _restoreSavedLoginFields() async {
    try {
      final repo = context.read<AuthRepository>();
      final accounts = await repo.savedAccounts();
      if (!mounted || accounts.isEmpty) return;
      final active = accounts.firstWhere(
        (a) => a['is_active'] == true,
        orElse: () => accounts.first,
      );
      _loginUsernameController.text = '${active['username'] ?? ''}';
      _loginPasswordController.text = '${active['password'] ?? ''}';
    } catch (_) {}
  }
  @override
  void dispose() {
    _tabController.dispose();
    _loginUsernameController.dispose();
    _loginPasswordController.dispose();
    _regUsernameController.dispose();
    _regDisplayNameController.dispose();
    _regPasswordController.dispose();
    super.dispose();
  }

  void _submitLogin() {
    if (_loginFormKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(LoginSubmitted(
            username: _loginUsernameController.text.trim(),
            password: _loginPasswordController.text,
          ));
    }
  }

  void _submitRegister() {
    if (_regFormKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(RegisterSubmitted(
            username: _regUsernameController.text.trim(),
            displayName: _regDisplayNameController.text.trim(),
            password: _regPasswordController.text,
          ));
    }
  }

  Future<void> _switchAccount() async {
    final repo = context.read<AuthRepository>();
    final accounts = await repo.savedAccounts();
    if (!mounted) return;
    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد حسابات محفوظة على هذا الجهاز.')));
      return;
    }
    final selected = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('تبديل الحساب'),
        content: SizedBox(width: 360, child: ListView(shrinkWrap:true, children:[
          for(final a in accounts) ListTile(
            title: Text('${a['display_name'] ?? a['username'] ?? ''}'),
            subtitle: Text('@${a['username'] ?? ''}'),
            onTap: ()=>Navigator.pop(c,'${a['username'] ?? ''}'),
            trailing: IconButton(
              tooltip: 'حذف الحساب من الجهاز',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await repo.removeSavedAccount('${a['username'] ?? ''}');
                if(c.mounted) Navigator.pop(c);
                if(mounted) setState((){});
              },
            ),
          ),
        ])),
        actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('إغلاق'))],
      ),
    );
    if(selected==null || selected.isEmpty || !mounted) return;
    context.read<AuthBloc>().add(SavedAccountSwitchRequested(selected));
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final localeCubit = context.watch<LocaleCubit>();
    final isAr = localeCubit.state.languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('app.title')),
        centerTitle: true,
        actions: [
          Semantics(
            button: true,
            label: isAr ? 'التبديل إلى اللغة الإنجليزية' : 'Switch to Arabic',
            child: IconButton(
              icon: const Icon(Icons.language),
              tooltip: isAr ? 'English' : 'العربية',
              onPressed: () {
                localeCubit.setLanguage(isAr ? 'en' : 'ar');
              },
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          tabs: [
            Tab(text: loc.translate('auth.login')),
            Tab(text: loc.translate('auth.register')),
          ],
        ),
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is AuthLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('جاري التحقق...'),
                ],
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              // Login Tab
              SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _loginFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AccessibleHeader(loc.translate('auth.login')),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _loginUsernameController,
                        decoration: InputDecoration(
                          labelText: loc.translate('auth.username'),
                          prefixIcon: const Icon(Icons.person),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().length < 2) ? 'اسم المستخدم غير صالح' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _loginPasswordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: loc.translate('auth.password'),
                          prefixIcon: const Icon(Icons.lock),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'يرجى إدخال كلمة المرور' : null,
                      ),
                      const SizedBox(height: 24),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.switch_account),
                        label: const Text('تبديل الحساب (الحسابات المحفوظة)'),
                        onPressed: _switchAccount,
                      ),

                      AccessibleButton(
                        label: loc.translate('auth.login'),
                        onPressed: _submitLogin,
                        icon: Icons.login,
                      ),
                    ],
                  ),
                ),
              ),

              // Register Tab
              SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _regFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AccessibleHeader(loc.translate('auth.register')),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _regUsernameController,
                        decoration: InputDecoration(
                          labelText: loc.translate('auth.username'),
                          prefixIcon: const Icon(Icons.person_outline),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().length < 2) ? 'يجب أن يكون حرفين على الأقل' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _regDisplayNameController,
                        decoration: InputDecoration(
                          labelText: loc.translate('auth.displayName'),
                          prefixIcon: const Icon(Icons.badge_outlined),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().length < 2) ? 'يجب أن يكون حرفين على الأقل' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _regPasswordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: loc.translate('auth.password'),
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v == null || v.length < 8) ? 'كلمة المرور 8 أحرف على الأقل' : null,
                      ),
                      const SizedBox(height: 24),
                      AccessibleButton(
                        label: loc.translate('auth.register'),
                        onPressed: _submitRegister,
                        icon: Icons.app_registration,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
