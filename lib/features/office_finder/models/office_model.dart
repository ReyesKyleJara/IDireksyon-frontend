class OfficeModel {
  final String id;
  final String name;
  final String address;
  final String distance;
  final String operatingHours;
  final String serviceTag;
  final double latitude;
  final double longitude;

  const OfficeModel({
    required this.id,
    required this.name,
    required this.address,
    required this.distance,
    required this.operatingHours,
    required this.serviceTag,
    required this.latitude,
    required this.longitude,
  });
}