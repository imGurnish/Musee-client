# Sync & Cast Feature — Implementation Plan

**Status:** 📋 Planned  
**Date:** September 2026  
**Architecture:** Clean Architecture (Data → Domain → Presentation)  
**Feature:** Cast playback to TV/car + remote control all audio settings from phone

---

## 📌 Overview

The **Sync & Cast** feature has three responsibilities:

1. **Playback sync** — phone and receiver play the same track at the same position
2. **TV/Car sign-in via QR** — the TV or car **displays** a QR code; the user scans it with their phone (already logged in) to authenticate the device — no typing credentials on the TV
3. **Full remote control** — phone controls not just play/pause/skip but also EQ bands, bass, surround, volume, crossfade, and more on the receiver

The phone is always the **Controller**. The TV, car display, or second phone is the **Receiver**.

---

## 🔐 Feature 1 — QR Code Sign-In (Device Auth Flow)

This is similar to how YouTube TV, Spotify Connect, and Netflix let you sign in on a TV by scanning a QR code on your phone. The TV **never needs you to type a password**.

### How it works

```
[TV / Car screen]                        [Phone (already logged in)]
     │                                              │
     │  1. Opens Musee receiver page                │
     │  2. Creates a device_auth token (UUID)       │
     │  3. Displays QR code on screen               │
     │     encoding: musee://auth/device?token=UUID │
     │  4. Waits... (Realtime subscription)         │
     │                                              │
     │         User points phone camera at TV       │
     │                                   ──────────►│ 5. Phone camera scans the QR
     │                                              │    (mobile_scanner)
     │                                              │
     │                                              │ 6. app_links receives deep link
     │                                              │    musee://auth/device?token=UUID
     │                                              │
     │                                              │ 7. Phone shows confirmation:
     │                                              │    "Sign in Living Room TV as You?"
     │                                              │
     │                                              │ 8. User taps Approve
     │                                              │    → calls approve_device_auth()
     │                                              │    → token: pending → approved
     │                                              │
     │  9. Realtime fires on TV ◄───────────────────│
     │     token.status == 'approved'               │
     │     → TV is now authenticated                │
     │     → auto-joins cast session                │
     └──────────────────────────────────────────────┘
```

### Supabase table: `device_auth_tokens`

```sql
CREATE TABLE device_auth_tokens (
  token        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID REFERENCES auth.users(id),  -- NULL until approved
  device_name  TEXT,                              -- "Living Room TV"
  status       TEXT DEFAULT 'pending',            -- pending | approved | expired
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  expires_at   TIMESTAMPTZ DEFAULT NOW() + INTERVAL '5 minutes',
  approved_at  TIMESTAMPTZ
);
```

### Supabase Edge Function: `approve_device_auth`

Called by the phone after the user scans the QR code:

```typescript
// supabase/functions/approve_device_auth/index.ts
Deno.serve(async (req) => {
  const { token } = await req.json();
  const user = await getUser(req); // from Authorization header

  await supabase
    .from('device_auth_tokens')
    .update({ user_id: user.id, status: 'approved', approved_at: new Date() })
    .eq('token', token)
    .eq('status', 'pending')
    .gt('expires_at', new Date());

  return new Response(JSON.stringify({ ok: true }));
});
```

### TV/receiver flow (Flutter Web or native)

```dart
// 1. TV generates a token and shows QR
final token = await castRepo.createDeviceAuthToken(deviceName: 'Living Room TV');
// QR content: "musee://auth/device?token=$token"

// 2. TV subscribes to Realtime for approval
supabase
  .channel('device_auth:$token')
  .onPostgresChanges(
    event: PostgresChangeEvent.update,
    schema: 'public',
    table: 'device_auth_tokens',
    filter: PostgresChangeFilter(type: FilterType.eq, column: 'token', value: token),
    callback: (payload) {
      if (payload.newRecord['status'] == 'approved') {
        // Token is approved — proceed to join the cast session
        _onDeviceApproved(payload.newRecord['user_id']);
      }
    },
  )
  .subscribe();
```

### Phone flow (Flutter app)

When `app_links` receives `musee://auth/device?token=<UUID>`:

