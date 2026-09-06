import 'dart:ui';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'localization_service.dart';

/// Immutable state for LocaleCubit.
class LocaleState extends Equatable {
  final Locale locale;
  final TextDirection textDirection;

  const LocaleState({
    required this.locale,
    required this.textDirection,
  });

  String get languageCode => locale.languageCode;
  bool get isRtl => textDirection == TextDirection.rtl;

  @override
  List<Object?> get props => [locale, textDirection];
}

/// Cubit managing dynamic runtime language and directionality changes.
class LocaleCubit extends Cubit<LocaleState> {
  final LocalizationService _localizationService;

  LocaleCubit(this._localizationService)
      : super(LocaleState(
          locale: _localizationService.currentLocale,
          textDirection: _localizationService.textDirection,
        )) {
    _localizationService.localeStream.listen((newLocale) {
      emit(LocaleState(
        locale: newLocale,
        textDirection: _localizationService.textDirection,
      ));
    });
  }

  /// Change active language ('ar' or 'en') dynamically.
  Future<void> setLanguage(String langCode) async {
    await _localizationService.setLanguage(langCode);
    emit(LocaleState(
      locale: _localizationService.currentLocale,
      textDirection: _localizationService.textDirection,
    ));
  }

  /// Toggle between Arabic and English.
  Future<void> toggleLanguage() async {
    final nextLang = state.languageCode == 'ar' ? 'en' : 'ar';
    await setLanguage(nextLang);
  }
}
