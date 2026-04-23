import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/colors.dart';

class ChatBotWidget extends StatefulWidget {
  const ChatBotWidget({super.key});

  @override
  State<ChatBotWidget> createState() => _ChatBotWidgetState();
}

class _ChatBotWidgetState extends State<ChatBotWidget> {
  final _supabase = Supabase.instance.client;
  final List<Map<String, dynamic>> _messages = [
    {
      'sender': 'bot',
      'text': 'مرحبًا بك في عقارات طنطا! 👋 كيف يمكنني مساعدتك اليوم؟',
      'options': ['بحث عن عقار 🏠', 'عرض عقاري للبيع 💰', 'استشارة عقارية 💬']
    }
  ];
  
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // متغيرات لتخزين "رحلة العميل" داخل الشات
  String _userIntent = '';
  String _userPreference = '';
  bool _isWaitingForPhone = false;

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

  // حفظ بيانات العميل في سوبابيز (Lead من الشات)
  Future<void> _saveChatLead(String phone) async {
    try {
      await _supabase.from('leads').insert({
        'name': 'عميل من الشات',
        'phone': phone,
        'source': 'chatbot',
        'form_data': {
          'intent': _userIntent,
          'preference': _userPreference,
          'chat_summary': 'العميل مهتم بـ $_userIntent في $_userPreference'
        }
      });
      debugPrint('Chat lead saved successfully');
    } catch (e) {
      debugPrint('Error saving chat lead: $e');
    }
  }

