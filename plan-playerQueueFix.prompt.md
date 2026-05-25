## Plan: Stabilize player queue and loading UX

The player issues appear to come from one shared control surface: `lib/core/player/player_cubit.dart` is both building the queue and deciding when to refill it, while the album/playlist pages currently inject source artwork in a way that leaks playlist cover art into track playback. The plan is to make queue ownership source-aware, gate recommendation autofill so it only runs after a source queue finishes and only when the setting is enabled, add proper retry/recovery for transient playback failures, and replace misleading duration text with loading placeholders while track details are still resolving.

**Steps**
1. Map and preserve playback source context end to end, starting at the tap handlers in `lib/features/user_albums/presentation/pages/user_album_page.dart` and `lib/features/user_playlists/presentation/pages/user_playlist_page.dart`, and through `PlayerCubit.playTrackById()` in `lib/core/player/player_cubit.dart`.
   - Keep the clicked track as the first queue item, then queue the remaining album or playlist tracks in source order after it.
   - Ensure the queue item and current track retain enough context to distinguish album playback from playlist playback even after the queue is rebuilt or expanded from the backend.
   - Use album artwork for tracks when the source is a playlist, instead of the playlist cover, so the player reflects the actual track artwork.

2. Make the bottom player sheet source-aware instead of deriving its label from incidental fields.
   - Update `lib/core/common/widgets/player_bottom_sheet.dart` to render a tappable source label that says playing from album or playing from playlist based on preserved source context, not just whether `playlistId` or `albumId` happens to be present on the current track.
   - Keep the header name clickable and route to the correct album or playlist detail page.
   - Confirm the cover art in the bottom sheet comes from the track or album artwork path, not the playlist cover path.

3. Refactor queue refill so recommendations only append at the end of an album or playlist, and only when the setting is enabled.
   - Update `_refreshQueueIfNeeded()` in `lib/core/player/player_cubit.dart` to stop rewriting the active queue during normal playback just because the remaining queue is low.
   - Add an explicit source-boundary check so recommendation autofill runs only when the current album or playlist queue has actually been exhausted.
   - Respect `recommendationAutoFillEnabled` from `lib/features/settings/presentation/pages/settings_page.dart` as the only user-facing gate for autofill.
   - Keep the current source queue intact; recommendation tracks should be appended after the source tracks finish, not interleaved or inserted early.

4. Harden playback against transient network failures so playback does not abruptly pause.
   - Strengthen the recovery path in `PlayerCubit.playTrackById()` and the URL resolution flow it uses so a temporary fetch failure triggers a retry or backoff sequence instead of immediately finalizing playback as failed.
   - Review `_emitPlaybackError()`, `_fetchPlayableUrl()`, and the player state listener in `lib/core/player/player_cubit.dart` so temporary buffering, loading, or source resolution failures do not collapse into a false paused state.
   - Keep the current track selected and retry the same track before giving up, with a bounded number of attempts and a clear failure state only after retries are exhausted.

5. Replace misleading zero or near-zero duration text with loading placeholders while track details are still syncing.
   - In `lib/features/user_playlists/presentation/pages/user_playlist_page.dart`, replace duration text with a shimmer or skeleton placeholder wherever the item is still syncing or its track details have not finished loading.
   - Avoid formatting incomplete metadata as `0.01` or a similar misleading value; show loading UI until real duration data is available.
   - Keep the placeholder behavior consistent across all playlist item presentations that currently render duration from sync-in-progress data.

6. Align source metadata parsing and queue persistence so the fixed behavior survives queue reloads.
   - Review `lib/features/player/domain/entities/queue_item.dart` and any queue mapping helpers in `lib/core/player/player_cubit.dart` so album and playlist identifiers are preserved through `fromExpandedJson()` and any fallback queue reconstruction.
   - If the backend expansion response does not always include the right source identifiers, keep the local tap-time source identifiers as fallback values rather than letting them drop to null.
   - Verify queue reload, next-track advancement, and manual track selection all keep the original source association.

**Relevant files**
- `c:\Users\gurni\Dev\Flutter\Musee-client\lib\core\player\player_cubit.dart` — main queue construction, queue refill, completion handling, retry behavior, and playback state transitions.
- `c:\Users\gurni\Dev\Flutter\Musee-client\lib\core\player\player_state.dart` — source/queue state that may need to carry persistent playback context.
- `c:\Users\gurni\Dev\Flutter\Musee-client\lib\core\common\widgets\player_bottom_sheet.dart` — top player label, tap target, and artwork display.
- `c:\Users\gurni\Dev\Flutter\Musee-client\lib\features\player\domain\entities\queue_item.dart` — queue item source parsing and artwork fallback logic.
- `c:\Users\gurni\Dev\Flutter\Musee-client\lib\features\user\albums\presentation\pages\user_album_page.dart` — album tap behavior and queue seeding reference implementation.
- `c:\Users\gurni\Dev\Flutter\Musee-client\lib\features\user_playlists\presentation\pages\user_playlist_page.dart` — playlist tap behavior, queue seeding, and the sync/loading UI that currently shows misleading duration text.
- `c:\Users\gurni\Dev\Flutter\Musee-client\lib\features\settings\presentation\pages\settings_page.dart` — user-facing recommendation autofill toggle wiring.
- `c:\Users\gurni\Dev\Flutter\Musee-client\lib\features\player\data\repositories\player_repository_impl.dart` — queue API surface if additional metadata must be forwarded.

**Verification**
1. Add or update focused tests around queue construction and playback source labeling so an album tap and a playlist tap both start on the selected track and preserve the correct source metadata.
2. Add a unit test for queue refill that confirms recommendation autofill does not run before the album or playlist queue is exhausted and does not run when the setting is off.
3. Add a playback-failure test that simulates a temporary URL/network error and verifies the player retries instead of immediately ending in a paused error state.
4. Add a widget test or golden-style UI check for the syncing playlist row to confirm the duration area shows a loading placeholder instead of a numeric duration while the item is still loading.
5. Manually validate the end-to-end flow in the app: play from an album, play from a playlist, finish the source queue, confirm recommendations append only then, and confirm artwork and source label remain correct throughout.

**Decisions**
- Treat album and playlist playback as source-scoped queues, not discovery queues, until the source content is finished.
- Preserve the tap-time album or playlist identifiers as canonical source context, even if backend-expanded queue data is incomplete.
- Keep recommendation autofill opt-in through settings and inactive by default during normal source playback.
- Use loading placeholders for unresolved duration values rather than formatting partial metadata as a real time.

**Further Considerations**
1. If the backend can include a distinct source type and source title in the queue expansion response, that should be preferred over inferring source type from the current track fields.
2. If the player already has an internal reassertion timer or retry loop, the safest fix is to tighten that logic rather than layering a second recovery path on top of it.


//Few problems still existring 1. When auto-fill recommendation were off still the queue was showing recommended songs from backend. 2. When playing from album only the played album song got into queue rest came from recommendation (what should happen is other songs from albums should be in queue and recommations only if auto-fill recommendation is on and after album tracks are finished). 3.For playlist the first song of playlist does not fetch its cover proper (rest does) 4. No cover of tracks visible in playlists page (just number) which will improve user experience. 5. The duration of loading track in player still show 0.01 instead of loading shimmer