```dart
// Intercept the deep link in your existing AppLinks handler
final uri = Uri.parse(link);
if (uri.path == '/auth/device') {
  final token = uri.queryParameters['token']!;
  // Show confirmation sheet: "Sign in Living Room TV as Gurni?"
  final confirmed = await showDeviceAuthConfirmSheet(context, token);
  if (confirmed) {
    await castRepo.approveDeviceAuth(token); // calls Edge Function
  }
}
```

---

## 🎵 Feature 2 — Playback Sync (Supabase Realtime)

One device is the **Controller** (phone), another is the **Receiver** (TV/car/second phone). They stay in sync via two Supabase Realtime paths:

| Path | Used for | Mechanism |
|---|---|---|
| **Broadcast** | Position ticks, play/pause, seek (high freq) | No DB write — ultra fast |
| **Postgres Changes** | Track change, queue update, EQ change (low freq) | DB write → push |

### Supabase table: `cast_sessions`

```sql
CREATE TABLE cast_sessions (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id      UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  session_code  TEXT UNIQUE,           -- short human code e.g. "JAZZ-42"
  device_name   TEXT,
  status        TEXT DEFAULT 'active', -- active | ended
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  ended_at      TIMESTAMPTZ
);
```

### Supabase table: `cast_session_state`

The single row of truth for what is playing AND what audio settings are active.

```sql
CREATE TABLE cast_session_state (
  session_id       UUID PRIMARY KEY REFERENCES cast_sessions(id) ON DELETE CASCADE,

  -- Playback
  current_track_id UUID REFERENCES tracks(id),
  queue            JSONB DEFAULT '[]',    -- ordered array of track IDs
  queue_index      INT DEFAULT 0,
  position_ms      BIGINT DEFAULT 0,
  is_playing       BOOLEAN DEFAULT false,
  volume           FLOAT DEFAULT 1.0,
  shuffle          BOOLEAN DEFAULT false,
  repeat_mode      TEXT DEFAULT 'none',   -- none | one | all

  -- Audio controls (mirrors SettingsState fields)
  eq_enabled       BOOLEAN DEFAULT true,
  eq_preset        TEXT DEFAULT 'normal',
  eq_bands         JSONB DEFAULT '[0,0,0,0,0]',  -- 5-band gains as floats
  bass_level       INT DEFAULT 0,                -- 0–100
  surround_level   INT DEFAULT 0,                -- 0–100
  crossfade_enabled BOOLEAN DEFAULT false,
  normalize_volume  BOOLEAN DEFAULT false,

  updated_at       TIMESTAMPTZ DEFAULT NOW()
);
```

### Supabase table: `cast_session_receivers`

```sql
CREATE TABLE cast_session_receivers (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id   UUID REFERENCES cast_sessions(id) ON DELETE CASCADE,
  user_id      UUID REFERENCES auth.users(id),
  device_name  TEXT,
  joined_at    TIMESTAMPTZ DEFAULT NOW(),
  left_at      TIMESTAMPTZ
);
```

### Enable Realtime

```sql
ALTER PUBLICATION supabase_realtime ADD TABLE cast_session_state;
ALTER PUBLICATION supabase_realtime ADD TABLE device_auth_tokens;
```

### Row Level Security

```sql
-- cast_session_state: owner writes, anyone in an active session reads
CREATE POLICY "owner_writes_state" ON cast_session_state
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM cast_sessions
      WHERE id = cast_session_state.session_id AND owner_id = auth.uid()
    )
  );

CREATE POLICY "receiver_reads_state" ON cast_session_state
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM cast_sessions
      WHERE id = cast_session_state.session_id AND status = 'active'
    )
  );

-- device_auth_tokens: only the approving user can update their own token
CREATE POLICY "user_approves_token" ON device_auth_tokens
  FOR UPDATE USING (auth.uid() IS NOT NULL)
  WITH CHECK (user_id = auth.uid());

-- device_auth_tokens: anyone can read their own pending token (for polling)
CREATE POLICY "token_owner_reads" ON device_auth_tokens
  FOR SELECT USING (true); -- scoped by token UUID which is a secret
```

---

## 🎛️ Feature 3 — Remote Control (EQ, Bass, Surround & More)

