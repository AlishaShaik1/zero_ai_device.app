import 'dart:async';

import 'models/task_models.dart' as task_models;

class TaskStep extends task_models.TaskStep {
  TaskStep({
    required int step,
    required String action,
    required String target,
    String actionHint = '',
    int? dependsOn,
    Map<String, dynamic> params = const {},
    int maxRetries = 1,
    String status = 'pending',
    int retryCount = 0,
    dynamic result,
    String? errorMessage,
    DateTime? startedAt,
    DateTime? completedAt,
    int level = 1,
  }) : super(
          step: step,
          level: level,
          action: action,
          target: target,
          actionHint: actionHint,
          dependsOn: dependsOn,
          params: params,
          maxRetries: maxRetries,
          status: status,
          retryCount: retryCount,
          result: result,
          errorMessage: errorMessage,
          startedAt: startedAt,
          completedAt: completedAt,
        );
}

class TaskPlan extends task_models.TaskPlan {
  TaskPlan({
    required String id,
    required String request,
    required List<TaskStep> steps,
    DateTime? createdAt,
    String status = 'planning',
    String? clarificationQuestion,
    String? failureSummary,
  }) : super(
          id: id,
          userRequest: request,
          steps: steps,
          createdAt: createdAt,
          status: status,
          clarificationQuestion: clarificationQuestion,
          failureSummary: failureSummary,
        );

  String get request => userRequest;
}

class TaskExecutor {
  Future<void> executePlan(TaskPlan plan) async {
    for (final step in plan.steps) {
      if (step.status == 'blocked' || step.status == 'failed') {
        break;
      }

      if (!plan.areDependenciesMet(step)) {
        step.status = 'blocked';
        continue;
      }

      step.markInProgress();
      await Future<void>.delayed(Duration.zero);
      step.markSuccess({'info': 'done'});
    }

    plan.updateBlockedSteps();
  }
}
