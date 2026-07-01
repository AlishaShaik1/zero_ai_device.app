/// Task plan and step models — the data structure Gemma reads and writes.
/// From core architecture §4: Plan-Execute-Verify loop.

/// A single step in a task plan.
class TaskStep {
  final int step;
  final int level; // 1, 2, 3, or 4
  final String action;
  final String target;
  final String actionHint;
  final int? dependsOn;
  final Map<String, dynamic> params;
  final int maxRetries;

  String status; // pending | blocked | in_progress | success | failed
  int retryCount;
  dynamic result;
  String? errorMessage;
  DateTime? startedAt;
  DateTime? completedAt;

  TaskStep({
    required this.step,
    required this.level,
    required this.action,
    required this.target,
    this.actionHint = '',
    this.dependsOn,
    this.params = const {},
    this.maxRetries = 1,
    this.status = 'pending',
    this.retryCount = 0,
    this.result,
    this.errorMessage,
    this.startedAt,
    this.completedAt,
  });

  bool get canExecute {
    return status == 'pending' && retryCount <= maxRetries;
  }

  bool get isTerminal {
    return status == 'success' || (status == 'failed' && retryCount >= maxRetries);
  }

  void markInProgress() {
    status = 'in_progress';
    startedAt = DateTime.now();
  }

  void markSuccess(dynamic resultData) {
    status = 'success';
    result = resultData;
    completedAt = DateTime.now();
  }

  void markFailed(String error, {bool isTransient = false}) {
    if (isTransient && retryCount < maxRetries) {
      retryCount++;
      status = 'pending'; // Will be retried
      errorMessage = error;
    } else {
      status = 'failed';
      errorMessage = error;
      completedAt = DateTime.now();
    }
  }

  Map<String, dynamic> toJson() => {
    'step': step,
    'level': level,
    'action': action,
    'target': target,
    'action_hint': actionHint,
    'depends_on': dependsOn,
    'params': params,
    'status': status,
    'retry_count': retryCount,
    'max_retries': maxRetries,
    'result': result,
    'error': errorMessage,
  };

  factory TaskStep.fromJson(Map<String, dynamic> json) => TaskStep(
    step: json['step'] as int,
    level: json['level'] as int? ?? 1,
    action: json['action'] as String,
    target: json['target'] as String,
    actionHint: json['action_hint'] as String? ?? '',
    dependsOn: json['depends_on'] as int?,
    params: Map<String, dynamic>.from(json['params'] as Map? ?? {}),
    maxRetries: json['max_retries'] as int? ?? 1,
    status: json['status'] as String? ?? 'pending',
    retryCount: json['retry_count'] as int? ?? 0,
    result: json['result'],
    errorMessage: json['error'] as String?,
  );
}

/// A complete task plan — the top-level container for multi-step execution.
class TaskPlan {
  final String id;
  final String userRequest;
  final List<TaskStep> steps;
  final DateTime createdAt;

  String status; // planning | in_progress | complete | plan_failed | needs_clarification
  String? clarificationQuestion;
  String? failureSummary;

  TaskPlan({
    required this.id,
    required this.userRequest,
    required this.steps,
    DateTime? createdAt,
    this.status = 'planning',
    this.clarificationQuestion,
    this.failureSummary,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Check if all dependencies for a step are satisfied.
  bool areDependenciesMet(TaskStep step) {
    if (step.dependsOn == null) return true;
    final dep = steps.firstWhere(
      (s) => s.step == step.dependsOn,
      orElse: () => step, // Self-reference = no dependency
    );
    return dep.status == 'success';
  }

  /// Get the next executable step.
  TaskStep? get nextStep {
    for (final step in steps) {
      if (step.status == 'pending' && areDependenciesMet(step)) {
        return step;
      }
    }
    return null;
  }

  /// Check if the plan is complete (all steps succeeded).
  bool get isComplete => steps.every((s) => s.status == 'success');

  /// Check if the plan has a fatal failure.
  bool get hasFatalFailure => steps.any((s) => s.isTerminal && s.status == 'failed');

  /// Update blocked steps based on dependency failures.
  void updateBlockedSteps() {
    for (final step in steps) {
      if (step.dependsOn != null && step.status == 'pending') {
        final dep = steps.firstWhere(
          (s) => s.step == step.dependsOn,
          orElse: () => step,
        );
        if (dep.status == 'failed' && dep.isTerminal) {
          step.status = 'blocked';
        }
      }
    }
  }

  Map<String, dynamic> toJson() => {
    'task_id': id,
    'status': status,
    'clarification_question': clarificationQuestion,
    'failure_summary': failureSummary,
    'steps': steps.map((s) => s.toJson()).toList(),
  };
}
