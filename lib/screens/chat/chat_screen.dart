import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signsync/config/providers.dart';
import 'package:signsync/models/chat_message.dart';
import 'package:signsync/services/api_service.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/core/theme/colors.dart';
import 'package:signsync/utils/constants.dart';

/// Chat screen for AI-powered conversation.
///
/// This screen provides a chat interface for users to interact
/// with the SignSync AI assistant.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    LoggerService.info('Chat screen initialized');

    // Add welcome message
    _messages.add(
      ChatMessage.ai(
        content: 'Hello! I\'m SignSync AI. How can I help you with sign language today?',
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    // Add user message
    final userMessage = ChatMessage.user(content: text);
    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });

    // Clear input
    _controller.clear();

    // Scroll to bottom
    _scrollToBottom();

    try {
      // Get AI response
      final chatService = ChatApiService();
      final response = await chatService.sendMessage(
        message: text,
        conversationHistory: _messages,
      );

      setState(() => _isLoading = false);
      _messages.add(response);
      _scrollToBottom();

      LoggerService.info('AI response generated');
    } catch (e, stack) {
      LoggerService.error('Failed to get AI response', error: e, stack: stack);
      setState(() => _isLoading = false);

      _messages.add(
        ChatMessage.error('Failed to get response. Please try again.'),
      );
      _scrollToBottom();
    }
  }

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

  Future<void> _clearChat() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text('Are you sure you want to clear all messages?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (shouldClear == true) {
      setState(() => _messages.clear());
      _messages.add(
        ChatMessage.ai(
          content: 'Chat cleared. How can I help you?',
        ),
      );
    }
  }

  void _showQuickSuggestions() {
    final suggestions = [
      'What does this sign mean?',
      'Teach me a new sign',
      'How do I say "Hello"?',
      'Tell me about ASL',
    ];

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Quick Questions',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppConstants.spacingMd),
            Wrap(
              spacing: AppConstants.spacingSm,
              children: suggestions.map((suggestion) {
                return ActionChip(
                  label: Text(suggestion),
                  onPressed: () {
                    _controller.text = suggestion;
                    Navigator.pop(context);
                    _sendMessage();
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          children: [
            Text('AI Chat'),
            Text(
              'SignSync Assistant',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.lightbulb),
            onPressed: _showQuickSuggestions,
            tooltip: 'Suggestions',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _clearChat,
            tooltip: 'Clear Chat',
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: _buildMessagesList(),
          ),

          // Input Area
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _buildMessageBubble(message);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final color = isUser
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.surfaceVariant;
    final textColor = isUser
        ? Theme.of(context).colorScheme.onPrimary
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppConstants.spacingXs),
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppConstants.radiusLg),
            topRight: const Radius.circular(AppConstants.radiusLg),
            bottomLeft: Radius.circular(isUser ? AppConstants.radiusLg : AppConstants.radiusSm),
            bottomRight: Radius.circular(isUser ? AppConstants.radiusSm : AppConstants.radiusLg),
          ),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: message.isLoading
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text('Thinking...'),
                ],
              )
            : Text(
                message.content,
                style: TextStyle(color: textColor),
              ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: SafeArea(
        child: Row(
          children: [
            // Quick Actions
            IconButton(
              icon: const Icon(Icons.lightbulb_outline),
              onPressed: _showQuickSuggestions,
              tooltip: 'Suggestions',
            ),
            const SizedBox(width: AppConstants.spacingSm),
            // Text Input
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(AppConstants.radiusCircular),
                    ),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingMd,
                    vertical: AppConstants.spacingSm,
                  ),
                ),
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: AppConstants.spacingSm),
            // Send Button
            FilledButton(
              onPressed: _isLoading ? null : _sendMessage,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(AppConstants.spacingMd),
                shape: const CircleBorder(),
              ),
              child: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
