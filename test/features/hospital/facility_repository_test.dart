// test/features/hospitals/data/facility_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:navi_sante/features/hospitals/data/facility_local.dart';
import 'package:navi_sante/features/hospitals/data/facility_remote.dart';
import 'package:navi_sante/features/hospitals/data/facility_repository.dart';
import 'package:navi_sante/features/hospitals/controller/facility_model.dart';

class MockFacilityLocal extends Mock implements FacilityLocal {}
class MockFacilityRemote extends Mock implements FacilityRemote {}

FacilityModel _fakeFacility() {
  return const FacilityModel(
    facilityId: 'fac-001',
    name: 'Hopital Central Yaounde',
    type: FacilityType.hospital,
    rating: 4.5,
    latitude: 3.8667,
    longitude: 11.5167,
    servicesList: ['Cardiology', 'Specialized Surgery'],
    servicesCount: 2,
  );
}

void main() {
  late MockFacilityLocal mockLocal;
  late MockFacilityRemote mockRemote;
  late FacilityRepository repository;

  setUp(() {
    mockLocal = MockFacilityLocal();
    mockRemote = MockFacilityRemote();
    repository = FacilityRepository(local: mockLocal, remote: mockRemote);
    when(() => mockLocal.getAllFacilities()).thenReturn([]); // no local cache
  });

  test('returned one facility matching query', () async {
    when(() => mockRemote.searchFacilities(
          query: any(named: 'query'),
          typeFilter: any(named: 'typeFilter'),
          cityFilter: any(named: 'cityFilter'),
          serviceFilter: any(named: 'serviceFilter'),
          priceRangeFilter: any(named: 'priceRangeFilter'),
          minRating: any(named: 'minRating'),
        )).thenAnswer((_) async => [_fakeFacility()]);

    final results = await repository.searchFacilities(query: 'Hopital Central');

    expect(results, hasLength(1));
    expect(results.first.name, 'Hopital Central Yaounde');
    verify(() => mockRemote.searchFacilities(
          query: 'Hopital Central',
          typeFilter: null,
          cityFilter: null,
          serviceFilter: null,
          priceRangeFilter: null,
          minRating: 0.0,
        )).called(1);
  });
}