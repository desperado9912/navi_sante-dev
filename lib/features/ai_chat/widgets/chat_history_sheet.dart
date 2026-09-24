import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../viewmodel/ai_chat_bloc.dart';
import '../models/ai_chat_models.dart';
import 'ai_chat_style.dart';

Future<void> showChatHistorySheet(BuildContext context) {
  final bloc = context.read<AiChatBloc>();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) =>
        BlocProvider.value(value: bloc, child: const ChatHistorySheet()),
  );
}

class ChatHistorySheet extends StatelessWidget {
  const ChatHistorySheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.72,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      t(context, 'Chat history', 'Historique'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      context.read<AiChatBloc>().add(AiChatNewConversation());
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(t(context, 'New chat', 'Nouveau')),
                    style: TextButton.styleFrom(foregroundColor: kNaviTeal),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: BlocBuilder<AiChatBloc, AiChatState>(
                builder: (context, state) {
                  if (state.conversations.isEmpty) {
                    return Center(
                      child: Text(
                        t(
                          context,
                          'No conversations yet',
                          'Aucune conversation',
                        ),
                        style: const TextStyle(color: Color(0xFF5F6368)),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                    itemCount: state.conversations.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final conv = state.conversations[index];
                      return ListTile(
                        selected: conv.id == state.activeId,
                        selectedTileColor: const Color(0xFFD8F6FF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        title: Text(
                          conv.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          _relative(context, conv.updatedAt),
                          style: const TextStyle(fontSize: 12),
                        ),
                        onTap: () {
                          context.read<AiChatBloc>().add(
                            AiChatOpenConversation(conv.id),
                          );
                          Navigator.pop(context);
                        },
                        trailing: IconButton(
                          tooltip: t(context, 'Delete', 'Supprimer'),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Color(0xFF5F6368),
                          ),
                          onPressed: () => _confirmDelete(context, conv),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, ChatConversation conv) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(t(context, 'Delete chat?', 'Supprimer ?')),
          content: Text(
            t(
              context,
              '“${conv.title}” will be removed from this device.',
              '« ${conv.title} » sera retiré de cet appareil.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(t(context, 'Cancel', 'Annuler')),
            ),
            TextButton(
              onPressed: () {
                context.read<AiChatBloc>().add(
                  AiChatDeleteConversation(conv.id),
                );
                Navigator.pop(dialogContext);
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFC62828),
              ),
              child: Text(t(context, 'Delete', 'Supprimer')),
            ),
          ],
        );
      },
    );
  }

  String _relative(BuildContext context, int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    final diff = DateTime.now().difference(dt);
    final fr = isFrench(context);
    if (diff.inMinutes < 1) return t(context, 'Just now', 'À l’instant');
    if (diff.inMinutes < 60) {
      return fr ? 'Il y a ${diff.inMinutes} min' : '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return fr ? 'Il y a ${diff.inHours} h' : '${diff.inHours}h ago';
    }
    if (diff.inDays < 7) {
      return fr ? 'Il y a ${diff.inDays} j' : '${diff.inDays}d ago';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
