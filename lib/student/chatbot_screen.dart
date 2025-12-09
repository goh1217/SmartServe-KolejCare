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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: SafeArea(
          child: Container(
            color: const Color(0xFFF5F5F7),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          size: 18,
                          color: Color(0xFF5E4DB2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Chatbot Assistance',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'Powered by Gemini AI',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF9E9E9E),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.notifications_rounded,
                      color: Color(0xFF5E4DB2),
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildWelcomeCard()
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['isUser'] as bool;

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: isUser
                          ? const LinearGradient(
                              colors: [Color(0xFF6C4DF0), Color(0xFF5E4DB2)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isUser ? null : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isUser ? 20 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isUser 
                              ? const Color(0xFF5E4DB2).withOpacity(0.3)
                              : Colors.black.withOpacity(0.08),
                          blurRadius: isUser ? 12 : 8,
                          offset: Offset(0, isUser ? 4 : 2),
                        ),
                      ],
                    ),
                    child: Text(
                      msg['text'],
                      style: GoogleFonts.poppins(
                        color: isUser ? Colors.white : const Color(0xFF2D2D2D),
                        fontSize: 14,
                        fontWeight: isUser ? FontWeight.w500 : FontWeight.w400,
                        height: 1.5,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          if (_messages.isEmpty) _buildQuickReplies(),

          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Ask me anything...",
                      hintStyle: GoogleFonts.poppins(
                        color: const Color(0xFFB0B0B0),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                    ),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C4DF0), Color(0xFF5E4DB2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    onPressed: () => _sendMessage(_controller.text),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
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
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C4DF0), Color(0xFF5E4DB2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5E4DB2).withOpacity(0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                size: 64,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Hi there! I'm Fixie 👋",
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2D2D2D),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Your AI-powered assistant for SmartServe",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF5E4DB2),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Ask me anything about your residential college, maintenance reports, or campus facilities!",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: const Color(0xFF808080),
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickReplies() {
    final List<Map<String, dynamic>> quickReplies = [
      {"icon": Icons.info_outline, "label": "What is SmartServe?"},
      {"icon": Icons.home_work_outlined, "label": "College Info"},
      {"icon": Icons.help_outline, "label": "FAQs"},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              "Quick Actions",
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF808080),
              ),
            ),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: quickReplies.map((item) {
              return GestureDetector(
                onTap: () => _sendMessage(item["label"]),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFE0E0E0),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item["icon"],
                        size: 18,
                        color: const Color(0xFF5E4DB2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item["label"],
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF2D2D2D),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}