The phone already has a full [`EqualizerController`](../lib/core/equalizer/equalizer_controller.dart) with `applyEqBands()`, `applyBass()`, and `applySurround()`. The [`SettingsCubit`](../lib/features/settings/presentation/cubit/settings_cubit.dart) manages all the state.

The goal: when the user adjusts EQ on their phone during a cast session, the change is sent to the receiver and applied to its `EqualizerController` instance.

### Realtime broadcast events from phone (Controller)

These use **Broadcast** (no DB write) for instant response:

| Event | Payload | Trigger |
|---|---|---|
| `eq_bands_change` | `{ bands: [2.0, -1.0, 0.0, 1.5, 3.0] }` | User drags a band slider |
| `bass_change` | `{ level: 60 }` | User adjusts bass |
| `surround_change` | `{ level: 40 }` | User adjusts surround |
| `eq_enabled` | `{ enabled: false }` | User toggles EQ on/off |
| `crossfade_change` | `{ enabled: true }` | User toggles crossfade |
| `volume_change` | `{ volume: 0.75 }` | User adjusts volume |
| `position_tick` | `{ position_ms: 42000 }` | Every 2s during playback |
| `play` | `{}` | User taps play |
| `pause` | `{}` | User taps pause |
| `seek` | `{ position_ms: 10000 }` | User seeks |

For EQ changes that the user **commits** (lifts finger off slider, picks a preset), write to `cast_session_state` in the DB as well, so new receivers that join later get the correct state.

### Receiver applies incoming events

```dart
supabase
  .channel('session:${session.id}')
  .onBroadcast(event: 'eq_bands_change', callback: (payload) {
    final bands = (payload['bands'] as List).cast<double>();
    equalizerController.applyEqBands(bands);
  })
  .onBroadcast(event: 'bass_change', callback: (payload) {
    equalizerController.applyBass(payload['level'] as int);
  })
  .onBroadcast(event: 'surround_change', callback: (payload) {
    equalizerController.applySurround(payload['level'] as int);
  })
  .onBroadcast(event: 'position_tick', callback: (payload) {
    final targetMs = payload['position_ms'] as int;
    final currentMs = player.state.position.inMilliseconds;
    if ((targetMs - currentMs).abs() > 2000) {
      player.seek(Duration(milliseconds: targetMs));
    }
  })
  // Full state sync when track/queue/EQ settings are committed to DB
  .onPostgresChanges(
    event: PostgresChangeEvent.update,
    schema: 'public',
    table: 'cast_session_state',
    filter: PostgresChangeFilter(type: FilterType.eq, column: 'session_id', value: session.id),
    callback: (payload) => _applyFullState(payload.newRecord),
  )
  .subscribe();

void _applyFullState(Map<String, dynamic> record) {
  // Track changed
  final trackId = record['current_track_id'] as String;
  if (trackId != currentTrackId) _loadTrack(trackId);

  // EQ state
  if (record['eq_enabled'] == true) {
    final bands = (record['eq_bands'] as List).cast<double>();
    equalizerController.applyEqBands(bands);
    equalizerController.applyBass(record['bass_level'] as int);
    equalizerController.applySurround(record['surround_level'] as int);
  }
}
```

### Controller hooks into SettingsCubit

```dart
// In CastBloc — listen to SettingsCubit and forward changes to the channel
_settingsSubscription = context.read<SettingsCubit>().stream.listen((settings) {
  final channel = supabase.channel('session:${session.id}');

  channel.sendBroadcastMessage(
    event: 'eq_bands_change',
    payload: {'bands': settings.equalizerBands},
  );
  channel.sendBroadcastMessage(
    event: 'bass_change',
    payload: {'level': settings.bassLevel},
  );
  channel.sendBroadcastMessage(
    event: 'surround_change',
    payload: {'level': settings.surroundLevel},
  );
});
```

---

## 📂 Flutter Feature Structure

New feature at `lib/features/cast/`, matching the existing clean architecture:

