import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/features/chat/data/models/chat_conversation_model.dart';

void main() {
  group('ChatConversationDetail.fromResponse', () {
    const envelope = {
      'success': true,
      'data': {
        'conversation': {'id': 12, 'delivery_id': 86},
        'messages': [
          {'id': 1, 'message': 'Hello', 'created_at': '2026-08-17T10:00:00Z'},
          {'id': 2, 'message': 'Ui', 'created_at': '2026-08-17T10:01:00Z'},
        ],
        'participants': [],
        'has_left': false,
        'related_info': null,
      },
    };

    test('reads nested conversation, messages, and has_left', () {
      final detail = ChatConversationDetail.fromResponse(envelope);

      expect(detail.conversation?.id, 12);
      expect(detail.conversation?.deliveryId, 86);
      expect(detail.messages.map((m) => m.text), ['Hello', 'Ui']);
      expect(detail.hasLeft, isFalse);
      expect(ChatConversation.conversationIdFromResponse(envelope), 12);
    });

    test('treats has_left with empty messages as success', () {
      final detail = ChatConversationDetail.fromResponse({
        'success': true,
        'data': {
          'conversation': {'id': 12},
          'messages': [],
          'participants': [],
          'has_left': true,
          'related_info': null,
        },
      });

      expect(detail.hasLeft, isTrue);
      expect(detail.messages, isEmpty);
      expect(detail.conversation?.id, 12);
    });
  });
}
