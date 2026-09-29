import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:navi_sante/features/hospitals/widgets/facility_grid_cards.dart';
import 'package:navi_sante/features/hospitals/data/facility_model.dart';
import 'package:navi_sante/features/hospitals/viewmodels/facility_bloc.dart';

class FakeFacilityBloc extends Bloc<FacilityEvent, FacilityState> implements FacilityBloc {
  FakeFacilityBloc() : super(FacilityState());
}

void main() {
  testWidgets('Verify no overflow across multiple device widths and font scales', (tester) async {
    final facility = FacilityModel(
      facilityId: '1',
      name: 'Hôpital Central de Yaoundé avec Nom Très Long',
      type: FacilityType.hospital,
      rating: 4.8,
      latitude: 3.8,
      longitude: 11.5,
      servicesList: const ['Emergency', 'Cardiology', 'Pediatrics', 'Surgery', 'Radiology'],
      servicesCount: 8,
    );

    final bloc = FakeFacilityBloc();
    int errorCount = 0;

    FlutterError.onError = (FlutterErrorDetails details) {
      print('OVERFLOW: ${details.summary}');
      errorCount++;
    };

    for (final width in [320.0, 340.0, 360.0, 375.0, 390.0, 412.0, 428.0]) {
      for (final textScale in [1.0, 1.15, 1.25]) {
        tester.view.physicalSize = Size(width * 2.0, 800.0 * 2.0);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final cardWidth = (width - 40 - 12) / 2;
        final cardHeight = cardWidth / 0.62;

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: 'Inter'),
            home: MediaQuery(
              data: MediaQueryData(
                textScaler: TextScaler.linear(textScale),
                size: Size(width, 800.0),
              ),
              child: Scaffold(
                body: BlocProvider<FacilityBloc>.value(
                  value: bloc,
                  child: SizedBox(
                    width: cardWidth,
                    height: cardHeight,
                    child: FacilityGridCard(
                      facility: facility,
                      onDetailsTap: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    expect(errorCount, equals(0));
  });
}
