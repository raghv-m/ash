import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/chat/chat_interface.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat with ASH'),
        actions: [
          IconButton(
            icon: const Icon(Icons.voice_chat),
            onPressed: () {
              // TODO: Implement voice chat
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Voice chat coming soon!')),
              );
            },
          ),
        ],
      ),
      body: const ChatInterface(),
    );
  }
}

