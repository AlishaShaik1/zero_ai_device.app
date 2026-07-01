class MemoryAllocator {
  // 128K context budget
  static const int maxBudget = 128000;
  
  Map<String, int> zones = {
    'system_prompt': 3000,
    'connector_schema': 4000,
    'task_list': 3000,
    'chat_memory': 8000,
    'entity_context': 1000,
    'scratch': maxBudget - 19000
  };

  String allocatePrompt({
    required String system,
    required String schema,
    required String taskList,
    required String memory,
    required String context
  }) {
    // Trim and enforce budget limits in actual implementation
    return "$system\n$schema\n$taskList\n$memory\n$context";
  }
}
