import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocale {
  static const Locale english = Locale('en');
  static const Locale arabic = Locale('ar');

  static Locale get initialLocale => arabic;

  static bool isArabic(Locale locale) => locale.languageCode == 'ar';
}

class LocaleService extends ChangeNotifier {
  Locale _currentLocale = AppLocale.initialLocale;
  Locale get currentLocale => _currentLocale;
  bool get isArabic => AppLocale.isArabic(_currentLocale);

  Future<void> loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('language');
    if (saved != null) {
      // The user picked a language explicitly — honour it.
      _currentLocale = Locale(saved);
    } else {
      // First launch: follow the device language. We only support en/ar, so
      // an Arabic phone starts in Arabic, anything else starts in English.
      final deviceLang =
          WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      _currentLocale =
          deviceLang == 'ar' ? AppLocale.arabic : AppLocale.english;
    }
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    if (_currentLocale == locale) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', locale.languageCode);
    _currentLocale = locale;
    notifyListeners();
  }
}

class ThemeService extends ChangeNotifier {
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  Future<void> loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool('dark_mode');
    // First launch (no saved choice): follow the device theme. Once the user
    // flips the Dark Mode switch their choice is persisted and wins.
    _isDarkMode = saved ??
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', _isDarkMode);
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode == value) return;
    _isDarkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', _isDarkMode);
    notifyListeners();
  }
}

class AppColors {
  static const Color backgroundDark = Color(0xFF0A0E1A);
  static const Color surfaceDark = Color(0xFF131A2E);
  static const Color primary = Color(0xFF2563EB);
  static const Color secondary = Color(0xFF06B6D4);
  static const Color successGreen = Color(0xFF10B981);

  static const Color primaryPink = primary;
  static const Color primaryPurple = secondary;

  // A clear cool-grey (not near-white) so white [surfaceLight] cards have a
  // visible edge against the background in light theme.
  static const Color backgroundLight = Color(0xFFEAEEF4);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color textPrimaryDark = Colors.white;
  static const Color textPrimaryLight = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6C757D);
  static const Color textSecondaryLight = Color(0xFF6C757D);

  static const LinearGradient mainGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Color background(bool isDark) =>
      isDark ? backgroundDark : backgroundLight;
  static Color surface(bool isDark) => isDark ? surfaceDark : surfaceLight;
  static Color textPrimary(bool isDark) =>
      isDark ? textPrimaryDark : textPrimaryLight;
  static Color textSecondaryColor(bool isDark) =>
      isDark ? textSecondary : textSecondaryLight;
}

