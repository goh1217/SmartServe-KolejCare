import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:owtest/analytics_page.dart';
import 'package:owtest/main.dart';
import 'package:owtest/staff_complaints.dart';
import 'package:owtest/settings_page.dart';

// IMPORTANT: Replace this with your actual Gemini API Key.
// For production apps, use environment variables, not hardcoding.
const String GEMINI_API_KEY = "AIzaSyCMX9-2sIkUn-1DX0WPjqVBVYFsWvvX10M";

class HelpPage extends StatefulWidget {
  const HelpPage({Key? key}) : super(key: key);

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  int _selectedIndex = 3;
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];

  // Initialize the Gemini Model Client
  late final GenerativeModel _model = GenerativeModel(
    model: 'gemini-1.5-flash',
    apiKey: GEMINI_API_KEY,
  );

  final List<FAQItem> faqs = [
    FAQItem(
      icon: Icons.report_problem_outlined,
      question: 'How do I report a damage?',
    ),
    FAQItem(
      icon: Icons.access_time,
      question: 'How can I track my complaint',
    ),
    FAQItem(
      icon: Icons.info_outline,
      question: 'When will technician arrive?',
    ),
    FAQItem(
      icon: Icons.attach_money,
      question: 'What are the repair costs?',
    ),
    FAQItem(
      icon: Icons.phone_outlined,
      question: 'How to contact support?',
    ),
  ];

  void _onItemTapped(int index) {
    if (index == 0) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else if (index == 1) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (context) => const StaffComplaintsPage()));
    } else if (index == 2) {
      Navigator.push(
          context, MaterialPageRoute(builder: (context) => const AnalyticsPage()));
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _messages.add(ChatMessage(
          text: text,
          isUser: true,
        ));
        _messageController.clear();
      });
      _generateBotResponse(text);
    }
  }

  void _selectFAQ(String question) {
    setState(() {
      _messages.add(ChatMessage(
        text: question,
        isUser: true,
      ));
    });
    _generateBotResponse(question);
  }

  // Modified to be async and call Gemini
  void _generateBotResponse(String userInput) async {
    // A small delay for better UX before generating a response
    await Future.delayed(const Duration(milliseconds: 300));

    String botReply;

    // --- Hardcoded Logic (Existing) ---
    final hardcodedResponse = _getResponseForQuestion(userInput);

    if (hardcodedResponse != null) {
      botReply = hardcodedResponse;
    }
    // --- Gemini API Logic (New) ---
    else {
      try {
        // Prepare a prompt to instruct the AI on its role
        final systemInstruction =
            "You are a helpful, friendly, and concise chatbot assistant for the SmartServe residential college platform. Answer user questions based on your general knowledge and the context provided, keeping your answers related to dormitory, college, or student life when possible.";

        final content = [
          Content.text(systemInstruction),
          Content.text(userInput)
        ];

        // Use the API to generate a response
        final response = await _model.generateContent(content);

        botReply = response.text ??
            "Sorry, the AI model returned an empty response. Try again.";
      } catch (e) {
        // Catch any errors (like network issues, invalid key, rate limits)
        botReply =
            "I ran into an error trying to connect to the AI. Please check your API key and internet connection.";
        // Log the error for debugging
        print('Gemini API Error: $e');
      }
    }

    // Update the UI with the bot's final response
    setState(() {
      _messages.add({
        'text': botReply,
        'isUser': false,
      });
    });
  }

  String? _getResponseForQuestion(String question) {
    if (question.contains('report a damage')) {
      return 'To report a damage, go to the Complaints section and click "Add New Complaint". Fill in the details and submit.';
    } else if (question.contains('track my complaint')) {
      return 'You can track your complaint in the Complaints section. Each complaint shows its current status: Pending, In Progress, or Completed.';
    } else if (question.contains('technician arrive')) {
      return 'The technician arrival time will be shown in your complaint details once scheduled. You will receive a notification.';
    } else if (question.contains('repair costs')) {
      return 'Repair costs vary depending on the type of damage. You will receive a cost estimate before any work begins.';
    } else if (question.contains('contact support')) {
      return 'You can contact support through this chat or by calling our helpline at 1-800-SUPPORT.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // AI Assistant Header
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'AI Assistant',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SettingsPage())),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // FAQs Section
                    const Text(
                      'Frequently Asked Questions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // FAQ Buttons
                    ...faqs.map((faq) => _buildFAQButton(faq)),
                    const SizedBox(height: 24),

                    // AI Assistant Chat Box
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Assistant Header
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.smart_toy,
                                  color: Color(0xFF7C3AED),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'AI Assistant',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    'online',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Chat Messages Area
                          Container(
                            constraints: const BoxConstraints(
                              minHeight: 150,
                              maxHeight: 300,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: _messages.isEmpty
                                ? Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF0F0F0),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.smart_toy,
                                          color: Color(0xFF7C3AED),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Text(
                                          'Hi there! What would you like help with today?',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: _messages.length,
                                    itemBuilder: (context, index) {
                                      return _buildChatMessage(
                                          _messages[index]);
                                    },
                                  ),
                          ),
                          const SizedBox(height: 16),

                          // Message Input
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Colors.grey.shade300),
                                  ),
                                  child: TextField(
                                    controller: _messageController,
                                    decoration: const InputDecoration(
                                      hintText: 'Type your message',
                                      hintStyle: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                    ),
                                    onSubmitted: (_) => _sendMessage(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C3AED),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.send,
                                      color: Colors.white),
                                  onPressed: _sendMessage,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description),
            label: 'Complaints',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.help_outline),
            label: 'Help',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF7C3AED),
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  Widget _buildFAQButton(FAQItem faq) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: () => _selectFAQ(faq.question),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFE9D5FF),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              children: [
                Icon(
                  faq.icon,
                  color: const Color(0xFF7C3AED),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    faq.question,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatMessage(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.smart_toy,
                color: Color(0xFF7C3AED),
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? const Color(0xFF7C3AED)
                    : const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  fontSize: 14,
                  color: message.isUser ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}

// Models
class FAQItem {
  final IconData icon;
  final String question;

  FAQItem({
    required this.icon,
    required this.question,
  });
}

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({
    required this.text,
    required this.isUser,
  });
}
