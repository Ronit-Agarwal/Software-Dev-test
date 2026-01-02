import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:signsync/config/providers.dart';
import 'package:signsync/models/chat_message.dart';
import 'package:signsync/services/gemini_ai_service.dart';
import 'package:signsync/services/chat_history_service.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/core/theme/colors.dart';
import 'package:signsync/utils/constants.dart';

/// Chat screen for AI-powered conversation.
///
/// This screen provides a chat interface for users to interact
/// with the SignSync AI assistant using Gemini 2.5.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SpeechToText _speechToText = SpeechToText();
  
  bool _isLoading = false;
  bool _isListening = false;
  bool _voiceEnabled = false;

  @override
  void initState() {
    super.initState();
    LoggerService.info('Chat screen initialized');
    _loadChatHistory();
    _initSpeech();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _speechToText.cancel();
    super.dispose();
  }

  Future<void> _loadChatHistory() async {
    try {
      final historyService = ref.read(chatHistoryServiceProvider);
      if (historyService.isInitialized) {
        final messages = await historyService.getRecentMessages(50);
        if (messages.isNotEmpty) {
          setState(() => _messages.addAll(messages.reversed));
          _scrollToBottom();
        }
      }
    } catch (e) {
      LoggerService.error('Failed to load chat history', error: e);
    }
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speechToText.initialize();
      if (mounted) {
        setState(() => _isListening = available);
      }
    } catch (e) {
      LoggerService.error('Failed to initialize speech recognition', error: e);
    }
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

    // Save to history
    final historyService = ref.read(chatHistoryServiceProvider);
    if (historyService.isInitialized) {
      await historyService.addMessage(userMessage);
    }

    // Clear input
    _controller.clear();

    // Scroll to bottom
    _scrollToBottom();

    try {
      // Get AI response
      final aiService = ref.read(geminiAiServiceProvider);
      final response = await aiService.sendMessage(text);

      setState(() => _isLoading = false);
      _messages.add(response);
      _scrollToBottom();

      // Save to history
      if (historyService.isInitialized) {
        await historyService.addMessage(response);
      }

      LoggerService.info('AI response generated');
    } catch (e, stack) {
      LoggerService.error('Failed to get AI response', error: e, stack: stack);
      setState(() => _isLoading = false);

      final errorMessage = ChatMessage.error('Failed to get response. Please try again.');
      _messages.add(errorMessage);
      _scrollToBottom();

      if (historyService.isInitialized) {
        await historyService.addMessage(errorMessage);
      }
    }
  }

  Future<void> _startListening() async {
    if (!_isListening || _isLoading) return;

    setState(() => _isListening = true);

    await _speechToText.listen(
      onResult: (result) {
        if (result.finalResult) {
          setState(() {
            _controller.text = result.recognizedWords;
            _isListening = false;
          });
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
    );
  }

  void _stopListening() {
    _speechToText.stop();
    setState(() => _isListening = false);
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
      
      final historyService = ref.read(chatHistoryServiceProvider);
      if (historyService.isInitialized) {
        await historyService.clearAll();
      }

      _messages.add(
        ChatMessage.ai(
          content: 'Chat cleared. How can I help you?',
        ),
      );
    }
  }

  void _showQuickSuggestions() {
    final aiService = ref.read(geminiAiServiceProvider);
    final suggestions = aiService.getSuggestedResponses();

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Suggested Questions',
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

  void _toggleVoice() {
    setState(() {
      _voiceEnabled = !_voiceEnabled;
    });
    ref.read(geminiAiServiceProvider).setVoiceEnabled(_voiceEnabled);
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
            icon: Icon(_voiceEnabled ? Icons.volume_up : Icons.volume_off),
            onPressed: _toggleVoice,
            tooltip: _voiceEnabled ? 'Voice Output On' : 'Voice Output Off',
            color: _voiceEnabled ? Theme.of(context).colorScheme.primary : null,
          ),
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
            // Voice Input Button
            IconButton(
              icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
              onPressed: _isLoading ? null : (_isListening ? _stopListening : _startListening),
              tooltip: _isListening ? 'Stop Listening' : 'Voice Input',
              color: _isListening ? Colors.red : null,
            ),
            const SizedBox(width: AppConstants.spacingSm),
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
                decoration: InputDecoration(
                  hintText: _isListening ? 'Listening...' : 'Type a message...',
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(AppConstants.radiusCircular),
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
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
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
