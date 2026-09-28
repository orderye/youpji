import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/theme_constants.dart';
import '../../providers/chat_provider.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('游迹 AI 旅游助手'),
        actions: [
          if (chatState.sessionId != null)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Center(
                child: Text(
                  '会话中',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.verifiedGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // 聊天气泡列表
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: chatState.messages.length,
              itemBuilder: (context, index) {
                final msg = chatState.messages[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),

          // 发送等待指示
          if (chatState.isSending)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'AI 正在核对官方景区事实...',
                    style: TextStyle(fontSize: 12, color: AppTheme.mutedGray),
                  ),
                ],
              ),
            ),

          // 底部输入框
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE9E3D6))),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      decoration: const InputDecoration(
                        hintText: '向游迹助手提问（如：黄果树门票多少钱？）',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty) {
                          ref.read(chatProvider.notifier).sendMessage(val.trim());
                          _msgCtrl.clear();
                          _scrollToBottom();
                        }
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: AppTheme.primaryBlue),
                    onPressed: () {
                      final val = _msgCtrl.text.trim();
                      if (val.isNotEmpty) {
                        ref.read(chatProvider.notifier).sendMessage(val);
                        _msgCtrl.clear();
                        _scrollToBottom();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(dynamic msg) {
    final isUser = msg.isUser as bool;
    final text = msg.text as String;
    final sources = (msg.sources as List<String>?) ?? [];
    final suggestions = (msg.suggestions as List<String>?) ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.primaryBlue,
                  child: Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUser ? AppTheme.primaryBlue : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: isUser ? null : Border.all(color: const Color(0xFFE9E3D6)),
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 14,
                      color: isUser ? Colors.white : AppTheme.darkInk,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // 来源标注
          if (sources.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Wrap(
                spacing: 6,
                children: sources.map((s) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.cyan.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '来源: $s',
                      style: const TextStyle(fontSize: 10, color: AppTheme.cyan),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // 快捷联想气泡
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: suggestions.map((sug) {
                  return ActionChip(
                    label: Text(sug, style: const TextStyle(fontSize: 12)),
                    onPressed: () {
                      ref.read(chatProvider.notifier).sendMessage(sug);
                      _scrollToBottom();
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
