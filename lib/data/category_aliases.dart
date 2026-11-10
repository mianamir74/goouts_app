/// One answer to "which GoOuts category is this partner in", whatever was
/// typed into the partner's free text `category` field ("Historic Pub",
/// "Cocktail Bar", "Pubs", "Bars"...). Added 10 Nov 2026 when Pubs and Bars
/// became one category, "Pubs & Bars".
String canonicalCategory(String raw) {
  var v = raw.toLowerCase().trim();
  v = v.replaceAll('é', 'e').replaceAll('è', 'e');
  if (v.isEmpty) return '';
  if (v.contains('comedy')) return 'comedy';
  if (v.contains('lounge') || v.contains('shisha')) return 'lounges';
  if (v.contains('music') || v.contains('concert') || v.contains('jazz')) return 'music';
  if (v.contains('pub') ||
      (RegExp(r'(^|\s)bars?$').hasMatch(v) &&
          !v.contains('restaurant') && !v.contains('cafe'))) {
    return 'pubs & bars';
  }
  if (v.contains('club')) return 'clubs';
  if (v.contains('cafe') || v.contains('coffee')) return 'cafes';
  if (v.contains('fast food') || v.contains('chicken') || v.contains('pizza') ||
      v.contains('burger') || v.contains('kebab') || v.contains('fish & chips')) {
    return 'fast food';
  }
  if (v.contains('restaurant') || v.contains('dining') || v.contains('brasserie')) {
    return 'restaurants';
  }
  if (v.contains('home needs')) return 'home needs';
  return v.endsWith('s') ? v : '${v}s';
}

/// Display name used by Category Management for the merged category.
const String kPubsAndBars = 'Pubs & Bars';
