import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/colors.dart';
import '../models/property.dart';
import '../services/supabase_service.dart';

class ChatBotWidget extends StatefulWidget {
  const ChatBotWidget({super.key});

  @override
  State<ChatBotWidget> createState() => _ChatBotWidgetState();
}

class _ChatBotWidgetState extends State<ChatBotWidget> {
  final _supabaseService = SupabaseService();
  final _supabase = Supabase.instance.client;

  final List<Map<String, dynamic>> _messages = [
    {
      'sender': 'bot',
      'text':
          'مرحبًا بك في مساعد شركة الحمد للعقارات الذكي! 🏢✨ كيف يمكنني مساعدتك اليوم؟',
      'options': [
        'بحث عن عقار 🏠',
        'عرض عقاري للبيع 💰',
        'حساب ميزانية وأقساط 🧮',
        'متوسط الأسعار والمواقع 📊',
        'استشارة مباشرة 💬'
      ]
    }
  ];

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Property> _allProperties = [];
  List<String> _fetchedFolders = [];

  Property? _selectedProperty;
  String _userIntent = '';
  String _selectedType = '';
  String _selectedRegion = '';
  String _selectedBudget = '';
  String _sellerArea = '';
  String _sellerPrice = '';
  String _sellerRooms = '';
  bool _isWaitingForPhone = false;
  bool _waitingForSellerArea = false;
  bool _waitingForSellerPrice = false;
  bool _waitingForSellerRooms = false;
  bool _isBotTyping = false;

  /// 🌐 Dynamic Regions generated dynamically from real DB folders and properties
  List<String> get _dynamicRegions {
    final set = <String>{};
    for (var f in _fetchedFolders) {
      if (f != 'الكل' && f.trim().isNotEmpty) {
        set.add(f.trim());
      }
    }
    for (var p in _allProperties) {
      final fName = p.folderName.trim();
      if (fName.isNotEmpty && fName != 'عام') {
        set.add(fName);
      }
    }

    if (set.isEmpty) {
      set.addAll([
        'طنطا - شارع الاستاد',
        'طنطا - شارع البحر',
        'القاهرة - التجمع الخامس'
      ]);
    }

    final list = set.take(6).map((r) => '$r 📍').toList();
    list.add('أي منطقة 🌐');
    return list;
  }

  /// 🏢 Dynamic Property Types generated from DB properties
  List<String> get _dynamicTypes {
    final set = <String>{};
    for (var p in _allProperties) {
      if (p.type.trim().isNotEmpty) {
        set.add(p.type.trim());
      }
    }
    if (set.isEmpty) {
      set.addAll(['شقة سكنية', 'فيلا مستقلة', 'محل تجاري']);
    }
    return set.take(4).map((t) => '$t 🏢').toList();
  }

  @override
  void initState() {
    super.initState();
    _loadPropertiesAndFolders();
  }

