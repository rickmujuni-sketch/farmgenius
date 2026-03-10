# farmgenius

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

---

## FarmGenius Setup & Authentication (Milestone 1)

This section describes how to run the app locally, configure Supabase, and
exercise the email‑based sign-up / login functionality implemented for
Milestone 1. It’s written for complete beginners.

### 1. Prerequisites

- Install Flutter (see the links above). On macOS you may also need Xcode
  and/or Android Studio if you plan to build for mobile.
- A free [Supabase account](https://supabase.com) and a project. You will
  need the **URL** and a **publishable (anon) key** from the project’s
  settings.

### 2. Configuring secrets securely

The app reads the Supabase configuration from Dart environment variables so
that you don’t check them into source control. If you don’t provide them, the
hard‑coded defaults from `lib/constants.dart` will be used.

Run commands like this to specify your values:

```bash
flutter pub get
flutter run -d chrome \
  --dart-define=SUPABASE_URL="https://your-project.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="sb_publishable_…"
```

You can also add these definitions to `launch.json` or your IDE’s run
configuration for convenience.

### 3. Signing up and logging in

1. Launch the app as shown above. A Chrome window will open with the
   welcome screen.
2. Click “Email Login” to go to the login form.
3. If you don’t have an account yet, navigate to `/signup` or press the
   “Sign up” button (if added later). Enter an email, your password twice,
   and pick a role (Owner, Manager, or Staff). Tap **Create account**.
4. After signing up you’ll be returned to the login screen. Enter the same
   email and password and tap **Sign In**.
5. When authentication succeeds the app will redirect to one of the role‑
   specific home pages: Owner, Manager, or Staff. You can inspect their
   contents in `lib/screens/*_home.dart`.
6. To log out, use the “Logout” button on any home page. Authentication
   state is stored in memory and secure storage; the session is restored
   automatically when you restart the app.

### 4. Next steps

- The current implementation stores the chosen role only locally; you
  should create a `users` table in Supabase or update the user’s metadata
  via a secure backend so the role persists in the database.
- Phone/SMS login is stubbed out; you can enable it once the Supabase
  project has SMS configured and the client API matches your SDK version.
- To build for iOS/macOS/Android you’ll need to install CocoaPods (macOS) or
  Android SDK. See `flutter doctor` output and follow the instructions.

That’s it for Milestone 1! Feel free to explore the code in `lib/services`
and `lib/screens` to understand how authentication is wired together.

---

## Share a trusted feedback link (Web)

Use this to publish a single URL for third-party reviewers.

### Prerequisites

- Firebase project created in your Google account
- Firebase CLI installed and authenticated:

```bash
npm install -g firebase-tools
firebase login
```

### One-time setup

1. Open `.firebaserc` and replace `YOUR_FIREBASE_PROJECT_ID` with your real project id.
2. Ensure web hosting files are present (`firebase.json` already configured for Flutter web SPA routing).

### Deploy and get a shareable link

```bash
./scripts/deploy_feedback_web.sh <your-firebase-project-id>
```

After deploy completes, Firebase prints a Hosting URL (for example `https://<project-id>.web.app`).
Share that URL with your trusted reviewers.
