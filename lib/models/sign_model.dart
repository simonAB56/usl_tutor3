class SignModel {
  final String label;
  final String description;
  final String category; // 'number' or 'letter'
  final bool isMotion; // true for J, Z

  const SignModel({
    required this.label,
    required this.description,
    required this.category,
    this.isMotion = false,
  });

  String get imagePath => 'assets/images/signs/$label.png';

  static List<SignModel> get allSigns => [
    ...List.generate(
      11,
      (i) => SignModel(
        label: '$i',
        description: 'The number $i in Ugandan Sign Language',
        category: 'number',
      ),
    ),
    ...List.generate(26, (i) {
      final letter = String.fromCharCode(65 + i);
      return SignModel(
        label: letter,
        description: 'The letter $letter in Ugandan Sign Language',
        category: 'letter',
        isMotion: letter == 'J' || letter == 'Z',
      );
    }),
  ];

  static List<SignModel> get numbers =>
      allSigns.where((s) => s.category == 'number').toList();

  static List<SignModel> get letters =>
      allSigns.where((s) => s.category == 'letter').toList();
}