class AppTranslations {
  static final Map<String, Map<String, String>> _translations = {
    'en': {
      'app_name': 'Omni Parking',
      'dashboard': 'Dashboard',
      'cars': 'Cars',
      'available_spots': 'Available',
      'revenue': 'Revenue',
      'recent_activity': 'Recent Activity',
      'show_all': 'Show All',
      'filter': 'Filter',
      'parking_empty': 'Parking is empty',
      'tap_to_start': 'scan a plate to add a car',
      'car_entry': 'Car Entry',
      'scan_plate': 'Scan Plate',
      'manual_entry': 'Manual Entry',
      'auto_scan': 'Auto Scan',
      'use_camera': 'Use camera to detect plate',
      'enter_manually': 'Enter Manually',
      'enter_plate': 'Enter plate number',
      'enter_plate_manually': 'Enter Plate Manually',
      'car_exit': 'Car Exit',
      'scan_to_checkout': 'Scan plate to check out',
      'car_not_found': 'No parked car matches this plate',
      'plate_hint': 'A B C 1234',
      'continue_btn': 'Continue',
      'settings': 'Settings',
      'general': 'General',
      'language': 'Language',
      'dark_mode': 'Dark Mode',
      'camera_scanner': 'Camera & Scanner',
      'default_camera': 'Default Camera',
      'rear_camera': 'Rear Camera',
      'front_camera': 'Front Camera',
      'flash_mode': 'Flash Mode',
      'scan_delay': 'Scan Delay',
      'payment': 'Payment',
      'payment_method': 'Payment Method',
      'hourly_rate': 'Hourly Rate',
      'history': 'History',
      'help_support': 'Help & Support',
      'about': 'About',
      'select_language': 'Select Language',
      'select_camera': 'Select Camera',
      'select_payment': 'Payment Method',
      'scan_plate_title': 'Scan Plate',
      'point_camera': 'Point camera at plate',
      'plate_detected': 'Plate Detected',
      'rescan': 'Rescan',
      'confirm_entry': 'Confirm Entry',
      'choose_zone': 'Choose Zone',
      'check_in': 'Check In',
      'check_out': 'Check Out',
      'entry_time': 'Entry Time',
      'exit_time': 'Exit Time',
      'zone': 'Zone',
      'check_in_success': 'Check-in successful',
      'check_out_success': 'Check-out successful',
      'confirm': 'Confirm',
      'cancel': 'Cancel',
      'done': 'Done',
      'from_gallery': 'From Gallery',
      'no_plate_found': 'No plate found',
      'loading': 'Loading...',
      'version': 'Version',
      'all_rights': '© 2024 All Rights Reserved',
      'cash': 'Cash',
      'card': 'Card',
      'seconds': 'seconds',
      'sar_hour': 'SAR/hour',
      'search_plates': 'Search plates...',
      'entry_complete': 'Entry Complete',
      'parking_system': 'License Plate Recognition',
      'light_mode': 'Light Mode',
      'arabic': 'Arabic',
      'english': 'English',
      'entry_ticket': 'Entry Ticket',
      'checkout_ticket': 'Checkout Ticket',
      'plate_number': 'Plate Number',
      'entry_date': 'Entry Date',
      'exit_date': 'Exit Date',
      'duration': 'Duration',
      'total_fee': 'Total Fee',
      'plate_required': 'Plate number is required',
      'plate_digit_error': 'Plate must have 3 or 4 digits',
      'plate_letter_error': 'Plate must have 2 or 3 valid Arabic letters',
      'plate_format_error': 'Plate must be digits followed by Arabic letters',
      'plate_invalid': 'Invalid plate format',
      'plate_duplicate': 'Plate already exists',
      'confidence_label': 'Confidence: ',
      'duplicate_session_msg': 'An active session exists in zone',
      'flash_error': 'Cannot toggle flash: ',
      'no_other_camera': 'No other camera available',
      'camera_switch_error': 'Camera switch error: ',
      'error': 'Error: ',
      'loading_camera': 'Loading camera...',
      'auto_scanning': 'Auto scanning...',
      'scanning': 'Scanning...',
      'open_camera': 'Open Camera',
      'preparing_scanner': 'Preparing scanner…',
      'garage': 'Garage',
      'egp_hour': 'EGP/hr',
      'manage_zones': 'Manage Garage',
      'garage_layout': 'Garage Layout',
      'garage_setup': 'Set Up Your Garage',
      'setup_title': 'Build your garage',
      'setup_subtitle': 'Add zones and set how many slots each one has.',
      'add_zone': 'Add Zone',
      'zone_name': 'Zone name',
      'slots': 'Slots',
      'remove_zone': 'Remove zone',
      'finish': 'Finish',
      'save': 'Save',
      'total_slots': 'total slots',
      'garage_saved': 'Garage updated',
      'garage_save_error': 'Could not save — please try again',
      'need_at_least_one_zone': 'Add at least one zone with a name and slots',
      'zone_has_parked_cars': 'Check out the cars first in zone',
      'no_garage_title': 'Set up your garage',
      'no_garage_msg':
          'You haven\'t added any zones yet. Create your garage layout to start parking cars.',
      'set_up_now': 'Set Up Garage',
      'rate_updated': 'Rate updated',
      'clean_history': 'Clean History',
      'auto_delete': 'Auto-delete completed sessions',
      'never': 'Never',
      'after_7_days': 'After 7 days',
      'after_30_days': 'After 30 days',
      'after_90_days': 'After 90 days',
      'history_cleaned': 'History cleaned',
      'enter_rate': 'Enter hourly rate (EGP)',
      'low_confidence_title': 'Not sure about this plate',
      'low_confidence_msg': 'Please check the plate and correct it if needed',
      'numbers_label': 'Numbers',
      'letters_label': 'Letters',
      'try_again': 'Try Again',
      'processing': 'Processing...',
      'align_plate_hint': 'Align the car license plate inside the frame',
      'flash_off': 'Off',
      'flash_on': 'On',
      'flash_auto': 'Auto',
      'flash_torch': 'Torch',
      'zoom_label': 'Zoom',
      'gallery': 'Gallery',
      'flip': 'Flip',
      'payment_qr': 'Payment QR',
      'payment_qr_set': 'Configured',
      'payment_qr_none': 'Not set',
      'payment_qr_hint': 'Shown to customers at checkout for online payment.',
      'choose_from_gallery': 'Choose from gallery',
      'remove': 'Remove',
      'qr_updated': 'Payment QR updated',
      'qr_removed': 'Payment QR removed',
      'scan_to_pay': 'Scan to pay',
      'available_zones': 'Available Zones',
      'confirm_zone': 'Confirm Zone ',
      'zone_label': 'Zone ',
      'check_in_failed_duplicate': 'Check-in failed — session already exists',
      'garage_full': 'Garage is full — no available spots',
      'check_in_error': 'Check-in failed — please try again',
      'today': 'Today',
      'all': 'All',
      'no_transactions': 'No transactions',
      'transactions': 'Transactions',
      'avg_duration': 'Avg Duration',
      'active': 'Active',
      'completed': 'Completed',
      'search_by_plate': 'Search by plate...',
      'no_active_sessions': 'No active sessions',
      'confirm_checkout': 'Confirm Checkout - ',
      'confirm_payment': 'Confirm Payment',
      'amount_due': 'Amount Due',
      'awaiting_payment': 'Awaiting payment',
      'spots_label': ' spots',
      'search_hint': 'Search here...',
      'hours_short': 'h',
      'egp': 'EGP',
      'customize_experience': 'Customize your experience',
      'smart_parking_solution': 'Smart Parking Solution',
      'close': 'Close',
      'ai_scanner': 'AI Scanner',
      'qr_ticket': 'QR Ticket',
      'zones': 'Zones',
      'checkout_success': 'Checkout successful',
      'time_am': 'AM',
      'time_pm': 'PM',
    },
    'ar': {
      'app_name': 'Omni Parking',
      'dashboard': 'لوحة التحكم',
      'cars': 'السيارات',
      'available_spots': 'المتاح',
      'revenue': 'الإيرادات',
      'recent_activity': 'النشاط الأخير',
      'show_all': 'عرض الكل',
      'filter': 'تصفية',
      'parking_empty': 'الجراج فارغ حالياً',
      'tap_to_start': 'امسح لوحة لإضافة سيارة',
      'car_entry': 'دخول سيارة',
      'scan_plate': 'مسح اللوحة',
      'manual_entry': 'إدخال يدوي',
      'auto_scan': 'مسح تلقائي',
      'use_camera': 'استخدم الكاميرا للتعرف على اللوحة',
      'enter_manually': 'أدخل يدوياً',
      'enter_plate': 'أدخل رقم اللوحة',
      'enter_plate_manually': 'أدخل اللوحة يدوياً',
      'car_exit': 'خروج سيارة',
      'scan_to_checkout': 'امسح اللوحة لتسجيل الخروج',
      'car_not_found': 'لا توجد سيارة مركونة بهذه اللوحة',
      'plate_hint': 'أ ب ج 1234',
      'continue_btn': 'متابعة',
      'settings': 'الإعدادات',
      'general': 'عام',
      'language': 'اللغة',
      'dark_mode': 'الوضع الداكن',
      'camera_scanner': 'الكاميرا والماسح',
      'default_camera': 'الكاميرا الافتراضية',
      'rear_camera': 'الكاميرا الخلفية',
      'front_camera': 'الكاميرا الأمامية',
      'flash_mode': 'وضع الفلاش',
      'scan_delay': 'تأخير المسح',
      'payment': 'الدفع',
      'payment_method': 'طريقة الدفع',
      'hourly_rate': 'السعر لكل ساعة',
      'history': 'السجل',
      'help_support': 'المساعدة والدعم',
      'about': 'حول',
      'select_language': 'اختر اللغة',
      'select_camera': 'اختر الكاميرا',
      'select_payment': 'طريقة الدفع',
      'scan_plate_title': 'مسح اللوحة',
      'point_camera': 'وجّه الكاميرا نحو اللوحة',
      'plate_detected': 'تم التعرف على اللوحة',
      'rescan': 'إعادة المسح',
      'confirm_entry': 'تأكيد الدخول',
      'choose_zone': 'اختر المنطقة',
      'check_in': 'تسجيل دخول',
      'check_out': 'تسجيل خروج',
      'entry_time': 'وقت الدخول',
      'exit_time': 'وقت الخروج',
      'zone': 'المنطقة',
      'check_in_success': 'تم تسجيل الدخول بنجاح',
      'check_out_success': 'تم تسجيل الخروج بنجاح',
      'confirm': 'تأكيد',
      'cancel': 'إلغاء',
      'done': 'تم',
      'from_gallery': 'من المعرض',
      'no_plate_found': 'لم يتم التعرف على لوحة',
      'loading': 'جاري التحميل...',
      'version': 'الإصدار',
      'all_rights': '© 2024 جميع الحقوق محفوظة',
      'cash': 'نقدي',
      'card': 'بطاقة',
      'seconds': 'ثواني',
      'sar_hour': 'ريال/ساعة',
      'search_plates': 'ابحث عن اللوحات...',
      'entry_complete': 'اكتمل الدخول',
      'parking_system': 'نظام التعرف على اللوحات',
      'light_mode': 'الوضع الفاتح',
      'arabic': 'العربية',
      'english': 'English',
      'entry_ticket': 'تذكرة الدخول',
      'checkout_ticket': 'تذكرة الخروج',
      'plate_number': 'رقم اللوحة',
      'entry_date': 'تاريخ الدخول',
      'exit_date': 'تاريخ الخروج',
      'duration': 'المدة',
      'total_fee': 'الإجمالي',
      'plate_required': 'رقم اللوحة مطلوب',
      'plate_digit_error': 'يجب أن تحتوي اللوحة على 3 أو 4 أرقام',
      'plate_letter_error': 'يجب أن تحتوي اللوحة على 2 أو 3 أحرف عربية صحيحة',
      'plate_format_error': 'اللوحة يجب أن تتكون من أرقام متبوعة بأحرف عربية',
      'plate_invalid': 'صيغة اللوحة غير صحيحة',
      'plate_duplicate': 'رقم اللوحة موجود مسبقاً',
      'confidence_label': 'نسبة الثقة: ',
      'duplicate_session_msg': 'توجد جلسة نشطة لهذه اللوحة في المنطقة',
      'flash_error': 'لا يمكن تشغيل الفلاش: ',
      'no_other_camera': 'لا توجد كاميرا أخرى',
      'camera_switch_error': 'خطأ في تبديل الكاميرا: ',
      'error': 'خطأ: ',
      'loading_camera': 'جاري تحميل الكاميرا...',
      'auto_scanning': 'المسح التلقائي...',
      'scanning': 'جاري المسح...',
      'open_camera': 'فتح الكاميرا',
      'preparing_scanner': 'جارٍ تجهيز الماسح…',
      'garage': 'الجراج',
      'egp_hour': 'جنيه/ساعة',
      'manage_zones': 'إدارة الجراج',
      'garage_layout': 'تخطيط الجراج',
      'garage_setup': 'إعداد الجراج',
      'setup_title': 'أنشئ الجراج الخاص بك',
      'setup_subtitle': 'أضف المناطق وحدد عدد الأماكن في كل منطقة.',
      'add_zone': 'إضافة منطقة',
      'zone_name': 'اسم المنطقة',
      'slots': 'الأماكن',
      'remove_zone': 'حذف المنطقة',
      'finish': 'إنهاء',
      'save': 'حفظ',
      'total_slots': 'إجمالي الأماكن',
      'garage_saved': 'تم تحديث الجراج',
      'garage_save_error': 'تعذّر الحفظ — حاول مرة أخرى',
      'need_at_least_one_zone': 'أضف منطقة واحدة على الأقل باسم وأماكن',
      'zone_has_parked_cars': 'أخرج السيارات أولاً من منطقة',
      'no_garage_title': 'قم بإعداد الجراج',
      'no_garage_msg':
          'لم تقم بإضافة أي مناطق بعد. أنشئ تخطيط الجراج لبدء ركن السيارات.',
      'set_up_now': 'إعداد الجراج',
      'rate_updated': 'تم تحديث السعر',
      'clean_history': 'مسح السجل',
      'auto_delete': 'حذف الجلسات المكتملة تلقائياً',
      'never': 'أبداً',
      'after_7_days': 'بعد 7 أيام',
      'after_30_days': 'بعد 30 يوماً',
      'after_90_days': 'بعد 90 يوماً',
      'history_cleaned': 'تم مسح السجل',
      'enter_rate': 'أدخل السعر بالساعة (جنيه)',
      'low_confidence_title': 'غير متأكد من هذه اللوحة',
      'low_confidence_msg': 'يرجى التحقق من اللوحة وتصحيحها إذا لزم الأمر',
      'numbers_label': 'الأرقام',
      'letters_label': 'الحروف',
      'try_again': 'حاول مرة أخرى',
      'processing': 'جاري المعالجة...',
      'align_plate_hint': 'ضع لوحة ارقام السيارة داخل الإطار',
      'flash_off': 'إيقاف',
      'flash_on': 'تشغيل',
      'flash_auto': 'تلقائي',
      'flash_torch': 'مصباح',
      'zoom_label': 'تكبير',
      'gallery': 'المعرض',
      'flip': 'قلب',
      'payment_qr': 'رمز الدفع',
      'payment_qr_set': 'مُفعّل',
      'payment_qr_none': 'غير مُعد',
      'payment_qr_hint': 'يُعرض للعملاء عند الخروج للدفع الإلكتروني.',
      'choose_from_gallery': 'اختر من المعرض',
      'remove': 'إزالة',
      'qr_updated': 'تم تحديث رمز الدفع',
      'qr_removed': 'تمت إزالة رمز الدفع',
      'scan_to_pay': 'امسح للدفع',
      'available_zones': 'المناطق المتاحة',
      'confirm_zone': 'تأكيد المنطقة ',
      'zone_label': 'المنطقة ',
      'check_in_failed_duplicate': 'فشل تسجيل الدخول - الجلسة موجودة مسبقاً',
      'garage_full': 'الجراج ممتلئ — لا توجد أماكن متاحة',
      'check_in_error': 'فشل تسجيل الدخول — حاول مرة أخرى',
      'today': 'اليوم',
      'all': 'الكل',
      'no_transactions': 'لا توجد معاملات',
      'transactions': 'المعاملات',
      'avg_duration': 'متوسط المدة',
      'active': 'نشط',
      'completed': 'مكتمل',
      'search_by_plate': 'ابحث عن لوحة السيارة...',
      'no_active_sessions': 'لا توجد جلسات نشطة',
      'confirm_checkout': 'تأكيد الخروج - ',
      'confirm_payment': 'تأكيد الدفع',
      'amount_due': 'المبلغ المستحق',
      'awaiting_payment': 'بانتظار الدفع',
      'spots_label': ' مكان',
      'search_hint': 'ابحث هنا...',
      'hours_short': 'س',
      'egp': 'ج.م',
      'customize_experience': 'خصص تجربتك',
      'smart_parking_solution': 'حل ذكي للجراج',
      'close': 'إغلاق',
      'ai_scanner': 'الماسح الذكي',
      'qr_ticket': 'تذكرة QR',
      'zones': 'المناطق',
      'checkout_success': 'تم تسجيل الخروج بنجاح',
      'time_am': 'ص',
      'time_pm': 'م',
    },
  };