```
lib/features/cast/
├── domain/
│   ├── entities/
│   │   ├── cast_session.dart
│   │   ├── cast_session_state.dart
│   │   └── device_auth_token.dart         -- NEW (QR sign-in)
│   ├── repository/
│   │   └── cast_repository.dart
│   └── usecases/
│       ├── create_cast_session.dart
│       ├── join_cast_session.dart
│       ├── end_cast_session.dart
│       ├── sync_playback_state.dart
│       ├── create_device_auth_token.dart   -- NEW
│       └── approve_device_auth.dart        -- NEW
├── data/
│   ├── datasources/
│   │   └── cast_remote_data_source.dart
│   ├── models/
│   │   ├── cast_session_model.dart
│   │   ├── cast_session_state_model.dart
│   │   └── device_auth_token_model.dart    -- NEW
│   └── repositories/
│       └── cast_repository_impl.dart
└── presentation/
    ├── bloc/
    │   ├── cast_bloc.dart
    │   ├── cast_event.dart
    │   └── cast_state.dart
    ├── pages/
    │   ├── cast_device_picker_page.dart
    │   ├── cast_receiver_page.dart
    │   └── device_auth_qr_page.dart        -- NEW (TV shows this)
    └── widgets/
        ├── cast_button.dart
        ├── cast_pairing_sheet.dart
        ├── device_auth_confirm_sheet.dart   -- NEW (phone shows this on QR scan)
        └── remote_eq_panel.dart             -- NEW (compact EQ in cast controls)
```

---

## 🔗 How It Hooks Into the Existing App

| Existing | Role in Cast |
|---|---|
| `PlayerCubit` | Source of position + track URL — `CastBloc` listens to it |
| `EnhancedQueueBloc` | Source of queue + current track — `CastBloc` listens to `QueueLoaded` |
| `SettingsCubit` | Source of EQ, bass, surround, crossfade — `CastBloc` listens and forwards |
| `EqualizerController` | Called on the **receiver** side when EQ events arrive |
| `app_links` | Triggered on the **phone** when its camera scans the QR shown on the TV screen (`musee://auth/device?token=...`) |
| `QueueItem.trackId` | The track reference broadcast in `cast_session_state` |
| `media_kit` Player | Receiver's player — `.seek()` for drift correction |
| Supabase JWT | Same auth token, no new auth setup needed |

---

## 📦 New Dependencies

```yaml
dependencies:
  # QR code display (pairing screen on controller + device auth on TV)
  qr_flutter: ^4.1.0

  # QR code scanning (on phone to scan TV's QR)
  mobile_scanner: ^7.0.0

  # Phase 2 only — Google Cast
  # flutter_cast_video: ^1.0.0
```

No new packages needed for the Supabase Realtime sync — `supabase_flutter` already supports Realtime channels and Broadcast.

---

## 🗺️ Complete Flow Diagram

```
DEVICE AUTH (TV/Car sign-in via QR)
────────────────────────────────────────────────────────
TV / Car (Receiver)                    Phone (Controller)
───────────────────                    ──────────────────
Opens receiver page
Creates device_auth_token row
  → status: pending
Displays QR code on screen ─────────► User points phone camera at TV screen
  musee://auth/device?token=UUID           │
Subscribes to Realtime ◄──────────────    │ mobile_scanner decodes the QR
  waiting for token approval              │ app_links fires deep link
                                          │ Phone shows confirmation sheet:
                                          │   "Sign in Living Room TV as You?"
                                          │ User taps Approve
                                          │ calls approve_device_auth(token)
                                          │   → token status: approved
                                          │   → token user_id: current user
Postgres Changes fires ◄──────────────────┘
  status == 'approved'
TV is now authenticated as user
  → auto-joins cast session


CAST SESSION (ongoing sync)
─────────────────────────────────────────────────────────────
Phone (Controller)                    TV / Car (Receiver)
─────────────────                     ──────────────────
[PlayerCubit]                         joins channel "session:<id>"
[EnhancedQueueBloc]  ──Broadcast──►  receives position_tick
[SettingsCubit]      ──Broadcast──►  receives eq_bands_change, bass_change, etc.
                                      → calls equalizerController.applyEqBands()
                                      → calls equalizerController.applyBass()
                     ──DB write──►   receives postgres_change on cast_session_state
                                      → loads new track via trackId
                                      → applies committed EQ state
```

---

## ✅ Implementation Checklist

