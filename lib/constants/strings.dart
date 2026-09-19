class AppStrings {
  static const String appName = 'شركة الحمد للعقارات';
  static const String homeTitle = 'أفضل عقارات في طنطا والقاهرة';
  static const String homeSubtitle = 'نساعدك تلاقي البيت والفرصة الاستثمارية بكل سهولة';
  
  // Form Strings
  static const String nameLabel = 'الاسم الكامل';
  static const String phoneLabel = 'رقم الهاتف';
  static const String cityLabel = 'المحافظة';
  static const String propertyTypeLabel = 'نوع العقار';
  static const String locationLabel = 'المنطقة / الحي';
  static const String budgetLabel = 'الميزانية المتوقعة';
  static const String roomsLabel = 'عدد الغرف';
  static const String purposeLabel = 'الغرض';
  static const String sendButton = 'سجل اهتمامك الآن';
  
  // Cities
  static const List<String> cities = ['الكل', 'طنطا', 'القاهرة'];
  
  // Property Types
  static const List<String> propertyTypes = ['شقة', 'فيلا', 'محل تجاري', 'عمارة كاملة', 'أرض'];

  // Property Statuses
  static const List<String> propertyStatuses = ['متاح', 'تم البيع', 'تم الإيجار', 'حجز مبدئي'];

  // Amenities
  static const List<String> availableAmenities = [
    'مصعد',
    'أمن 24/7',
    'جراج خاص',
    'تشطيب سوبر لوكس',
    'تكييف مركزي',
    'حديقة خاصة',
    'حمام سباحة'
  ];
  
  // Locations grouped by city
  static const List<String> tantaLocations = [
    'الحي الغربي',
    'الحي الشرقي',
    'منطقة الاستاد',
    'وسط البلد',
    'شارع البحر',
    'النحاس',
    'الضواحي'
  ];

  static const List<String> cairoLocations = [
    'التجمع الخامس',
    'الشيخ زايد',
    'المعادي',
    'مدينة نصر',
    'الشروق',
    'العاصمة الإدارية',
    '6 أكتوبر'
  ];

  // Combined Locations for dropdowns
  static const List<String> locations = [
    'الحي الغربي (طنطا)',
    'الحي الشرقي (طنطا)',
    'منطقة الاستاد (طنطا)',
    'شارع البحر (طنطا)',
    'التجمع الخامس (القاهرة)',
    'الشيخ زايد (القاهرة)',
    'المعادي (القاهرة)',
    'مدينة نصر (القاهرة)',
    'العاصمة الإدارية (القاهرة)'
  ];
  
  // Purposes
  static const List<String> purposes = ['سكن شخصي', 'استثمار'];

  // Finishing Categories
  static const List<String> finishingTypes = [
    'سوبر لوكس',
    'نصف تشطيب',
    'ألترا لوكس',
    'بدون تشطيب (طوب أحمر)',
    'تشطيب لوكس',
  ];

  // Default Folder Categories
  static const List<String> defaultFolders = [
    'الكل',
    'طنطا - شارع الاستاد',
    'طنطا - شارع البحر',
    'طنطا - الحي الغربي',
    'القاهرة - التجمع الخامس',
    'القاهرة - الشيخ زايد',
    'فرص لقطة 🔥',
    'إيجار مفروش 🛋️',
  ];
}

