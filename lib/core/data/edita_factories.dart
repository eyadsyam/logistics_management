/// All Edita Food Industries factory data.
///
/// Each factory has:
///  - A unique code (e.g. E06)
///  - City and full address
///  - GPS coordinates (approximate based on industrial zone data)
///  - List of product categories manufactured
///  - List of brand names produced
///
/// Used to auto-assign the nearest/correct factory based on the
/// product the client selects when creating a shipment.
library;

class EditaFactory {
  final String id;
  final String name;
  final String city;
  final String address;
  final double latitude;
  final double longitude;
  final List<String> productCategories;
  final List<String> brands;

  const EditaFactory({
    required this.id,
    required this.name,
    required this.city,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.productCategories,
    required this.brands,
  });

  /// Human-readable label: "E06 — 6th of October"
  String get label => '$id — $city';
}

/// Master list of Edita factories (official data up to 2025/2026).
const List<EditaFactory> editaFactories = [
  EditaFactory(
    id: 'E06',
    name: 'Edita Factory E06',
    city: '6th of October City',
    address: 'Industrial Zone, 6th of October City, Giza, Egypt',
    latitude: 29.9601,
    longitude: 30.9110,
    productCategories: ['Bakery', 'Cake', 'Rusks'],
    brands: ['Molto', 'TODO', 'Bake Rolz', 'Bake Stix'],
  ),
  EditaFactory(
    id: 'E07',
    name: 'Edita Factory E07',
    city: '6th of October City',
    address: 'Industrial Zone A3, 6th of October City, Giza, Egypt',
    latitude: 29.9634,
    longitude: 30.9175,
    productCategories: ['Bakery', 'Cake', 'Wafers', 'Rusks'],
    brands: ['Molto', 'Freska', 'TODO', 'Bake Rolz'],
  ),
  EditaFactory(
    id: 'E08',
    name: 'Edita Factory E08',
    city: '6th of October City',
    address: 'Industrial Zone B, 6th of October City, Giza, Egypt',
    latitude: 29.9580,
    longitude: 30.9220,
    productCategories: ['Cake', 'Wafers', 'Biscuit'],
    brands: ['Freska', 'Oniro', 'TODO', 'Twinkies'],
  ),
  EditaFactory(
    id: 'E09',
    name: 'Edita Factory E09',
    city: '6th of October City',
    address: 'Industrial Zone C, 6th of October City, Giza, Egypt',
    latitude: 29.9550,
    longitude: 30.9250,
    productCategories: ['Frozen'],
    brands: ['Molto Forni', 'Frozen Pizza'],
  ),
  EditaFactory(
    id: 'E10',
    name: 'Edita Factory E10',
    city: '10th of Ramadan City',
    address: 'Industrial Zone, 10th of Ramadan City, Sharqia, Egypt',
    latitude: 30.2962,
    longitude: 31.7341,
    productCategories: ['Cake'],
    brands: ['TODO', 'Twinkies', 'HOHOs', 'Tiger Tail'],
  ),
  EditaFactory(
    id: 'E15',
    name: 'Edita Factory E15',
    city: 'Beni Suef',
    address: 'Industrial Zone, Beni Suef City, Beni Suef, Egypt',
    latitude: 29.0661,
    longitude: 31.0994,
    productCategories: ['Candy'],
    brands: ['MiMix', 'Dolce', 'Jellix'],
  ),
];

/// Returns the best-match factory for a given brand name.
///
/// Priority: exact brand match → first factory that lists the brand.
/// If no match, returns the first factory (E06) as default.
EditaFactory getFactoryForBrand(String brandName) {
  final lower = brandName.toLowerCase().trim();

  for (final factory in editaFactories) {
    for (final brand in factory.brands) {
      if (brand.toLowerCase() == lower) {
        return factory;
      }
    }
  }

  // Partial match fallback
  for (final factory in editaFactories) {
    for (final brand in factory.brands) {
      if (brand.toLowerCase().contains(lower) ||
          lower.contains(brand.toLowerCase())) {
        return factory;
      }
    }
  }

  return editaFactories.first; // Default: E06
}

/// Returns all factories that produce a given product category.
List<EditaFactory> getFactoriesForCategory(String category) {
  final lower = category.toLowerCase().trim();
  return editaFactories
      .where(
        (f) => f.productCategories.any((c) => c.toLowerCase().contains(lower)),
      )
      .toList();
}