### Backend (Supabase)

**Tables**
- [ ] `device_auth_tokens` table
- [ ] `cast_sessions` table
- [ ] `cast_session_state` table (including EQ + audio control columns)
- [ ] `cast_session_receivers` table

**Realtime**
- [ ] Enable Realtime on `cast_session_state`
- [ ] Enable Realtime on `device_auth_tokens`

**Security**
- [ ] RLS: owner writes `cast_session_state`, active sessions read
- [ ] RLS: `device_auth_tokens` — user approves own token; token UUID is the secret

**Edge Functions**
- [ ] `approve_device_auth` — validates token, links to user, sets status=approved
- [ ] *(Optional)* `generate_session_code` — short human-friendly cast code (e.g. JAZZ-42)

---

### Flutter — Device Auth (QR Sign-In)

- [ ] `DeviceAuthToken` domain entity + usecase
- [ ] `CastRemoteDataSource.createDeviceAuthToken()`
- [ ] `CastRemoteDataSource.approveDeviceAuth(token)` (calls Edge Function)
- [ ] `DeviceAuthQrPage` — TV shows this with QR code + spinner
- [ ] `DeviceAuthConfirmSheet` — phone shows after scanning QR
- [ ] Wire `app_links` deep link handler for `musee://auth/device?token=...`
- [ ] Realtime subscription on `device_auth_tokens` (TV side — waiting for approval)
- [ ] Add `mobile_scanner` + `qr_flutter` packages

---

### Flutter — Playback Sync

- [ ] `CastBloc` — listens to `PlayerCubit` and broadcasts `position_tick`
- [ ] `CastBloc` — listens to `EnhancedQueueBloc` and writes to `cast_session_state` on track/queue change
- [ ] Receiver: Broadcast listener for `play`, `pause`, `seek`, `position_tick`
- [ ] Receiver: Postgres Changes listener for full state on track/queue change
- [ ] Drift correction on receiver (seek if > 2s out of sync)

---

### Flutter — Remote EQ & Audio Controls

- [ ] `CastBloc` — listens to `SettingsCubit` and broadcasts EQ events
- [ ] Receiver: Broadcast listener for `eq_bands_change`, `bass_change`, `surround_change`, `eq_enabled`, `crossfade_change`, `volume_change`
- [ ] Receiver: calls `EqualizerController.applyEqBands()` / `applyBass()` / `applySurround()` on incoming events
- [ ] Write committed EQ state to `cast_session_state` DB (so new receivers get it)
- [ ] `RemoteEqPanel` widget — compact EQ controls shown in the controller's cast overlay

---

### Flutter — UI

- [ ] `cast_button.dart` — cast icon in player bar (in `play_track_page.dart`)
- [ ] `CastPairingSheet` — session code entry + QR display
- [ ] `CastDevicePickerPage` — list of available sessions / devices
- [ ] `CastReceiverPage` — fullscreen Now Playing on TV/car
- [ ] GoRouter routes for all cast pages
- [ ] Register `CastBloc` and usecases in `init_dependencies.dart`

---

## 💡 Tips & Notes

- **EQ broadcast during slider drag** — send `eq_bands_change` on every `onChanged` callback (Broadcast has no cost). Only write to DB on `onChangeEnd` (finger lifted).
- **Drift threshold** — 2 seconds is a safe default. Tighten to 500ms only if users demand it (causes more seeks).
- **Device auth token TTL** — expire tokens after 5 minutes. The TV should re-generate if the user takes too long.
- **Receiver state bootstrap** — when a receiver first joins, read the full `cast_session_state` row and apply all EQ/audio settings immediately, before the first Broadcast event arrives.
- **TV vs. Car pairing** — TVs are best paired via QR (TV **displays** it, user **scans** with phone camera). Cars/head units with small screens may not show a scannable QR — use the session code (e.g. JAZZ-42) instead, which the user types into the phone.
- **Web receiver** — the receiver page can be a hosted Flutter Web page on your Vercel deployment, meaning any TV browser can receive without installing the app.

---

**Next Step:** Create the Supabase tables and the `approve_device_auth` Edge Function, then scaffold the Flutter `cast` feature module. 🚀
