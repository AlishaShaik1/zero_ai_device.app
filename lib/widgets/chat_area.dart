import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart';
import '../services/conversation_manager.dart';

class ChatArea extends StatefulWidget {
  final ConversationManager conversationManager;

  const ChatArea({Key? key, required this.conversationManager}) : super(key: key);

  @override
  State<ChatArea> createState() => _ChatAreaState();
}

class _ChatAreaState extends State<ChatArea> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.conversationManager.addListener(_scrollToBottom);
  }

  @override
  void dispose() {
    widget.conversationManager.removeListener(_scrollToBottom);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    // Use a post-frame callback so the scroll happens AFTER the ListView
    // has laid out the new message. Without this, the final completed message
    // can end up below the visible scroll area.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100, // Overscroll slightly for new items
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: widget.conversationManager,
        builder: (context, child) {
          final history = widget.conversationManager.history;
          final streamingMsg = widget.conversationManager.currentStreamingMessage;
          
          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120), // Padding for bottom bar
            itemCount: history.length + (streamingMsg.isNotEmpty ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == history.length) {
                // Render streaming message
                return _ChatBubble(
                  content: streamingMsg,
                  isUser: false,
                  isStreaming: true,
                );
              }
              final msg = history[index];
              return _ChatBubble(
                content: msg['content'] ?? '',
                isUser: msg['role'] == 'user',
                isStreaming: false,
              );
            },
          );
        },
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String content;
  final bool isUser;
  final bool isStreaming;

  const _ChatBubble({
    Key? key,
    required this.content,
    required this.isUser,
    this.isStreaming = false,
  }) : super(key: key);

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF333333),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              margin: const EdgeInsets.only(right: 12, top: 4),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF00C9C8), Color(0xFF00E5FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00C9C8).withValues(alpha: 0.3),
                    blurRadius: 8,
                  )
                ],
              ),
              child: const Icon(Icons.lens_blur_rounded, color: Color(0xFF0A0A0F), size: 18),
            ),
          ],
          
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF1E1E28) : Colors.transparent,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                border: isUser ? null : Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isUser)
                    MarkdownBody(
                      data: content + (isStreaming ? " ⬤" : ""), // Add typing indicator cursor
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 15, height: 1.5),
                        code: TextStyle(
                          backgroundColor: Colors.black.withValues(alpha: 0.5),
                          color: const Color(0xFF00E5FF),
                          fontFamily: 'monospace',
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    )
                  else
                    Text(
                      content,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 15, height: 1.4),
                    ),
                    
                  if (!isUser && !isStreaming)
                    Align(
                      alignment: Alignment.bottomRight,
                      child: GestureDetector(
                        onTap: () => _copyToClipboard(context),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Icon(Icons.copy_rounded, size: 16, color: Colors.white.withValues(alpha: 0.3)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          if (isUser) const SizedBox(width: 32), // spacer for user alignment
        ],
      ),
    );
  }
}
