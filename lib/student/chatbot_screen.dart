import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_generative_ai/google_generative_ai.dart'; // <-- New Import

// IMPORTANT: Replace this with your actual Gemini API Key.
// For production apps, use environment variables, not hardcoding.
const String GEMINI_API_KEY = "AIzaSyCMX9-2sIkUn-1DX0WPjqVBVYFsWvvX10M";

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();

  final List<Map<String, dynamic>> _messages = [];

  // Initialize the Gemini Model Client
  late final GenerativeModel _model = GenerativeModel(
    model: 'gemini-2.5-flash',
    apiKey: "AIzaSyCMX9-2sIkUn-1DX0WPjqVBVYFsWvvX10M",
  );

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    // Add user message to the list immediately
    setState(() {
      _messages.add({
        'text': text.trim(),
        'isUser': true,
      });
    });

    _controller.clear();
    _generateBotResponse(text);
  }

  // Modified to be async and call Gemini
  void _generateBotResponse(String userInput) async {
    // A small delay for better UX before generating a response
    await Future.delayed(const Duration(milliseconds: 300));
    
    String botReply;

    // --- Hardcoded Logic (Existing) ---
    if (userInput.toLowerCase().contains('complaint') ||
        userInput.toLowerCase().contains('problem')) {
      botReply =
          "Here’s a step-by-step guide on how you can file a complaint regarding damages in your dormitory:\n"
          "1. Navigate to your home page.\n"
          "2. Find the purple '+' button at the bottom centre of your menu section.\n"
          "3. You will be directed to a form. Fill in all the details and press ‘Submit Complaint’.\n\n"
          "That’s all you need to do to file a file a complaint to your residential college office. 😊";
    } else if (userInput.toLowerCase().contains('smartserve')) {
      botReply =
          "SmartServe is a platform for managing residential college facilities, maintenance reports, and student services all in one place.";
    } else if (userInput.toLowerCase().contains('college')) {
      botReply =
          "You can contact your residential college office for room or facility issues. They’ll assist with repair scheduling and room management.";
    } else if (userInput.toLowerCase().contains('faq')) {
      botReply = "You can browse FAQs for help with account access, maintenance reporting, and general dorm inquiries.";
    }
    // --- Gemini API Logic (New) ---
    else {
      try {
        // Prepare a prompt to instruct the AI on its role
        final systemInstruction = "You are Fixie, a helpful, friendly, and concise chatbot assistant for the SmartServe residential college platform. Answer user questions based on your general knowledge and the context provided, keeping your answers related to dormitory, college, or student life when possible.";

        final content = [
          Content.text(systemInstruction),
          Content.text(userInput)
        ];

        // Use the API to generate a response
        final response = await _model.generateContent(content);

        botReply = response.text ?? "Sorry, the AI model returned an empty response. Try again.";
      } catch (e) {
        // Catch any errors (like network issues, invalid key, rate limits)
        botReply = "I ran into an error trying to connect to the AI. Please check your API key and internet connection.";
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

  @override
  Widget build(BuildContext context) {
    // ... (Your existing build method)
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEDE8FF),
        elevation: 0,
        title: Text(
          'Chatbot Assistance',
          style: GoogleFonts.poppins(
              fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.notifications_none, color: Colors.black87),
          ),
        ],
      ),

      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildWelcomeCard()
                : ListView.builder(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['isUser'] as bool;

                return Align(
                  alignment:
                  isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser
                          ? const Color(0xFF5F33E1)
                          : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(12),
                        topRight: const Radius.circular(12),
                        bottomLeft: Radius.circular(isUser ? 12 : 0),
                        bottomRight: Radius.circular(isUser ? 0 : 12),
                      ),
                      boxShadow: [
                        if (!isUser)
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                      ],
                    ),
                    child: Text(
                      msg['text'],
                      style: GoogleFonts.poppins(
                        color: isUser ? Colors.white : Colors.black87,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          if (_messages.isEmpty) _buildQuickReplies(),

          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Type your message here...",
                      hintStyle: GoogleFonts.poppins(
                        color: const Color(0xFF90929C),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: Color(0xFF5F33E1)),
                  onPressed: () => _sendMessage(_controller.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.smart_toy_rounded,
                size: 80, color: Color(0xFF5F33E1)),
            const SizedBox(height: 16),
            Text(
              "Hi there, I’m Fixie, your chatbot assistance on SmartServe.\nTry asking me some questions regarding your residential college!",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 14, color: const Color(0xFF606060), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickReplies() {
    final List<String> quickReplies = [
      "💬 What is SmartServe?",
      "🏫 College",
      "❓ FAQs",
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        children: quickReplies.map((label) {
          return GestureDetector(
            onTap: () => _sendMessage(label),
            child: Chip(
              label: Text(
                label,
                style: GoogleFonts.poppins(fontSize: 13),
              ),
              backgroundColor: const Color(0xFFF2EEFF),
            ),
          );
        }).toList(),
      ),
    );
  }
}