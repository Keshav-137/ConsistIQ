# ConsistIQ

ConsistIQ is a Flutter productivity app for recurring routines, medicine
reminders, alarms, deadlines, study plans, and daily progress. Its tagline is
**“Never break the chain.”**

## Features

- **Today dashboard:** See today's scheduled items, completion progress, streaks,
  and streak freezes. Use the **+** button to create a routine, medicine
  reminder, deadline, task, or meeting.
- **Tasks and routines:** Schedule one-time or recurring items, choose times
  and weekdays, add reminder lead times and follow-ups, snooze, and mark items
  done or skipped. Routines can build streaks.
- **Medicine reminders:** Create daily medicine schedules with dose notes,
  multiple times, reminders, and snoozing.
- **Alarms and notifications:** Set reminders, follow-ups, vibration, ringtone,
  and optional full-screen alarms. Notification actions can complete or snooze
  supported items without opening the app.
- **Streaks and freezes:** Review routine history and active streaks. A
  streak-freeze can automatically protect an eligible missed day; the app
  awards freezes at streak milestones, up to its configured limit.
- **Study mode (Android):** Set a focus duration or run until manually stopped.
  Select study apps and emergency apps to allow. Calls, Messages, YouTube,
  WhatsApp, and ConsistIQ are always allowed. Optional Do Not Disturb support
  can silence other interruptions while studying.
- **Syllabus study plans:** Paste a syllabus, choose a daily study duration and
  optional number of days, review the generated daily topics, then create a
  scheduled plan with a streak and reminder.
- **Calendar import:** Choose upcoming events from calendars on the phone and
  add selected events as meeting reminders. Synced Google calendars are
  available through the phone's calendar provider.
