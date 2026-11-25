# Open and partially completed workouts

You can train offline. Each completed set is saved on the iPhone.

With workout permission in Health, starting or continuing a workout starts a HealthKit session for Lock Screen updates. It stays active through pauses, rests, exercise changes and locking the phone. **Close** ends the HealthKit session and leaves your progress available in HotFace. Finishing a workout also ends HealthKit. HotFace discards the HealthKit workout and keeps its own training record.

- **Open workout.** Closing the screen, terminating the app or returning another day keeps the workout open. In **Train**, choose **Continue workout** to resume from the saved set or rest. The cycle day stays available to the open session until you finish it.
- **Partially completed workout.** Choose **Finish workout** and confirm to close early. The summary shows completed sets, optional repetition counts, exercise ratings and the number of unperformed sets. That cycle day is complete.
- **Completed cycle.** Finish each day and check its summary. When all days are resolved, Train offers the next cycle. A new cycle uses the usual routine and preserves each prior workout's saved results.

The TrainingKit integration test `OfflineCycleTests` reopens the local store and reads both days' summaries after starting the next cycle.
