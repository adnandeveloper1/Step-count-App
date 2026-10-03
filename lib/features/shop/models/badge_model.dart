class BadgeModel {
  final String id;
  final String title;
  final String description;
  final int requiredSteps;
  final bool isUnlocked;
  final String iconName;

  const BadgeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.requiredSteps,
    required this.isUnlocked,
    required this.iconName,
  });

  BadgeModel copyWith({
    String? id,
    String? title,
    String? description,
    int? requiredSteps,
    bool? isUnlocked,
    String? iconName,
  }) {
    return BadgeModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      requiredSteps: requiredSteps ?? this.requiredSteps,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      iconName: iconName ?? this.iconName,
    );
  }
}