- **Gmail import (optional):** Sign in with Google and choose inbox messages to
  turn into local tasks. See [Google sign-in and Gmail setup](#optional-google-sign-in-and-gmail-task-import).
- **Android home-screen widgets:** Add Quick add task, Today's tasks, or Task
  progress from the launcher's widget picker.
- **Local profile and settings:** Set a dashboard greeting, notification and
  alarm defaults, app-lock timeout, study preferences, and optional Gemini API
  settings.

## Using the app

### Create and manage tasks

1. Open **Today** and tap the **+** button.
2. Choose a type: Routine, Medicine, Deadline, Task, or Meeting.
3. Enter a title and adjust the schedule, reminders, and alarm options.
4. Save the item. It appears on the dashboard when scheduled for today.
5. Tap an item to view actions, or use its completion control to mark it done.
   Overdue items can be completed, snoozed, or skipped.

Use **Routines** to manage recurring items, **Streaks** to review progress, and
**Today** to see the day's schedule and completion progress.

### Choose a theme

Open **Settings → Appearance** and choose:

- **System** to follow the device appearance setting.
- **Light** for the light glass theme.
- **Dark** for the dark glass theme.

The theme choice is saved on the device. ConsistIQ uses a translucent glass
interface with a softly animated background. App animations are paused when the
app is in the background.

### Notifications, alarms, and battery settings

In **Settings → Notifications and alarms**, enable reminders and use the
permission button to grant the Android notification, exact-alarm, and
full-screen alarm permissions that your device offers. Use the test buttons to
check reminder and alarm delivery.

In **Settings → Alarm settings**, configure vibration, ringtone, default
reminder lead time, snooze duration, and whether new tasks use full-screen
alarms. Individual items can have their own alarm settings.

For timely delivery, allow notifications and exact alarms in Android settings.
Some phone manufacturers also delay background alarms unless ConsistIQ is
allowed to run without battery restrictions or start automatically. The app
requests the relevant Android permissions where supported; the exact menus and
behavior vary by device. Battery exemptions can increase battery use, so enable
them only if your reminders are being delayed.

ConsistIQ pauses Flutter animations and stops its foreground-only refresh
polling while backgrounded. Scheduled reminders are handled by Android
notifications; no app can guarantee delivery if the operating system or device
manufacturer restricts background execution.

### Use Study mode (Android)

1. Open **Study** and choose a duration, a custom duration, or **Until I stop**.
2. Optionally enable **Auto silent**.
3. Add apps that you need for studying and add any emergency apps you need to
   keep reachable.
4. Grant **Usage access** and **Display over other apps** when Android asks.
   Do Not Disturb access is optional and is needed for auto-silent behavior.
5. Tap **Start study mode**. Use **Stop study mode** when you are finished.

Study mode uses Android app-usage and overlay capabilities to cover apps that
are not allowed. These permissions are sensitive: Android shows their settings
pages and the user must grant them explicitly.

### Create a study plan

Open **Routines → Study planner**, paste the syllabus, and set the minutes per
day. The number of days is optional. Generate and review the suggested topics,
edit or remove days as needed, then create the plan. The plan creates scheduled
study tasks and a daily reminder.

The syllabus splitter works offline by grouping syllabus lines and separators.
If a Gemini API key is configured, the syllabus text is sent to Google's
Gemini API to generate a plan; if the request fails, the app falls back to the
offline splitter.

### App lock

Go to **Settings → Security → App lock** and enable it. The device must have a
screen lock configured. ConsistIQ uses the device's available fingerprint,
face, or device-credential authentication; biometrics are not stored by the
app.

Choose how long ConsistIQ can be away before it locks again. The available
timeouts are **Instantly**, **15 sec**, **20 sec**, **30 sec**, **1 min**, and
**5 min**.

### Calendar and Gmail imports

- **Calendar:** Open **Settings → Integrations → Import from phone calendar**.
  Grant calendar access, choose a calendar and select the upcoming events to
  import. Selected events become local meeting reminders.
- **Gmail:** Open **Settings → Integrations → Google account & create tasks
  from Gmail**, sign in, grant the requested Gmail access, and select messages
  to create tasks. The app requests the Gmail metadata scope and reads up to 20
  recent inbox messages.

## Technology

- **Flutter and Dart** for the cross-platform UI and app logic.
- **Provider** for application state; settings and task data are stored locally
  with **SharedPreferences**.
- **flutter_local_notifications**, **timezone**, and **flutter_timezone** for
  scheduled local notifications and alarms.
- **local_auth** for device-supported authentication.
- **device_calendar** for reading on-device calendars.
- **google_sign_in** and **http** for the optional Google/Gmail integration and
  Gemini API requests.
- **home_widget** for Android home-screen widgets.
- Android native Kotlin code and Flutter platform channels for app blocking,
  study-mode permissions, and alarm ringtone selection.

## Development setup

### Requirements

- Flutter SDK and Dart SDK versions allowed by `pubspec.yaml` (Dart `>=3.3.0
  <4.0.0`).
- Android Studio / Android SDK for Android builds. The study-mode blocking and
  home-screen widgets are Android-specific.

### Run and validate

From the repository root:

```powershell
flutter pub get
flutter run
```

To run the tests and static analysis:

```powershell
flutter test
flutter analyze
```

To build an Android debug APK:

```powershell
flutter build apk --debug
```

The project currently includes Android and iOS directories. Android is the
primary target for notifications, app lock, study mode, and widgets; exact
feature availability depends on platform support and granted permissions.

## Data and privacy notes

- Tasks, settings, profile name, and study plans are stored locally using
  SharedPreferences. The README does not claim that local preferences are
  encrypted.
- Calendar data is read from the phone only after calendar permission is
  granted; only events the user selects are copied into local tasks.
- Gmail is optional. Google sign-in does not ask for a Google password. Gmail
  access is requested separately after the user starts the import flow; the
  app reads message metadata for selection and does not send, delete, or modify
  messages.
- A Gemini API key is optional and is stored in the app's local settings.
  When Gemini generation is used, the entered syllabus text is sent to Google's
  Gemini API. Without a key, syllabus splitting uses the offline fallback.

## Optional Google sign-in and Gmail task import

Google sign-in is optional; the app remains usable without an account. The app
does not ask for or store a Google password. Gmail access is requested
separately, only after the user reads an in-app disclosure and taps the Gmail
import action. The app requests the Gmail metadata scope, lists up to 20 inbox
messages, and only copies a user's selected subject, sender, and preview into
a local task. It does not send, delete, or modify messages.

To configure Google sign-in for a build:

1. Create a Google Cloud project, enable the Gmail API, and configure the OAuth
   consent screen. Add test users while the consent screen is in testing.
2. Register an Android OAuth client for the app's application ID and signing
   certificate fingerprints. The current application ID is the Flutter
   template value `com.example.app`; choose a unique application ID before
   public release and register that value instead.
3. Create a Web application OAuth client ID and build with:

   ```powershell
   flutter build apk --release --dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_WEB_CLIENT_ID
   ```

   The client ID is a public identifier, not a password. Do not add private
   keys, service-account files, or user credentials to the APK or repository.
4. Gmail metadata access is a restricted Google OAuth scope. Public
   distribution may require Google's verification and a privacy policy. Until
   setup is complete, the Google sign-in button is disabled and local app use
   continues to work.

The Android release build currently uses the debug signing configuration.
Configure a private release keystore outside source control before distributing
release APK updates.

## Android home-screen widgets

Add any of these widgets from the Android launcher's widget picker:

- **Quick add task** opens the task editor.
- **Today's tasks** shows remaining tasks and their routine/task type.
- **Task progress** shows completed versus scheduled tasks for today.

Widgets refresh when tasks are changed in the app and after a task is completed
from a reminder notification.
