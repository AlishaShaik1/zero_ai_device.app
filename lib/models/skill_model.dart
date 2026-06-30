class SkillModel {
  final String id;
  final String name;
  final String description;
  final String iconEmoji;
  bool isActive;
  final List<String> toolNames;

  SkillModel({
    required this.id,
    required this.name,
    required this.description,
    required this.iconEmoji,
    this.isActive = true,
    required this.toolNames,
  });

  SkillModel copyWith({
    String? id,
    String? name,
    String? description,
    String? iconEmoji,
    bool? isActive,
    List<String>? toolNames,
  }) {
    return SkillModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconEmoji: iconEmoji ?? this.iconEmoji,
      isActive: isActive ?? this.isActive,
      toolNames: toolNames ?? this.toolNames,
    );
  }
}
