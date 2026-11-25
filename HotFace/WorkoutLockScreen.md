# Workout timers, sounds and Lock Screen

## Set up the iPhone

Start or continue a workout in Train. HotFace attempts to start its Live Activity and a Health workout session automatically.

- **Live Activities:** In iPhone Settings, find HotFace and enable Live Activities. Return to the workout and use **Show on Lock Screen** if the card is missing.
- **Health:** Allow HotFace to write Workouts when prompted. To change a previous decision, open Health, find HotFace under your profile's app permissions and enable Workouts. HotFace requests workout sharing only, not read access. It discards the Health workout on close or finish; the training record stays in HotFace.
- **Sounds:** Tap **Enable workout sounds on Lock Screen** when offered and allow notifications. In iPhone Settings, find HotFace's notification settings and enable notifications, Sounds and Lock Screen alerts. Review silent mode and any active or automatically scheduled Focus. A Work Focus that allowed only work apps silenced an earlier test.
- Connect your headphones and start music before training if desired. Test a short timed set before relying on audio alone.

AlarmKit permission belongs to the earlier feasibility probe, not the integrated workout sound path. The integrated workout uses local notifications with distinct sounds.

## During a workout

Complete a repetition set from the card, or start, pause and resume a timed set. Starting and resuming include three seconds of preparation. A completed timed set advances to the applicable rest or next waiting set. Rest expiry leaves the next set ready; it does not automatically start that set.

An authorized Health session stays active throughout the workout, including pauses and rests. Closing the workout screen ends Health and preserves the open workout. See [workout recovery](WorkoutRecovery.md).

## Verified results and limits

The following distinguishes the integrated workout results (task 5.6) from the earlier feasibility probe. All physical observations are on the iPhone 15 Pro, iOS 27.0.1; the iPhone 16 on iOS 26 remains untested.

| Condition | Observed result |
|---|---|
| Normal locking | Start and Pause worked. Without Health, the card stalled at zero even though reopening showed the correct next set. With Health, timed sets advanced to rest and the card offered the next set after rest without reopening. |
| Music and headphones | Integrated cues were audible through headphones with and without music. The earlier local-notification probe observed music briefly lowering and returning to its previous volume; AlarmKit instead played through the speaker and interrupted music. The exact volume behavior of every integrated cue was not independently measured. |
| Holds and supersets | A gym workout initially missed hold cues while the rest cue sounded. After separating notification scheduling from card updates, the user confirmed audible superset hold cues on the locked phone. |
| Cue visibility | After the set and rest cues sounded, only the latest rest notification remained beside the card in the corrected build. Cleanup requires an opportunity for HotFace to run. |
| Sounds disabled | The warning appeared. A timed set completed silently and was recorded once; reopening showed set 2 ready. |
| Live Activities disabled | The unavailable-controls warning appeared; no workout card appeared. Reopening retained the waiting set. |
| Health denied or unavailable | HotFace retains local workout functionality and warns that card updates may be delayed. A dedicated physical denial retest is not recorded. |
| Switching apps | Earlier probe tones were distinguished outside the app; exact cue timing and the phase on return were not confirmed in that trial. |
| Force quit or restart | Earlier probes recovered the next set on reopening. Individual cue delivery and ordering were not fully confirmed. No equivalent integrated-workout guarantee is established. |
| System termination or prolonged suspension | Physical verification remains pending. Do not assume the card or all notifications will update on schedule. |
| Concurrent actions and recovery | Earlier shared-storage trial recovered three distinct sets without duplication on the physical iPhone and simulator. Integrated repository tests separately passed stale controls, duplicate taps and rest deadlines on macOS. |

English and Spanish timed-session recovery and Health session continuity were also checked in the iOS 27.2 simulator; these tests do not establish physical audio routing or iOS 26 behavior.

## If the card or sound is missing

Check the permission warnings and the settings above. Reopen HotFace to reconcile the saved workout with elapsed time; confirm the current set before taking another action. Continue locally when system services are unavailable. A visible card is not proof that its contents are current, and notification sound delivery depends on system settings and audio routing.

The complete [device and audio matrices](../openspec/changes/gym-training-mvp/factibilidad-iphone.md) and [integration observations](../openspec/changes/gym-training-mvp/tasks.md#5-timers-audio-and-supersets) record the evidence and pending checks. Repeat on both target devices before claiming full physical coverage; record OS version, permissions, Focus, audio route, cue heard, card phase before opening and recovered phase after opening.
