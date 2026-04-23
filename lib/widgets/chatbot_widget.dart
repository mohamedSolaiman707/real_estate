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

  void _handleSend() {
    if (_controller.text.isEmpty) return;
    String text = _controller.text;
    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _controller.clear();
      _botResponse(text);
    });
  }

  void _botResponse(String userText) {
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
      setState(() {
        _messages.add({'sender': 'bot', 'text': response});
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'chatbot',
      onPressed: () => _showChat(context),
      backgroundColor: AppColors.primary,
      child: const Icon(Icons.smart_toy),
    );
  }

  void _showChat(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                children: [
                  AppBar(
                    title: const Text('مساعدك العقاري'),
                    leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    automaticallyImplyLeading: false,
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        bool isUser = _messages[index]['sender'] == 'user';
                        return Align(
                          alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isUser ? Colors.grey[300] : AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(_messages[index]['text']!),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            decoration: const InputDecoration(hintText: 'اكتب سؤالك هنا...', border: OutlineInputBorder()),
                            onSubmitted: (_) => _handleSend(),
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.send), onPressed: _handleSend),
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
