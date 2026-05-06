enum DivisionSymbol { slash, obelus, colon }

class MathSettings {
  final bool isDarkMode;
  final DivisionSymbol divisionSymbol;

  MathSettings({
    this.isDarkMode = true,
    this.divisionSymbol = DivisionSymbol.obelus, // ÷
  });

  String get divisionString {
    switch (divisionSymbol) {
      case DivisionSymbol.slash: return '/';
      case DivisionSymbol.obelus: return '÷';
      case DivisionSymbol.colon: return ':';
    }
  }
}
