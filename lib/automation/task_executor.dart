class TaskStep {
  int step;
  String action;
  String target;
  Map<String, dynamic> params;
  String status;
  dynamic result;

  TaskStep({
    required this.step,
    required this.action,
    required this.target,
    this.params = const {},
    this.status = 'pending',
    this.result,
  });
}

class TaskPlan {
  String id;
  String request;
  List<TaskStep> steps;

  TaskPlan({required this.id, required this.request, required this.steps});
}

class TaskExecutor {
  Future<void> executePlan(TaskPlan plan) async {
    for (var step in plan.steps) {
      if (step.status == 'blocked' || step.status == 'failed') {
        break; // Dependent steps stay blocked
      }
      
      try {
        // Execute single tool call
        // A step only advances on status: success
        step.status = 'success';
        step.result = {'info': 'done'};
      } catch (e) {
        step.status = 'failed';
        break;
      }
    }
  }
}
