import 'package:flutter_test/flutter_test.dart';

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
}
