class Medal {
  final String id;
  final String title;
  final String description;
  final String iconAsset;
  final bool isUnlocked;

  Medal({
    required this.id,
    required this.title,
    required this.description,
    required this.iconAsset,
    this.isUnlocked = false,
  });

  Medal copyWith({bool? isUnlocked}) {
    return Medal(
      id: id,
      title: title,
      description: description,
      iconAsset: iconAsset,
      isUnlocked: isUnlocked ?? this.isUnlocked,
    );
  }
}

final List<Medal> initialMedals = [
  Medal(
    id: 'first_step',
    title: 'Primer Paso',
    description: 'Completa tu primer nivel.',
    iconAsset: 'assets/medals/first_step.png',
  ),
  Medal(
    id: 'math_genius',
    title: 'Genio Matemático',
    description: 'Llega al nivel 10.',
    iconAsset: 'assets/medals/genius.png',
  ),
  Medal(
    id: 'speed_runner',
    title: 'Velocista',
    description: 'Resuelve un nivel en menos de 20 segundos.',
    iconAsset: 'assets/medals/speed.png',
  ),
  Medal(
    id: 'persistent',
    title: 'Perseverante',
    description: 'Juega 5 partidas seguidas.',
    iconAsset: 'assets/medals/persistent.png',
  ),
];
