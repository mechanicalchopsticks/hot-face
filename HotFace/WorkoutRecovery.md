# Open and partially completed workouts

You can train offline. Each completed set is saved on the iPhone.

- **Open workout.** Closing the screen, terminating the app or returning another day keeps the workout open. In **Train**, choose **Continue workout** to resume from the saved set or rest. The cycle day stays available to the open session until you finish it.
- **Partially completed workout.** Choose **Finish workout** and confirm to close early. The summary shows completed sets, optional repetition counts, exercise ratings and the number of unperformed sets. That cycle day is complete.
- **Completed cycle.** Finish each day and check its summary. When all days are resolved, Train offers the next cycle. A new cycle uses the usual routine and preserves each prior workout's saved results.

The TrainingKit integration test `OfflineCycleTests` reopens the local store and reads both days' summaries after starting the next cycle.
