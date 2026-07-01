import 'package:flutter_test/flutter_test.dart';
import 'package:zero_ring_app/automation/connector_registry.dart';
import 'package:zero_ring_app/automation/task_executor.dart';

void main() {
  group('ConnectorRegistry Gate Logic', () {
    test('Proceed on exact match and connected', () {
      final registry = ConnectorRegistry();
      final result = registry.gateCheck('gemini');
      
      expect(result['status'], equals('proceed'));
      expect(result['connector'].id, equals('gemini_app'));
    });

    test('Stop on unknown app', () {
      final registry = ConnectorRegistry();
      final result = registry.gateCheck('unknown_app');
      
      expect(result['status'], equals('stop'));
      expect(result['message'], contains('I don\'t have unknown_app set up'));
    });
  });

  group('Plan Integrity', () {
    test('Dependent step does not fire if prior step fails', () async {
      final executor = TaskExecutor();
      
      final plan = TaskPlan(
        id: '1',
        request: 'do something',
        steps: [
          TaskStep(step: 1, action: 'check', target: 'app1', status: 'pending'),
          TaskStep(step: 2, action: 'generate', target: 'app2', status: 'failed'),
          TaskStep(step: 3, action: 'send', target: 'app3', status: 'pending'), // Should be blocked
        ]
      );
      
      await executor.executePlan(plan);
      
      expect(plan.steps[0].status, equals('success'));
      expect(plan.steps[1].status, equals('failed'));
      expect(plan.steps[2].status, equals('pending'));
    });
  });
}
