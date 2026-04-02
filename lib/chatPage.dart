import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:http/http.dart' as http;

class EmergencyChatPage extends StatefulWidget {
  final String incidentId;
  final String userName;

  const EmergencyChatPage({super.key, required this.incidentId, required this.userName});

  @override
  State<EmergencyChatPage> createState() => _EmergencyChatPageState();
}

class _EmergencyChatPageState extends State<EmergencyChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late IO.Socket socket;
  final List<Map<String, dynamic>> messages = [];

  bool loading = true;
  bool connected = false;
  bool _isSocketInitialized = false;


  final String apiBaseUrl = "https://ems.qalertapp.com";

  // final String apiBaseUrl = "http://192.168.1.11:3000";

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  @override
  void dispose() {
    if (_isSocketInitialized) {
      socket.off("newMessage");
      socket.off("connect");
      socket.off("connect_error");
      socket.off("disconnect");
      socket.disconnect();
      socket.dispose();
    }
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --- Fetch chat history from API ---
  Future<void> _fetchMessages() async {
    try {
      final res = await http.get(
        Uri.parse('$apiBaseUrl/api/v2/chats/${widget.incidentId}'),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          final List fetchedMessages = data['data'];
          if (mounted) {
            setState(() {
              messages.clear(); // clear system message
              for (var msg in fetchedMessages) {
                final isMe = msg['sender'] == widget.userName;
                messages.add({
                  "sender": isMe ? "You" : (msg['sender'] ?? "Responder"),
                  "text": msg['text'] ?? "",
                  "isMe": isMe,
                  "timestamp": msg['timestamp'] ?? "",
                });
              }
            });
            _scrollToBottom();
          }
        }
      }
    } catch (e) {
      debugPrint("❌ Failed to fetch messages: $e");
    }
  }

  // --- Connect Socket ---
  void _connectSocket(String incidentId) {
    debugPrint("🔗 Connecting to: $apiBaseUrl");

    socket = IO.io(
      apiBaseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setPath('/socket.io')
          .enableAutoConnect()
          .enableReconnection()
          .build(),
    );

    _isSocketInitialized = true;

    socket.onConnect((_) {
      debugPrint("✅ Connected to Socket Server");
      if (mounted) {
        setState(() => connected = true);
        socket.emit("joinIncident", incidentId);
        debugPrint("🏠 Joined Room: $incidentId");
      }
    });

    socket.onConnectError((data) =>
        debugPrint("❌ Socket Connection Error: $data"));

    // Receive message from responder/admin
    socket.on("newMessage", (data) {
      if (mounted) {
        final message = data['message']; // unwrap payload
        final sender = message['sender'] ?? "Responder";

        // Only add if not sent by me (mine are added locally)
        if (sender != widget.userName) {
          setState(() {
            messages.add({
              "sender": sender,
              "text": message['text'] ?? "",
              "isMe": false,
              "timestamp": message['timestamp'] ?? "",
            });
          });
          _scrollToBottom();
        }
      }
    });

    socket.onDisconnect((_) {
      debugPrint("🔌 Disconnected from Server");
      if (mounted) {
        setState(() => connected = false);
      }
    });
  }

  // --- Send Message ---
  void _sendMessage(String text) {
    if (text.trim().isEmpty || !connected) return;

    final now = DateTime.now().toIso8601String();

    final messageData = {
      "text": text,
      "sender": widget.userName,
      "timestamp": now,
    };

    final payload = {
      "incidentId": widget.incidentId,
      "message": messageData,
    };

    // Emit to server
    socket.emit("sendMessage", payload);

    // Add to local UI immediately
    setState(() {
      messages.add({
        "sender": "You",
        "text": text,
        "isMe": true,
        "timestamp": now,
      });
    });

    _controller.clear();
    _scrollToBottom();
  }

  // --- Scroll to bottom ---
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // --- Initialize Chat ---
  Future<void> _initializeChat() async {
    debugPrint("✅ Chat opened for incident: ${widget.incidentId}");

    // Show system message while connecting
    setState(() {
      loading = false;
      messages.add({
        "sender": "System",
        "text": "Connecting to Responders...",
        "isMe": false,
        "timestamp": "",
      });
    });

    // Connect socket
    _connectSocket(widget.incidentId);

    // Load chat history
    await _fetchMessages();
  }

  // --- Format timestamp ---
  String _formatTime(String timestamp) {
    if (timestamp.isEmpty) return '';
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Chat Room",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 15),
              child: Row(
                children: [
                  Text(
                    connected ? "LIVE" : "OFFLINE",
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 5),
                  CircleAvatar(
                    radius: 5,
                    backgroundColor:
                    connected ? Colors.greenAccent : Colors.grey,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: loading
          ? const Center(
        child: CircularProgressIndicator(color: Colors.red),
      )
          : Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.grey.shade50,
              child: messages.isEmpty
                  ? const Center(
                child: Text(
                  "No messages yet.",
                  style: TextStyle(color: Colors.grey),
                ),
              )
                  : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(15),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  return _chatBubble(
                    msg["text"] ?? "",
                    msg["isMe"] ?? false,
                    msg["sender"] ?? "",
                    msg["timestamp"] ?? "",
                  );
                },
              ),
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  // --- Chat Bubble ---
  Widget _chatBubble(
      String text, bool isMe, String sender, String timestamp) {
    final formattedTime = _formatTime(timestamp);
    final isSystem = sender == "System";

    // System message style
    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              text,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment:
        isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            " $sender",
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
          const SizedBox(height: 2),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe ? Colors.red.shade600 : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft:
                isMe ? const Radius.circular(16) : Radius.zero,
                bottomRight:
                isMe ? Radius.zero : const Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.black87,
                    fontSize: 15,
                  ),
                ),
                if (formattedTime.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    formattedTime,
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe ? Colors.white60 : Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Input Area ---
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: "Type emergency details...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _sendMessage(_controller.text),
              icon: Icon(
                Icons.send_rounded,
                color: connected ? Colors.red.shade700 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}