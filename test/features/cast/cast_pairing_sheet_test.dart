import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musee/core/player/player_cubit.dart';
import 'package:musee/core/player/player_state.dart';
import 'package:musee/features/cast/domain/entities/cast_receiver_device.dart';
import 'package:musee/features/cast/domain/entities/cast_session.dart';
import 'package:musee/features/cast/presentation/bloc/cast_bloc.dart';
import 'package:musee/features/cast/presentation/bloc/cast_state.dart';
import 'package:musee/features/cast/presentation/widgets/cast_pairing_sheet.dart';
import 'package:musee/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:musee/features/settings/presentation/cubit/settings_state.dart';

class FakeCastBloc extends Fake implements CastBloc {
  final CastState _state;
  FakeCastBloc(this._state);

  @override
  CastState get state => _state;

  @override
  Stream<CastState> get stream => const Stream.empty();

  @override
  Future<void> close() async {}
}

class FakePlayerCubit extends Fake implements PlayerCubit {
  final PlayerViewState _state;
  FakePlayerCubit(this._state);

  @override
  PlayerViewState get state => _state;

  @override
  Stream<PlayerViewState> get stream => const Stream.empty();

  @override
  Future<void> close() async {}
}

class FakeSettingsCubit extends Fake implements SettingsCubit {
  final SettingsState _state;
  FakeSettingsCubit(this._state);

  @override
  SettingsState get state => _state;

  @override
  Stream<SettingsState> get stream => const Stream.empty();

  @override
  Future<void> close() async {}
}

void main() {
  testWidgets(
      'CastPairingSheet in CastActive state does not overflow on mobile screens (360x800)',
      (WidgetTester tester) async {
    final session = CastSession(
      id: 'session-uuid-123456',
      ownerId: 'user-1',
      sessionCode: 'MUSE42',
      createdAt: DateTime.now(),
      status: 'active',
    );

    final receiver = CastReceiverDevice(
      id: 'rec-1',
      sessionId: 'session-uuid-123456',
      deviceName: 'Living Room Android TV',
      joinedAt: DateTime.now(),
    );

    final activeState = CastActive(
      session: session,
      role: CastRole.controller,
      receivers: [receiver],
    );

    final castBloc = FakeCastBloc(activeState);
    final playerCubit = FakePlayerCubit(const PlayerViewState());
    final settingsCubit = FakeSettingsCubit(const SettingsState());

    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<CastBloc>.value(value: castBloc),
          BlocProvider<PlayerCubit>.value(value: playerCubit),
          BlocProvider<SettingsCubit>.value(value: settingsCubit),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: CastPairingSheet(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Toggle EQ panel to verify all subpanels render without overflow
    await tester.tap(find.text('Remote Equalizer & Audio'));
    await tester.pumpAndSettle();

    expect(find.text('Connected Cast Session'), findsOneWidget);
    expect(find.text('CONNECTED RECEIVERS (1)'), findsOneWidget);
    expect(find.text('Living Room Android TV'), findsOneWidget);
  });

  testWidgets(
      'CastPairingSheet does not overflow on small narrow screen (320px) with long device name and large text scale',
      (WidgetTester tester) async {
    final session = CastSession(
      id: 'session-uuid-long-identifier-123456',
      ownerId: 'user-1',
      sessionCode: 'LONGCODE88',
      createdAt: DateTime.now(),
      status: 'active',
    );

    final receiver = CastReceiverDevice(
      id: 'rec-1',
      sessionId: 'session-uuid-long-identifier-123456',
      deviceName: 'Living Room Sony Bravia 4K Ultra HD TV with Google Cast Support',
      joinedAt: DateTime.now(),
    );

    final activeState = CastActive(
      session: session,
      role: CastRole.controller,
      receivers: [receiver],
    );

    final castBloc = FakeCastBloc(activeState);
    final playerCubit = FakePlayerCubit(const PlayerViewState());
    final settingsCubit = FakeSettingsCubit(const SettingsState(equalizerEnabled: true));

    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<CastBloc>.value(value: castBloc),
          BlocProvider<PlayerCubit>.value(value: playerCubit),
          BlocProvider<SettingsCubit>.value(value: settingsCubit),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.3),
            ),
            child: const Scaffold(
              body: CastPairingSheet(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Scroll to and toggle EQ panel
    await tester.ensureVisible(find.text('Remote Equalizer & Audio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remote Equalizer & Audio'));
    await tester.pumpAndSettle();

    expect(find.text('Connected Cast Session'), findsOneWidget);
  });

  testWidgets('CastPairingSheet in idle state does not overflow on small screen',
      (WidgetTester tester) async {
    final castBloc = FakeCastBloc(const CastIdle());
    final playerCubit = FakePlayerCubit(const PlayerViewState());
    final settingsCubit = FakeSettingsCubit(const SettingsState());

    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<CastBloc>.value(value: castBloc),
          BlocProvider<PlayerCubit>.value(value: playerCubit),
          BlocProvider<SettingsCubit>.value(value: settingsCubit),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: CastPairingSheet(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Cast & Sync Playback'), findsOneWidget);
    expect(find.text('Start Cast Session'), findsOneWidget);
  });
}