  Future<void> _loadPropertiesAndFolders() async {
    try {
      final properties = await _supabaseService.getProperties();
      final folders = await _supabaseService.getFolders();
      if (mounted) {
        setState(() {
          _allProperties = properties;
          _fetchedFolders = folders;
        });
      }
    } catch (e) {
      debugPrint('Error prefetching data for chatbot: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _saveChatLead(String phone) async {
    try {
      final isSellIntent = _userIntent.contains('بيع') ||
          _userIntent.contains('عرض') ||
          _selectedType.contains('بيع');

      String summary;
      String leadName;
      String intentStr;
      String purposeStr;

      if (isSellIntent) {
        leadName = 'عرض عقار للبيع 💰 (مالك)';
        intentStr = 'عرض عقار للبيع';
        purposeStr = 'بيع عقار (مالك)';
        final typeText = _selectedType.isEmpty ? 'شقة / عقار' : _selectedType.replaceAll('🏢', '').trim();
        final regText = _selectedRegion.isEmpty ? 'غير محدد' : _selectedRegion.replaceAll('📍', '').replaceAll('🌐', '').trim();
        summary = 'نوع العقار: $typeText | المنطقة: $regText | المساحة: $_sellerArea | السعر: $_sellerPrice | الغرف: $_sellerRooms';
      } else if (_selectedProperty != null) {
        leadName = 'طلب معاينة: ${_selectedProperty!.title}';
        intentStr = 'حجز معاينة مخصصة';
        purposeStr = 'شراء / معاينة';
        summary =
            'طلب معاينة مخصصة لعقار: ${_selectedProperty!.title} (${_selectedProperty!.location}) - السعر: ${_selectedProperty!.formattedPrice}';
      } else {
        leadName = 'طلب بحث عن عقار (مشتري)';
        intentStr = 'بحث عن عقار';
        purposeStr = 'شراء عقار';
        summary =
            'العميل مهتم بشراء ${_selectedType.isEmpty ? "عقار" : _selectedType} في ${_selectedRegion.isEmpty ? "طنطا/القاهرة" : _selectedRegion} - الميزانية: ${_selectedBudget.isEmpty ? "غير محدد" : _selectedBudget}';
      }

      await _supabase.from('leads').insert({
        'name': leadName,
        'phone': phone,
        'source': isSellIntent ? 'ai_chatbot_sell_property' : 'ai_chatbot_property_booking',
        'form_data': {
          'intent': intentStr,
          'purpose': purposeStr,
          'selected_property_id': _selectedProperty?.id,
          'selected_property_title': _selectedProperty?.title,
          'selected_property_price': _selectedProperty?.price,
          'selected_property_location': _selectedProperty?.location,
          'property_type':
              _selectedType.isEmpty ? _selectedProperty?.type : _selectedType.replaceAll('🏢', '').trim(),
          'region': _selectedRegion.replaceAll('📍', '').replaceAll('🌐', '').trim(),
          'location': _selectedRegion.replaceAll('📍', '').replaceAll('🌐', '').trim(),
          'budget': _selectedBudget,
          'seller_area': _sellerArea,
          'seller_price': _sellerPrice,
          'seller_rooms': _sellerRooms,
          'chat_summary': summary,
        }
      });
      debugPrint('Chat lead saved successfully as $leadName');
    } catch (e) {
      debugPrint('Error saving chat lead: $e');
    }
  }

  Future<void> _launchWhatsApp(String message) async {
    final Uri whatsappUri = Uri.parse(
        "https://wa.me/201014250577?text=${Uri.encodeComponent(message)}");
    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchPhoneCall(String phone) async {
    final Uri phoneUri = Uri.parse("tel:$phone");
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  void _handleOptionClick(String option, Function setModalState) {
    _addMessage('user', option, setModalState);

    if (option.contains('تحدث مع خبير') || option.contains('استشارة مباشرة')) {
      _launchWhatsApp(
          "مرحباً، أريد استشارة عقارية بخصوص العقارات المتاحة في طنطا والقاهرة.");
    } else if (option.contains('إعادة المحادثة') ||
        option.contains('رجوع للبداية') ||
        option.contains('تعديل البحث')) {
      _resetChat(setModalState);
    } else if (option.contains('تصفح كل العقارات')) {
      Navigator.pop(context);
      Navigator.pushNamed(context, '/listings');
    } else if (option.contains('حجز معاينة')) {
      _userIntent = 'حجز معاينة';
      _isWaitingForPhone = true;
      _triggerBotReply(
        'ممتاز جداً! 📅 من فضلك أدخل رقم تليفونك ليصلك كود التنسيق وموعد المعاينة المباشر مع استشاري الموقع:',
        setModalState,
      );
    } else if (option.contains('متوسط الأسعار')) {
      _triggerBotReply(
        '📊 متوسط أسعار المتر حالياً في مناطقنا المسجلة في السيرفر:\n\n• طنطا - شارع الاستاد: 14,000 - 18,000 ج.م/م²\n• طنطا - شارع البحر: 16,000 - 22,000 ج.م/م²\n• طنطا - الحي الغربي: 11,000 - 15,000 ج.م/م²\n• القاهرة - التجمع الخامس: 25,000 - 38,000 ج.م/م²\n\nهل تفضل البحث عن عقار محدد الآن؟',
        setModalState,
        options: ['بحث عن عقار 🏠', 'حساب ميزانية وأقساط 🧮', 'استشارة مباشرة 💬'],
      );
    } else {
      _processResponse(option, setModalState);
    }
  }

  void _resetChat(Function setModalState) {
    setModalState(() {
      _messages.clear();
      _selectedProperty = null;
      _userIntent = '';
      _selectedType = '';
      _selectedRegion = '';
      _selectedBudget = '';
      _sellerArea = '';
      _sellerPrice = '';
      _sellerRooms = '';
      _isWaitingForPhone = false;
      _waitingForSellerArea = false;
      _waitingForSellerPrice = false;
      _waitingForSellerRooms = false;
      _messages.add({
        'sender': 'bot',
        'text': 'أهلاً بك مجدداً! 🌟 كيف يمكنني مساعدتك الآن؟',
        'options': [
          'بحث عن عقار 🏠',
          'عرض عقاري للبيع 💰',
          'حساب ميزانية وأقساط 🧮',
          'متوسط الأسعار والمواقع 📊',
          'استشارة مباشرة 💬'
        ]
      });
    });
    _scrollToBottom();
  }

  void _handleSend(Function setModalState) {
    if (_controller.text.trim().isEmpty) return;
    String text = _controller.text.trim();
    _addMessage('user', text, setModalState);

    _parseFreeTextAndRespond(text, setModalState);

    _controller.clear();
  }

  void _addMessage(String sender, String text, Function setModalState,
      {List<String>? options, List<Property>? properties}) {
    setModalState(() {
      _messages.add({
        'sender': sender,
        'text': text,
        'options': options,
        'properties': properties,
      });
    });
    setState(() {});
    _scrollToBottom();
  }

  void _triggerBotReply(String text, Function setModalState,
      {List<String>? options, List<Property>? properties}) {
    setModalState(() {
      _isBotTyping = true;
    });
    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      setModalState(() {
        _isBotTyping = false;
        _messages.add({
          'sender': 'bot',
          'text': text,
          'options': options,
          'properties': properties,
        });
      });
      setState(() {});
      _scrollToBottom();
    });
  }

  /// 🔤 Arabic text normalizer for accurate fuzzy/exact string matching
  String _normalizeArabic(String text) {
    return text
        .replaceAll(RegExp(r'[أإآ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll(RegExp(r'[^\w\sأ-ي]'), '')
        .toLowerCase()
        .trim();
  }

  /// 🛡️ Dynamic Matching Engine for best property suggestions
  Map<String, dynamic> _findBestProperties() {
    final normType = _normalizeArabic(_selectedType);
    final rawReg = _selectedRegion
        .replaceAll('📍', '')
        .replaceAll('🌐', '')
        .replaceAll('طنطا - ', '')
        .replaceAll('القاهرة - ', '')
        .trim();
    final normReg = _normalizeArabic(rawReg);

    // 1. Budget Parsing
    double minPrice = 0;
    double maxPrice = double.infinity;

    if (_selectedBudget.contains('أقل من 1.5 مليون')) {
      maxPrice = 1600000;
    } else if (_selectedBudget.contains('1.5 إلى 3 مليون')) {
      minPrice = 1400000;
      maxPrice = 3200000;
    } else if (_selectedBudget.contains('أكثر من 3 مليون')) {
      minPrice = 2800000;
    } else if (_selectedBudget.contains('غير محدد')) {
      minPrice = 0;
      maxPrice = double.infinity;
    }

    // 2. Strict Availability: Filter properties where status is 'متاح'
    final availableProperties =
        _allProperties.where((p) => p.status == 'متاح').toList();

    // 3. Exact Search (Type + Region + Budget)
    List<Property> exact = availableProperties.where((p) {
      final normPropType = _normalizeArabic(p.type);
      final normPropLoc = _normalizeArabic(p.location);
      final normPropFolder = _normalizeArabic(p.folderName);
      final normPropCity = _normalizeArabic(p.city);
      final normPropTitle = _normalizeArabic(p.title);

      // Type Match
      bool typeMatch = _selectedType.isEmpty ||
          normType == 'عقار' ||
          normType.contains('بحث') ||
          normPropType.contains(normType) ||
          normType.contains(normPropType) ||
          (normType.contains('شقه') && normPropType.contains('شقه')) ||
          (normType.contains('فيلا') && normPropType.contains('فيلا')) ||
          (normType.contains('محل') && normPropType.contains('محل'));

      // Region Match
      bool regionMatch = _selectedRegion.isEmpty ||
          _selectedRegion.contains('أي منطقة') ||
          normReg.isEmpty ||
          normPropFolder == normReg ||
          normPropFolder.contains(normReg) ||
          normPropLoc.contains(normReg) ||
          normPropCity.contains(normReg) ||
          normPropTitle.contains(normReg);

      // Budget Match
      bool budgetMatch = p.price >= minPrice && p.price <= maxPrice;

      return typeMatch && regionMatch && budgetMatch;
    }).toList();

    if (exact.isNotEmpty) {
      return {'properties': exact.take(4).toList(), 'isExact': true};
    }

    // 4. Intelligent Fallback (Region + Reasonable Budget Margin)
    double fallbackMaxPrice =
        maxPrice == double.infinity ? double.infinity : maxPrice * 1.5;
    // Cap for "less than 1.5M" fallback to avoid showing 10M+ properties
    if (_selectedBudget.contains('أقل من 1.5 مليون')) {
      fallbackMaxPrice = 2500000;
    }

    List<Property> fallback = availableProperties.where((p) {
      final normPropLoc = _normalizeArabic(p.location);
      final normPropFolder = _normalizeArabic(p.folderName);
      final normPropCity = _normalizeArabic(p.city);
      final normPropTitle = _normalizeArabic(p.title);

      // Region Match (Strong preference for region in fallback)
      bool regionMatch = _selectedRegion.isEmpty ||
          _selectedRegion.contains('أي منطقة') ||
          normReg.isEmpty ||
          normPropFolder == normReg ||
          normPropFolder.contains(normReg) ||
          normPropLoc.contains(normReg) ||
          normPropCity.contains(normReg) ||
          normPropTitle.contains(normReg);

      // Budget Margin Check: Never show 12M property for 1.5-3M range
      bool budgetInRange =
          p.price >= (minPrice * 0.8) && p.price <= fallbackMaxPrice;

      return regionMatch && budgetInRange;
    }).toList();

    // Sort fallback by Price Proximity
    double targetPrice =
        (maxPrice == double.infinity) ? minPrice : (minPrice + maxPrice) / 2;
    fallback.sort((a, b) =>
        (a.price - targetPrice).abs().compareTo((b.price - targetPrice).abs()));

    if (fallback.isEmpty && availableProperties.isNotEmpty) {
      // Final fallback: just available in region
      fallback = availableProperties.where((p) {
        final normPropFolder = _normalizeArabic(p.folderName);
        final normPropLoc = _normalizeArabic(p.location);
        return normPropFolder.contains(normReg) || normPropLoc.contains(normReg);
      }).toList();
      fallback.sort((a, b) => (a.price - targetPrice)
          .abs()
          .compareTo((b.price - targetPrice).abs()));
    }

    return {'properties': fallback.take(4).toList(), 'isExact': false};
  }

  /// 🧠 NLP Free-Text Parser & Intent Analyzer
  void _parseFreeTextAndRespond(String input, Function setModalState) {
    String cleanInput = input.trim();

    // --- Enhanced Seller Details Flow ---
    if (_waitingForSellerArea) {
      setModalState(() {
        _sellerArea = cleanInput;
        _waitingForSellerArea = false;
        _waitingForSellerPrice = true;
      });
      _triggerBotReply(
        'ما هو السعر المطلوب لبيع العقار؟ 💰',
        setModalState,
      );
      return;
    }

    if (_waitingForSellerPrice) {
      setModalState(() {
        _sellerPrice = cleanInput;
        _waitingForSellerPrice = false;
        _waitingForSellerRooms = true;
      });
      _triggerBotReply(
        'كم عدد الغرف في العقار؟ 🛏️',
        setModalState,
      );
      return;
    }

    if (_waitingForSellerRooms) {
      setModalState(() {
        _sellerRooms = cleanInput;
        _waitingForSellerRooms = false;
        _isWaitingForPhone = true;
      });
      _triggerBotReply(
        'تمام جداً! 📱 من فضلك أدخل رقم تليفونك لتأكيد الطلب وتواصل مسئول المعاينة والتصوير معك 📸:',
        setModalState,
      );
      return;
    }

    // 1. Phone Input Detection
    String cleanDigits = cleanInput.replaceAll(RegExp(r'\D'), '');
    if (_isWaitingForPhone ||
        (cleanDigits.length >= 10 &&
            (cleanDigits.startsWith('01') || cleanDigits.startsWith('201')))) {
      if (cleanDigits.length >= 10) {
        _saveChatLead(cleanInput);
        final leadCode =
            '#TR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

        final isSell = _userIntent.contains('بيع') || _userIntent.contains('عرض');

        final confirmationText = _selectedProperty != null
            ? 'تم تسجيل طلب المعاينة المباشرة لعقار "${_selectedProperty!.title}" بنجاح! ✅\nرمز المعاينة: $leadCode\nسيقوم مستشارنا بالتواصل معك على الرقم $cleanDigits لتأكيد الموعد ⏱️'
            : (isSell
                ? 'تم تسجيل طلب عرض عقارك للبيع بنجاح! 💰📸\nرمز التنسيق المباشر: $leadCode\nسيقوم فريق المعاينات والتصوير العقاري بالتواصل معك على الرقم $cleanDigits لتنسيق الموعد والتسويق ⏱️'
                : 'تم تسجيل طلبك ومواصفاتك بنجاح! ✅\nرمز التنسيق المباشر: $leadCode\nسيقوم مستشارنا العقاري بالتواصل معك على الرقم $cleanDigits خلال 15 دقيقة للتنسيق ⏱️');

        _triggerBotReply(
          confirmationText,
          setModalState,
          options: ['تصفح كل العقارات 🏠', 'إعادة المحادثة 🔄'],
        );
        _isWaitingForPhone = false;
        return;
      } else if (_isWaitingForPhone) {
        _triggerBotReply(
          'من فضلك أدخل رقم تليفون صحيح مكون من 11 رقم (مثلاً: 01014250577).',
          setModalState,
        );
        return;
      }
    }

    // Detect Sell property intent from free text
    if (cleanInput.contains('بيع') ||
        cleanInput.contains('اعرض') ||
        cleanInput.contains('عندي شقة') ||
        cleanInput.contains('عندي عقار') ||
        cleanInput.contains('حبيت اعرض')) {
      _userIntent = 'عرض بيع';
    }

    // 2. Natural Text Parameter Extraction
    if (cleanInput.contains('شقة') || cleanInput.contains('شقه')) {
      _selectedType = 'شقة';
    } else if (cleanInput.contains('فيلا') || cleanInput.contains('فلا')) {
      _selectedType = 'فيلا';
    } else if (cleanInput.contains('محل') ||
        cleanInput.contains('مكتب') ||
        cleanInput.contains('تجاري')) {
      _selectedType = 'محل';
    }

    for (var reg in _dynamicRegions) {
      String cleanReg = reg.replaceAll('📍', '').replaceAll('🌐', '').trim();
      if (cleanInput.contains(cleanReg)) {
        _selectedRegion = cleanReg;
        break;
      }
    }

    if (cleanInput.contains('مليون') ||
        cleanInput.contains('ملايين') ||
        RegExp(r'\d+').hasMatch(cleanInput)) {
      if (cleanInput.contains('مليون ونص') ||
          cleanInput.contains('1.5') ||
          cleanInput.contains('2') ||
          cleanInput.contains('مليونين')) {
        _selectedBudget = 'من 1.5 إلى 3 مليون';
      } else if (cleanInput.contains('3') ||
          cleanInput.contains('4') ||
          cleanInput.contains('5')) {
        _selectedBudget = 'أكثر من 3 مليون';
      } else {
        _selectedBudget = 'أقل من 1.5 مليون';
      }
    }

    // 3. Question Answering Logic
    if (cleanInput.contains('سعر المتر') ||
        cleanInput.contains('أسعار') ||
        cleanInput.contains('بكم') ||
        cleanInput.contains('بكام')) {
      _triggerBotReply(
        '📊 متوسط أسعار المتر حالياً في مناطقنا المسجلة:\n\n• طنطا - شارع الاستاد: 14,000 - 18,000 ج.م/م²\n• طنطا - شارع البحر: 16,000 - 22,000 ج.م/م²\n• طنطا - الحي الغربي: 11,000 - 15,000 ج.م/م²\n• القاهرة - التجمع الخامس: 25,000 - 38,000 ج.م/م²\n\nهل تفضل البحث عن عقار محدد الآن؟',
        setModalState,
        options: ['بحث عن عقار 🏠', 'حساب ميزانية وأقساط 🧮', 'استشارة مباشرة 💬'],
      );
    } else if (cleanInput.contains('عنوان') ||
        cleanInput.contains('مقر') ||
        cleanInput.contains('مكانكم') ||
        cleanInput.contains('فين')) {
      _triggerBotReply(
        '📍 مقرات شركة الحمد للعقارات:\n\n• فرع طنطا: شارع الاستاد الرئيسي، برج الحمد.\n• فرع القاهرة: التجمع الخامس، شارع التسعين الشمالي.\n\nيشرفنا زيارتك في أي وقت من 10 صباحاً حتى 10 مساءً ☕',
        setModalState,
        options: ['حجز معاينة 📅', 'استشارة مباشرة 💬', 'بحث عن عقار 🏠'],
      );
    } else if (_selectedType.isNotEmpty ||
        _selectedRegion.isNotEmpty ||
        _selectedBudget.isNotEmpty) {
      final res = _findBestProperties();
      final List<Property> matched = res['properties'];
      final bool isExact = res['isExact'];

      if (isExact) {
        _triggerBotReply(
          'فهمت طلبك ممتااااز! 🎯 إليك أفضل العقارات المتاحة المطابقة لمواصفاتك بالظبط:',
          setModalState,
          properties: matched,
          options: ['حجز معاينة 📅', 'استشارة مباشرة 💬', 'إعادة المحادثة 🔄'],
        );
      } else {
        _triggerBotReply(
          'لم نجد عقاراً يطابق طلبك بالسعر والمكان تماماً، ولكن هذه أقرب الفرص المتاحة لميزانيتك في المنطقة 📍',
          setModalState,
          properties: matched,
          options: ['حجز معاينة 📅', 'تعديل البحث 🔄'],
        );
      }
    } else {
      _processResponse(cleanInput, setModalState);
    }
  }

  void _processResponse(String userText, Function setModalState) {
    if (userText.contains('عرض عقاري للبيع')) {
      _userIntent = 'عرض بيع';
      _triggerBotReply(
        'أهلاً بك! 💰 يسعدنا مساعدتك في تسويق عقارك. ما هو نوع العقار المراد بيعه؟',
        setModalState,
        options: _dynamicTypes,
      );
    } else if (userText.contains('بحث عن عقار')) {
      _userIntent = 'بحث';
      _triggerBotReply(
        'ممتاز جداً! 🏢 ما هو نوع العقار الذي تبحث عنه؟',
        setModalState,
        options: _dynamicTypes,
      );
    } else if (_dynamicTypes.any((t) => userText.contains(t.replaceAll('🏢', '').trim())) ||
        userText.contains('شقة') ||
        userText.contains('فيلا') ||
        userText.contains('محل')) {
      _selectedType = userText.replaceAll(RegExp(r'[^\w\sأ-ي]'), '').trim();
      final questionText = (_userIntent == 'عرض بيع' || _userIntent.contains('بيع'))
          ? 'ممتاز! 📍 في أي منطقة/مدينة يقع العقار المراد بيعه؟'
          : 'اختيار رائع! 📍 في أي منطقة تفضل البحث؟';
      _triggerBotReply(
        questionText,
        setModalState,
        options: _dynamicRegions,
      );
    } else if (_dynamicRegions.any((r) => userText.contains(r.replaceAll('📍', '').replaceAll('🌐', '').trim())) ||
        userText.contains('طنطا') ||
        userText.contains('القاهرة') ||
        userText.contains('أي منطقة') ||
        userText.contains('المحطة') ||
        userText.contains('الاستاد') ||
        userText.contains('البحر') ||
        userText.contains('الغربي')) {
      _selectedRegion = userText;
      if (_userIntent == 'عرض بيع' || _userIntent.contains('بيع')) {
        setModalState(() {
          _waitingForSellerArea = true;
        });
        _triggerBotReply(
          'كم تبلغ مساحة العقار التقريبية (بالمتر المربع)؟ 📏',
          setModalState,
        );
      } else {
        _triggerBotReply(
          'تمام جداً! 💵 ما هي الميزانية المناسبة لك؟',
          setModalState,
          options: [
            'أقل من 1.5 مليون 💵',
            'من 1.5 إلى 3 مليون 💰',
            'أكثر من 3 مليون 💎',
            'غير محدد ⚖️'
          ],
        );
      }
    } else if (userText.contains('مليون') || userText.contains('غير محدد')) {
      _selectedBudget = userText;

      final res = _findBestProperties();
      final List<Property> matched = res['properties'];
      final bool isExact = res['isExact'];

      if (isExact) {
        _triggerBotReply(
          'إليك أفضل العقارات المتاحة التي تطابق طلبك بالضبط 🎯:',
          setModalState,
          properties: matched,
          options: ['حجز معاينة 📅', 'استشارة مباشرة 💬', 'إعادة المحادثة 🔄'],
        );
      } else {
        _triggerBotReply(
          'لم نجد عقاراً يطابق طلبك بالسعر والمكان تماماً، ولكن هذه أقرب الفرص المتاحة لميزانيتك في المنطقة 📍',
          setModalState,
          properties: matched,
          options: ['حجز معاينة 📅', 'تصفح كل العقارات 🏠', 'تعديل البحث 🔄'],
        );
      }
    } else if (userText.contains('حساب ميزانية') || userText.contains('أقساط')) {
      _triggerBotReply(
        'نوفر أنظمة سداد مرنة تبدأ من 10% مقدم وتسهيلات تصل إلى 6 سنوات بدون فوائد! 🧮 هل تود التحدث مع خبير تمويل عقاري؟',
        setModalState,
        options: ['حجز معاينة 📅', 'استشارة مباشرة 💬'],
      );
    } else {
      _triggerBotReply(
        'أنا هنا لمساعدتك دائماً! يمكنك استفساري عن الأسعار، أو البحث عن شقة بالمواصفات، أو التحدث مع المستشار مباشراً 👨‍💼',
        setModalState,
        options: [
          'بحث عن عقار 🏠',
          'متوسط الأسعار والمواقع 📊',
          'استشارة مباشرة 💬',
          'إعادة المحادثة 🔄'
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      return FloatingActionButton(
        heroTag: 'chatbot',
        onPressed: () => _showChat(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.smart_toy_rounded, color: Colors.white),
      );
    }

    return FloatingActionButton.extended(
      heroTag: 'chatbot',
      onPressed: () => _showChat(context),
      backgroundColor: AppColors.primary,
      icon: const Icon(Icons.smart_toy_rounded, color: Colors.white),
      label: const Text(
        'المساعد العقاري الذكي',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showChat(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                children: [
                  _buildHeader(context, setModalState),
                  Expanded(child: _buildChatList(setModalState)),
                  _buildInputArea(setModalState),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, Function setModalState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.slateDark, Color(0xFF1E293B)],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withOpacity(0.4)),
            ),
            child: const Icon(Icons.smart_toy_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'مساعد شركة الحمد الذكي 🤖',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 2),
              Row(
                children: [
                  CircleAvatar(radius: 3.5, backgroundColor: AppColors.success),
                  SizedBox(width: 5),
                  Text(
                    'متصل الآن',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.phone_in_talk_rounded,
                color: Colors.white, size: 20),
            tooltip: 'اتصال مباشر',
            onPressed: () => _launchPhoneCall('01014250577'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: Colors.white, size: 20),
            tooltip: 'بدء محادثة جديدة',
            onPressed: () => _resetChat(setModalState),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList(Function setModalState) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length + (_isBotTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isBotTyping && index == _messages.length) {
          return _buildTypingIndicator();
        }
        return _buildMessageItem(_messages[index], setModalState);
      },
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smart_toy_rounded, size: 16, color: AppColors.primary),
            SizedBox(width: 8),
            Text(
              'جاري قراءة البيانات المتاحة في السيرفر...',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 8),
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(
      Map<String, dynamic> message, Function setModalState) {
    bool isUser = message['sender'] == 'user';
    List<String>? options = message['options'];
    List<Property>? properties = message['properties'];

    return Column(
      crossAxisAlignment:
          isUser ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Align(
          alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(14),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.8),
            decoration: BoxDecoration(
              color: isUser ? AppColors.slateDark : Colors.white,
              border: isUser
                  ? null
                  : Border.all(color: const Color(0xFFE2E8F0), width: 1),
              borderRadius: BorderRadius.circular(18).copyWith(
                bottomLeft: isUser ? Radius.zero : const Radius.circular(18),
                bottomRight: isUser ? const Radius.circular(18) : Radius.zero,
              ),
              boxShadow: isUser
                  ? null
                  : [
                      const BoxShadow(
                        color: Color(0x08000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
            ),
            child: Text(
              message['text'],
              style: TextStyle(
                color: isUser ? Colors.white : AppColors.textPrimary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ),
        if (!isUser && properties != null && properties.isNotEmpty)
          _buildPropertyCarousel(properties, setModalState),
        if (!isUser && options != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: options
                  .map(
                    (opt) => ActionChip(
                      label: Text(
                        opt,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      backgroundColor: Colors.white,
                      elevation: 1,
                      onPressed: () => _handleOptionClick(opt, setModalState),
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(
                            color: AppColors.primary, width: 1.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildPropertyCarousel(List<Property> props, Function setModalState) {
    return Container(
      height: 245,
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: props.length,
        itemBuilder: (context, idx) {
          final prop = props[idx];
          return Container(
            width: 230,
            margin: const EdgeInsets.only(left: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0C000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                      child: Image.network(
                        prop.mainImage,
                        height: 100,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 100,
                          color: const Color(0xFFF1F5F9),
                          child: const Icon(Icons.apartment_rounded,
                              color: AppColors.textMuted),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          prop.type,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prop.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${prop.location} • ${prop.formattedArea}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        prop.formattedPrice,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                Navigator.pop(context); // close chat modal
                                Navigator.pushNamed(
                                    context, '/property_details',
                                    arguments: prop);
                              },
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: const Text(
                                  'التفاصيل 👈',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 2,
                            child: InkWell(
                              onTap: () {
                                _selectedProperty = prop;
                                _userIntent = 'حجز معاينة مخصصة';
                                _isWaitingForPhone = true;

                                _addMessage(
                                  'user',
                                  'أرغب في حجز معاينة لعقار: ${prop.title} (${prop.formattedPrice}) 📅',
                                  setModalState,
                                );

                                _triggerBotReply(
                                  'اختيار ممتااااز! 🌟 تم تحديد (${prop.title} - ${prop.location}) لحجز المعاينة.\nمن فضلك أدخل رقم تليفونك لتأكيد موعد الزيارة 📱:',
                                  setModalState,
                                );
                              },
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          AppColors.primary.withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Text(
                                  'حجز المعاينة 📅',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputArea(Function setModalState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: _isWaitingForPhone
                    ? 'أدخل رقم تليفونك هنا (11 رقم)...'
                    : 'اكتب استفسارك العقاري أو طلبك هنا...',
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              onSubmitted: (_) => _handleSend(setModalState),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: AppColors.primary,
            child: IconButton(
              icon: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 18),
              onPressed: () => _handleSend(setModalState),
            ),
          ),
        ],
      ),
    );
  }
}