  Future<void> _launchWhatsApp(String message) async {
    final Uri whatsappUri = Uri.parse("https://wa.me/201014250577?text=${Uri.encodeComponent(message)}");
    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    }
  }

  void _handleOptionClick(String option, Function setModalState) {
    _addMessage('user', option, setModalState);
    
    if (option.contains('تواصل واتساب') || option.contains('تحدث مع خبير')) {
      _launchWhatsApp("أنا مهتم بـ $_userIntent في $_userPreference، أريد استشارة.");
    } 
    else if (option.contains('رجوع للبداية')) {
      _isWaitingForPhone = false;
      _addMessage('bot', 'أهلاً بك مرة أخرى! كيف يمكنني مساعدتك؟', setModalState, 
        options: ['بحث عن عقار 🏠', 'عرض عقاري للبيع 💰', 'استشارة عقارية 💬']);
    }
    else {
      _processResponse(option, setModalState);
    }
  }

  void _handleSend(Function setModalState) {
    if (_controller.text.isEmpty) return;
    String text = _controller.text;
    _addMessage('user', text, setModalState);
    
    // لو البوت مستني رقم التليفون
    if (_isWaitingForPhone) {
      if (text.length >= 11) {
        _saveChatLead(text);
        _addMessage('bot', 'تم تسجيل طلبك بنجاح ✅ سيتواصل معك أحد مستشارينا العقاريين فوراً.', setModalState, options: ['تصفح العقارات 🏠', 'رجوع للبداية 🔙']);
        _isWaitingForPhone = false;
      } else {
        _addMessage('bot', 'من فضلك أدخل رقم تليفون صحيح (11 رقم).', setModalState);
      }
    } else {
      _processResponse(text, setModalState);
    }
    
    _controller.clear();
  }

  void _addMessage(String sender, String text, Function setModalState, {List<String>? options}) {
    setModalState(() {
      _messages.add({'sender': sender, 'text': text, 'options': options});
    });
    setState(() {});
    _scrollToBottom();
  }

  void _processResponse(String userText, Function setModalState) {
    Future.delayed(const Duration(milliseconds: 600), () {
      if (userText.contains('بحث عن عقار')) {
        _userIntent = 'شراء عقار';
        _addMessage('bot', 'ممتاز! بتدور على إيه بالظبط؟', setModalState, 
          options: ['شقة سكنية 🏢', 'فيلا مستقلة 🏰', 'محل تجاري 🛍️']);
      } 
      else if (userText.contains('شقة سكنية')) {
        _userPreference = 'شقة سكنية';
        _addMessage('bot', 'جميل، محتاج الشقة تكون فين؟', setModalState, 
          options: ['الحي الغربي 📍', 'الاستاد 📍', 'وسط البلد 📍']);
      }
      else if (userText.contains('الحي الغربي') || userText.contains('الاستاد')) {
        _userPreference += ' في $userText';
        _isWaitingForPhone = true;
        _addMessage('bot', 'منطقة ممتازة! سأقوم بإرسال أفضل العروض المتاحة هناك إليك. اترك رقم تليفونك وسيتواصل معك خبيرنا فوراً.', setModalState);
      }
      else if (userText.contains('عرض عقاري للبيع')) {
        _userIntent = 'بيع عقار';
        _isWaitingForPhone = true;
        _addMessage('bot', 'يسعدنا مساعدتك في بيع عقارك بأفضل سعر. اترك رقم تليفونك لتحديد موعد للمعاينة والتصوير.', setModalState);
      }
      else if (userText.contains('استشارة عقارية')) {
        _userIntent = 'استشارة';
        _addMessage('bot', 'مستشارنا العقاري متاح لمساعدتك في أي وقت. عن ماذا تود الاستفسار؟', setModalState,
          options: ['أفضل مناطق الاستثمار 📈', 'تحدث مع خبير 👨‍💼']);
      }
      else if (userText.contains('تصفح العقارات')) {
        Navigator.pop(context);
        Navigator.pushNamed(context, '/listings');
      }
      else {
        _addMessage('bot', 'أنا هنا لمساعدتك دائماً. هل تريد التحدث مع أحد موظفينا مباشرة؟', setModalState,
          options: ['تحدث مع خبير 👨‍💼', 'رجوع للبداية 🔙']);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'chatbot',
      onPressed: () => _showChat(context),
      backgroundColor: AppColors.primary,
      child: const Icon(Icons.smart_toy, color: Colors.white),
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
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                children: [_buildHeader(context), Expanded(child: _buildChatList(setModalState)), _buildInputArea(setModalState)],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Row(
        children: [
          const CircleAvatar(backgroundColor: Colors.white24, child: Icon(Icons.smart_toy, color: Colors.white)),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('مساعدك العقاري الذكي', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              Text('متصل الآن', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          const Spacer(),
          IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  Widget _buildChatList(Function setModalState) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _buildMessageItem(_messages[index], setModalState),
    );
  }

  Widget _buildMessageItem(Map<String, dynamic> message, Function setModalState) {
    bool isUser = message['sender'] == 'user';
    List<String>? options = message['options'];
    return Column(
      crossAxisAlignment: isUser ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Align(
          alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(14),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              color: isUser ? Colors.grey[200] : AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(18).copyWith(
                bottomLeft: isUser ? Radius.zero : const Radius.circular(18),
                bottomRight: isUser ? const Radius.circular(18) : Radius.zero,
              ),
            ),
            child: Text(message['text'], style: TextStyle(color: isUser ? Colors.black87 : AppColors.primary, fontSize: 15, height: 1.4)),
          ),
        ),
        if (!isUser && options != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8, runSpacing: 8,
              children: options.map((opt) => ActionChip(
                label: Text(opt, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                backgroundColor: Colors.white,
                onPressed: () => _handleOptionClick(opt, setModalState),
                shape: RoundedRectangleBorder(side: const BorderSide(color: AppColors.primary), borderRadius: BorderRadius.circular(20)),
              )).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildInputArea(Function setModalState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black, blurRadius: 10)]),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: _isWaitingForPhone ? 'أدخل رقم تليفونك هنا...' : 'اكتب استفسارك هنا...',
                filled: true, fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              onSubmitted: (_) => _handleSend(setModalState),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(backgroundColor: AppColors.primary, child: IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: () => _handleSend(setModalState))),
        ],
      ),
    );
  }
}
