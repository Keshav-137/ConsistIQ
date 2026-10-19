# ConsistIQ

ConsistIQ is a Flutter task, reminder, routine, and study-planning app.

## Optional Google sign-in and Gmail task import

Google sign-in is optional; the app remains usable without an account. The app
does not ask for or store a Google password. Gmail access is requested
separately, only after the user reads an in-app disclosure and taps the Gmail
import action. The app requests the Gmail metadata scope, lists up to 20 inbox
messages, and only copies a user's selected subject, sender, and preview into a
local task. It does not send, delete, or modify messages.

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
