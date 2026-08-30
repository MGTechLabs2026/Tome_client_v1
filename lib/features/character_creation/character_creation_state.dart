// lib/features/character_creation/character_creation_state.dart
import '../../core/models/character_view.dart';

class CharacterCreationState {
  const CharacterCreationState({
    this.name,
    this.availableStyles = const [],
    this.synergyByStyle = const {},
    this.character,
    this.confirmed = false,
  });

  final String? name;
  final List<String> availableStyles;
  final Map<String, String?> synergyByStyle;
  final CharacterView? character;
  final bool confirmed;

  CharacterCreationState copyWith({
    String? name,
    List<String>? availableStyles,
    Map<String, String?>? synergyByStyle,
    CharacterView? character,
    bool? confirmed,
  }) =>
      CharacterCreationState(
        name: name ?? this.name,
        availableStyles: availableStyles ?? this.availableStyles,
        synergyByStyle: synergyByStyle ?? this.synergyByStyle,
        character: character ?? this.character,
        confirmed: confirmed ?? this.confirmed,
      );
}
