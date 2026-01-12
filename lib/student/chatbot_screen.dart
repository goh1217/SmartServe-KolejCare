import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_generative_ai/google_generative_ai.dart'; // <-- New Import
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'notification_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  late final String _geminiApiKey = dotenv.env['API_KEY'] ?? '';
  bool _showQuickActions = true; // Track quick actions visibility

  final List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;

  // Initialize the Gemini Model Client
  late final GenerativeModel _model = GenerativeModel(
    model: 'gemini-2.5-flash',
    apiKey: _geminiApiKey,
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
    // Show typing indicator
    setState(() {
      _isTyping = true;
    });

    // A small delay for better UX before generating a response
    await Future.delayed(const Duration(milliseconds: 300));
    
    String botReply;

    // --- Hardcoded Logic (Existing) ---
    String input = userInput.toLowerCase();
    if (input.contains('complaint') || input.contains('problem') || input.contains('damage')) {
      botReply =
          "To file a complaint about dormitory furniture or appliances (like bed frames, fans, or lamps):\n"
          "1. Go to the Home page.\n"
          "2. Tap the purple '+' button in the center of the menu.\n"
          "3. Fill in the details. *Tip: Our AI will automatically suggest the urgency based on your description!*\n"
          "4. Tap ‘Submit Complaint’. "; 
    } 
    else if (input.contains('track') || input.contains('status') || input.contains('progress')) {
      botReply =
          "You can view real-time updates on your repair progress in the 'Complaints' section (third icon of the menu). "
          "You'll be able to see if your request is pending, assigned, ongoing, rejected or completed. ";
    } 
    else if (input.contains('technician') || input.contains('arrival') || input.contains('who')) {
      botReply =
          "For your safety and privacy, SmartServe allows you to see the assigned technician's details "
          "and their estimated arrival time so you aren't surprised by visitors. ";
    } 
    else if (input.contains('schedule') || input.contains('reschedule') || input.contains('time')) {
      botReply =
          "SmartServe features a transparent scheduling system. If the assigned repair time doesn't work for you, "
          "you can use the rescheduling feature within the app to manage repair visits. ";
    } 
    else if (input.contains('donate') || input.contains('donation') || input.contains('money') || input.contains('fund')) {
      botReply =
          "You can contribute to the college's welfare fund through our secure payment integration. "
          "These voluntary donations support future repairs and facility upgrades! ";
    } 
    else if (input.contains('feedback') || input.contains('rate') || input.contains('rating')) {
      botReply =
          "Once a repair is finished, you can rate the service and provide feedback. "
          "This helps the college measure satisfaction and ensure the quality of repairs. ";
    }
    else if (input.contains('location') || input.contains('gps')) {
      botReply = 
          "The app uses GPS technology to automatically detect your current dormitory location "
          "when you file a report, making the process faster and more accurate. ";
    }
    else if (input.contains('smartserve') ) {
      botReply =
          "SmartServe is a centralized platform for students, staff and technicians "
          "to manage facility maintenance and community engagement at UTM. ";
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
        
        // Clean up markdown formatting to make it look less AI-generated
        botReply = botReply.replaceAll('**', '');
        // Strip leading bullet markers like "* " that clutter the UI
        botReply = botReply.replaceAll(RegExp(r'^\s*[\*\-]\s+', multiLine: true), '');
      } catch (e) {
        // Catch any errors (like network issues, invalid key, rate limits)
        botReply = "I ran into an error trying to connect to the AI. Please check your API key and internet connection.";
        // Log the error for debugging
        print('Gemini API Error: $e');
      }
    }

    // Update the UI with the bot's final response
    setState(() {
      _isTyping = false;
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
                _buildBellIcon(),
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
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                // Show typing indicator at the end
                if (_isTyping && index == _messages.length) {
                  return _buildTypingIndicator();
                }

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

          // Quick actions - Always visible but collapsible
          if (_messages.isNotEmpty) 
            _buildCompactQuickActions(),

          if (_messages.isEmpty) 
            _buildQuickReplies(),

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
      {
        "icon": Icons.info_outline,
        "label": "What is SmartServe?",
        "response": "SmartServe is a centralized platform for students, staff and technicians "
            "to manage facility maintenance and community engagement at UTM. It helps you report issues, "
            "track repairs, and stay connected with college services!"
      },
      {
        "icon": Icons.report_problem_outlined,
        "label": "How to file a complaint?",
        "response": "To file a complaint about dormitory furniture or appliances (like bed frames, fans, or lamps):\n"
            "1. Go to the Home page.\n"
            "2. Tap the purple '+' button in the center of the menu.\n"
            "3. Fill in the details. *Tip: Our AI will automatically suggest the urgency based on your description!*\n"
            "4. Tap 'Submit Complaint'."
      },
      {
        "icon": Icons.track_changes_outlined,
        "label": "Track my complaint",
        "response": "You can view real-time updates on your repair progress in the 'Complaints' section (third icon of the menu). "
            "You'll be able to see if your request is pending, assigned, ongoing, rejected or completed."
      },
      {
        "icon": Icons.engineering_outlined,
        "label": "Technician info",
        "response": "For your safety and privacy, SmartServe allows you to see the assigned technician's details "
            "and their estimated arrival time so you aren't surprised by visitors."
      },
      {
        "icon": Icons.star_outline,
        "label": "Rate service",
        "response": "Once a repair is finished, you can rate the service and provide feedback. "
            "This helps the college measure satisfaction and ensure the quality of repairs."
      },
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
                onTap: () {
                  // Send the question as user message
                  setState(() {
                    _messages.add({
                      'text': item["label"],
                      'isUser': true,
                    });
                  });
                  
                  // Immediately show the paired response
                  Future.delayed(const Duration(milliseconds: 300), () {
                    setState(() {
                      _messages.add({
                        'text': item["response"],
                        'isUser': false,
                      });
                    });
                  });
                },
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

  Widget _buildCompactQuickActions() {
    final List<Map<String, dynamic>> quickReplies = [
      {
        "icon": Icons.info_outline,
        "label": "What is SmartServe?",
        "response": "SmartServe is a centralized platform for students, staff and technicians "
            "to manage facility maintenance and community engagement at UTM. It helps you report issues, "
            "track repairs, and stay connected with college services!"
      },
      {
        "icon": Icons.report_problem_outlined,
        "label": "How to file a complaint?",
        "response": "To file a complaint about dormitory furniture or appliances (like bed frames, fans, or lamps):\n"
            "1. Go to the Home page.\n"
            "2. Tap the purple '+' button in the center of the menu.\n"
            "3. Fill in the details. *Tip: Our AI will automatically suggest the urgency based on your description!*\n"
            "4. Tap 'Submit Complaint'."
      },
      {
        "icon": Icons.track_changes_outlined,
        "label": "Track my complaint",
        "response": "You can view real-time updates on your repair progress in the 'Complaints' section (third icon of the menu). "
            "You'll be able to see if your request is pending, assigned, ongoing, rejected or completed."
      },
      {
        "icon": Icons.engineering_outlined,
        "label": "Technician info",
        "response": "For your safety and privacy, SmartServe allows you to see the assigned technician's details "
            "and their estimated arrival time so you aren't surprised by visitors."
      },
      {
        "icon": Icons.star_outline,
        "label": "Rate service",
        "response": "Once a repair is finished, you can rate the service and provide feedback. "
            "This helps the college measure satisfaction and ensure the quality of repairs."
      },
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F7FF),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF5E4DB2).withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _showQuickActions = !_showQuickActions;
              });
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Suggestions",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF5E4DB2),
                  ),
                ),
                Icon(
                  _showQuickActions ? Icons.expand_less : Icons.expand_more,
                  color: const Color(0xFF5E4DB2),
                  size: 20,
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _showQuickActions
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      height: 85,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: quickReplies.length,
                        itemBuilder: (context, index) {
                          final item = quickReplies[index];
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _messages.add({
                                  'text': item["label"],
                                  'isUser': true,
                                });
                              });

                              Future.delayed(const Duration(milliseconds: 300), () {
                                setState(() {
                                  _messages.add({
                                    'text': item["response"],
                                    'isUser': false,
                                  });
                                });
                              });
                            },
                            child: Container(
                              width: 110,
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFEAE5FF), Color(0xFFF0EBFF)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF5E4DB2).withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    item["icon"] as IconData,
                                    color: const Color(0xFF5E4DB2),
                                    size: 20,
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    item["label"] as String,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF2D2D2D),
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(0),
            const SizedBox(width: 4),
            _buildDot(1),
            const SizedBox(width: 4),
            _buildDot(2),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        final delay = index * 0.2;
        final animValue = ((value + delay) % 1.0);
        final scale = 0.5 + (animValue * 0.5);
        final opacity = 0.3 + (animValue * 0.7);
        
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFF5E4DB2).withOpacity(opacity),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
      onEnd: () {
        if (mounted && _isTyping) {
          setState(() {});
        }
      },
    );
  }

  // Bell icon with real-time unread badge
  Widget _buildBellIcon() {
    return FutureBuilder<String>(
      future: () async {
        final user = FirebaseAuth.instance.currentUser;
        final uid = user?.uid;
        if (uid == null) return '';
        final q = await FirebaseFirestore.instance.collection('student').where('authUid', isEqualTo: uid).limit(1).get();
        if (q.docs.isNotEmpty) return q.docs.first.id;
        final email = user?.email ?? '';
        if (email.isNotEmpty) {
          final qe = await FirebaseFirestore.instance.collection('student').where('email', isEqualTo: email).limit(1).get();
          if (qe.docs.isNotEmpty) return qe.docs.first.id;
        }
        return '';
      }(),
      builder: (context, snap) {
        final sid = snap.data ?? '';
        if (snap.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: const SizedBox(width: 22, height: 22, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }

        // Listen to all complaints and filter client-side to handle mixed reportBy formats
        final stream = FirebaseFirestore.instance.collection('complaint').snapshots();

        return StreamBuilder<QuerySnapshot>(
          stream: stream,
          builder: (context, s2) {
            final uid = FirebaseAuth.instance.currentUser?.uid;
            int unread = 0;

            for (final doc in s2.data?.docs ?? const []) {
              final data = doc.data() as Map<String, dynamic>? ?? {};
              if (data['isArchived'] == true) continue;
              if (data['isRead'] == true) continue;

              final rb = data['reportBy'] ?? data['reportedBy'];
              bool matches = false;

              if (sid.isNotEmpty) {
                if (rb is DocumentReference) {
                  final path = rb.path;
                  if (path.endsWith('/$sid') || path.contains(sid)) matches = true;
                } else if (rb is String) {
                  if (rb == sid || rb.endsWith('/$sid') || rb.contains('/student/$sid') || rb.contains('/collection/student/$sid')) {
                    matches = true;
                  }
                }
              }

              if (!matches && uid != null) {
                if (rb == uid) matches = true;
                else if (rb is String && rb.contains(uid)) matches = true;
                else if (rb is DocumentReference && rb.path.contains(uid)) matches = true;
              }

              if (matches) unread++;
            }

            final hasUnread = unread > 0;
            return GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (c) => const NotificationPage()));
              },
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
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      Icons.notifications_rounded,
                      color: hasUnread ? const Color(0xFF5E4DB2) : Colors.grey.shade600,
                      size: 22,
                    ),
                    if (hasUnread)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.45), blurRadius: 8, spreadRadius: 2)],
                          ),
                          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                          child: Center(
                            child: Text(
                              unread > 99 ? '99+' : '$unread',
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
