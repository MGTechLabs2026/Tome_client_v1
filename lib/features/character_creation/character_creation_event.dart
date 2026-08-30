// lib/features/character_creation/character_creation_event.dart
sealed class CharacterCreationEvent {
  const CharacterCreationEvent();
}

class NameSubmitted extends CharacterCreationEvent {
  const NameSubmitted(this.name);
  final String name;
}

class StyleChosen extends CharacterCreationEvent {
  const StyleChosen(this.styleId);
  final String styleId;
}