  static String translate(String key, Locale locale) {
    final lang = locale.languageCode;
    return _translations[lang]?[key] ?? _translations['en']![key] ?? key;
  }
}

String tr(BuildContext context, String key) {
  final locale = Localizations.localeOf(context);
  return AppTranslations.translate(key, locale);
}

/// True if two timestamps fall on the same calendar day.
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Formats a canonical plate ("3269مجع") for display. Arabic letters are spaced
/// apart so they render as separate plate glyphs instead of a connected word:
/// "3269مجع" → "3269 م ج ع". Digits stay grouped; letter order is unchanged
/// (already reversed to RTL plate order in the OCR decoder).
String displayPlate(String canonical) {
  final m = RegExp(r'^(\d*)(.*)$').firstMatch(canonical);
  final digits = m?.group(1) ?? '';
  final letters = (m?.group(2) ?? '').trim().split('').join(' ');
  final text = digits.isEmpty
      ? letters
      : letters.isEmpty
          ? digits
          : '$digits $letters';
  // Force LTR (LRI … PDI) so the plate reads identically in Arabic (RTL) UI —
  // digits then spaced letters, never reordered by the surrounding direction.
  return '${String.fromCharCode(0x2066)}$text${String.fromCharCode(0x2069)}';
}

/// App-wide date format: dd/mm/yyyy.
String formatDate(DateTime t) =>
    '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}/${t.year}';

/// App-wide time format: 12-hour with a localized AM/PM suffix
/// ("14:05" → "2:05 PM" / "2:05 م").
String formatTime(BuildContext context, DateTime t) {
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final minute = t.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${tr(context, t.hour < 12 ? 'time_am' : 'time_pm')}';
}

/// Wraps [s] in Unicode isolate marks so a value whose script may differ from
/// the surrounding text — e.g. an Arabic zone name embedded in an otherwise LTR
/// "Zone X - 7:05 PM" line — renders as a self-contained unit instead of
/// reordering the digits/label/time around it.
/// (U+2068 First Strong Isolate ... U+2069 Pop Directional Isolate.)
String bidiIsolate(String s) =>
    '${String.fromCharCode(0x2068)}$s${String.fromCharCode(0x2069)}';
