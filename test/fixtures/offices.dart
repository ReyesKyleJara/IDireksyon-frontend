import 'package:idireksyon_frontend/features/office_finder/map_services.dart';
import 'package:idireksyon_frontend/features/office_finder/models/office_model.dart';
import 'package:latlong2/latlong.dart';

const dfaMalolos = OfficeModel(
  id: '1',
  name: 'DFA Consular Office Malolos',
  agency: 'DFA',
  agencyName: 'Department of Foreign Affairs',
  address: 'SM City Malolos, McArthur Highway',
  records: ['Philippine Passport'],
  latitude: 14.8527,
  longitude: 120.8160,
);

const sssSantaMaria = OfficeModel(
  id: '2',
  name: 'SSS Santa Maria Branch',
  agency: 'SSS',
  address: 'Poblacion, Santa Maria, Bulacan',
  records: ['MySSS Card'],
  latitude: 14.8188,
  longitude: 120.9578,
);

const postOffice = OfficeModel(
  id: '3',
  name: 'Malolos Post Office',
  address: 'Malolos, Bulacan',
  records: ['Postal ID'],
  latitude: 14.8433,
  longitude: 120.8120,
);

const testOffices = [dfaMalolos, sssSantaMaria, postOffice];

/// Returns offices without touching the network.
class FixtureOfficeServices extends OfficeMapServices {
  FixtureOfficeServices({this.list = testOffices});
  final List<OfficeModel> list;

  @override
  Future<List<OfficeModel>> offices() async => list;

  @override
  Future<LatLng> locate() async => const LatLng(14.84, 120.81);
}
