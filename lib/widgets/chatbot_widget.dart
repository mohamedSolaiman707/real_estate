import 'package:flutter/material.dart';
import '../constants/colors.dart';

class ChatBotWidget extends StatefulWidget {
  const ChatBotWidget({super.key});

  @override
  State<ChatBotWidget> createState() => _ChatBotWidgetState();
}

class _ChatBotWidgetState extends State<ChatBotWidget> {
  final List<Map<String, String>> _messages = [
    {'sender': 'bot', 'text': 'مرحبًا! 👋 بتدور على إيه؟'}
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

  void _handleSend(Function setModalState) {
    if (_controller.text.isEmpty) return;
    String text = _controller.text;
    
    setModalState(() {
      _messages.add({'sender': 'user', 'text': text});
    });
    setState(() {}); // لتحديث الـ state الخارجية أيضاً
    
    _controller.clear();
    _scrollToBottom();
    
    _botResponse(text, setModalState);
  }

  void _botResponse(String userText, Function setModalState) {
    String response = 'تشرفت! في احتياج تاني؟';
    if (userText.contains('مرحبًا') || userText.contains('السلام')) {
      response = 'مرحبًا! 👋 بتدور على إيه؟';
    } else if (userText.contains('عندك شقة') || userText.contains('شقق')) {
      response = 'أيوه عندنا شقق كتير من 150k لـ 500k';
    } else if (userText.contains('السعر')) {
      response = 'يعتمد على الموقع. في الحي الغربي من 250k';
    } else if (userText.contains('الحي الغربي')) {
      response = 'موقع ذهبي جدًا! العائد 5% سنويًا';
    } else if (userText.contains('شكرًا')) {
      response = 'العفو! تحت أمرك في أي وقت.';
    }

    Future.delayed(const Duration(milliseconds: 500), () {
      setModalState(() {
        _messages.add({'sender': 'bot', 'text': response});
      });
      setState(() {});
      _scrollToBottom();
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
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('مساعدك العقاري 🤖', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        bool isUser = _messages[index]['sender'] == 'user';
                        return Align(
                          alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(12),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                            decoration: BoxDecoration(
                              color: isUser ? Colors.grey[200] : AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(15).copyWith(
                                bottomLeft: isUser ? Radius.zero : const Radius.circular(15),
                                bottomRight: isUser ? const Radius.circular(15) : Radius.zero,
                              ),
                            ),
                            child: Text(
                              _messages[index]['text']!,
                              style: TextStyle(color: isUser ? Colors.black87 : AppColors.primary, fontSize: 16),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            decoration: InputDecoration(
                              hintText: 'اكتب سؤالك هنا...',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                            ),
                            onSubmitted: (_) => _handleSend(setModalState),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          backgroundColor: AppColors.primary,
                          child: IconButton(
                            icon: const Icon(Icons.send, color: Colors.white),
                            onPressed: () => _handleSend(setModalState),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
