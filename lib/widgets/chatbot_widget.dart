import 'package:flutter/material.dart';
import '../constants/colors.dart';

class ChatBotWidget extends StatefulWidget {
  const ChatBotWidget({super.key});

  @override
  State<ChatBotWidget> createState() => _ChatBotWidgetState();
}

class _ChatBotWidgetState extends State<ChatBotWidget> {
  final List<Map<String, dynamic>> _messages = [
    {
      'sender': 'bot',
      'text': 'مرحبًا بك في عقارات طنطا! 👋 كيف يمكنني مساعدتك اليوم؟',
      'options': ['بحث عن عقار 🏠', 'عرض عقاري للبيع 💰', 'استشارة عقارية 💬']
    }
  ];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

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

  void _handleOptionClick(String option, Function setModalState) {
    _addMessage('user', option, setModalState);
    _processResponse(option, setModalState);
  }

  void _handleSend(Function setModalState) {
    if (_controller.text.isEmpty) return;
    String text = _controller.text;
    _addMessage('user', text, setModalState);
    _controller.clear();
    _processResponse(text, setModalState);
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
        _addMessage('bot', 'ممتاز! بتدور على إيه بالظبط؟', setModalState, 
          options: ['شقة سكنية 🏢', 'فيلا مستقلة 🏰', 'محل تجاري 🛍️', 'أرض 🌳']);
      } 
      else if (userText.contains('شقة سكنية')) {
        _addMessage('bot', 'جميل، محتاج الشقة تكون فين؟', setModalState, 
          options: ['الحي الغربي 📍', 'وسط البلد 📍', 'قحافة 📍', 'سيجر 📍']);
      }
      else if (userText.contains('عرض عقاري للبيع')) {
        _addMessage('bot', 'إحنا بنساعدك تبيع عقارك بأسرع وقت! محتاج تكلمنا واتساب نحدد ميعاد للمعاينة؟', setModalState, 
          options: ['تواصل واتساب الآن 🟢', 'رجوع للبداية 🔙']);
      }
      else if (userText.contains('استشارة عقارية')) {
        _addMessage('bot', 'مستشارنا العقاري معاك! تقدر تسأل عن الأسعار، الإجراءات القانونية، أو أفضل مناطق الاستثمار.', setModalState,
          options: ['أفضل مناطق الاستثمار 📈', 'أسعار المناطق 💰', 'تواصل مع خبير 👨‍💼']);
      }
      else if (userText.contains('الحي الغربي')) {
        _addMessage('bot', 'الحي الغربي منطقة راقية جداً! عندنا عروض بتبدأ من 800 ألف جنيه. تحب تشوف الصور؟', setModalState,
          options: ['عرض الشقق المتاحة 📸', 'تغيير المنطقة 🔄']);
      }
      else {
        _addMessage('bot', 'تشرفت بك! هل هناك أي شيء آخر يمكنني مساعدتك به؟', setModalState,
          options: ['رجوع للبداية 🔙', 'تحدث مع خدمة العملاء 📞']);
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
                children: [
                  _buildHeader(context),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        return _buildMessageItem(_messages[index], setModalState);
                      },
                    ),
                  ),
                  _buildInputArea(setModalState),
                ],
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
          const CircleAvatar(
            backgroundColor: Colors.white24,
            child: Icon(Icons.smart_toy, color: Colors.white),
          ),
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
            child: Text(
              message['text'],
              style: TextStyle(color: isUser ? Colors.black87 : AppColors.primary, fontSize: 15, height: 1.4),
            ),
          ),
        ),
        if (!isUser && options != null && options.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: options.map((opt) => ActionChip(
                label: Text(opt, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: AppColors.primary, width: 1),
                  borderRadius: BorderRadius.circular(20),
                ),
                onPressed: () => _handleOptionClick(opt, setModalState),
              )).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildInputArea(Function setModalState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'اكتب استفسارك هنا...',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onSubmitted: (_) => _handleSend(setModalState),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: AppColors.primary,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: () => _handleSend(setModalState),
            ),
          ),
        ],
      ),
    );
  }
}
