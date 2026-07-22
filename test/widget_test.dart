import 'package:flutter_test/flutter_test.dart';

import 'package:lifeos_ai/core/services/receipt_text_parser.dart';
import 'package:lifeos_ai/core/utils/password_hasher.dart';
import 'package:lifeos_ai/core/utils/list_codec.dart';
import 'package:lifeos_ai/features/assistant/domain/lifeos_ai_engine.dart';
import 'package:lifeos_ai/features/tasks/domain/task.dart';

void main() {
  test('PasswordHasher hashes consistently', () {
    final String hash = PasswordHasher.hash('secret123');
    expect(PasswordHasher.verify('secret123', hash), isTrue);
    expect(PasswordHasher.verify('wrong', hash), isFalse);
  });

  test('ListCodec round-trips values', () {
    const List<String> values = <String>['work', 'urgent'];
    expect(ListCodec.decode(ListCodec.encode(values)), values);
    expect(ListCodec.decode(null), isEmpty);
  });

  test('LifeOsAiEngine prioritizes urgent tasks', () {
    const LifeOsAiEngine engine = LifeOsAiEngine();
    final String reply = engine.respond(
      userMessage: 'What should I prioritize?',
      tasks: const <Task>[
        Task(id: '1', title: 'Ship release', isCompleted: false, priority: TaskPriority.urgent),
        Task(id: '2', title: 'Clean desk', isCompleted: false, priority: TaskPriority.low),
      ],
    );
    expect(reply.toLowerCase(), contains('ship release'));
  });

  test('ReceiptTextParser extracts amount and category hints', () {
    final ReceiptParseResult result = ReceiptTextParser.parse(
      'Blue Bottle Coffee\nLatte\nTotal \$12.50\nThank you',
    );
    expect(result.amount, 12.50);
    expect(result.description, 'Blue Bottle Coffee');
    expect(result.category, 'Food');
  });
}
