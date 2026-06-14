# Anjanvel ERP — Deployment Guide

## Prerequisites
- Flutter 3.x SDK
- Supabase account
- Firebase project (for push notifications)
- Android Studio / Xcode (for mobile builds)

---

## Step 1: Supabase Setup

### 1.1 Create Supabase Project
1. Go to https://supabase.com and create a new project
2. Name: `anjanvel-erp`
3. Choose a strong database password
4. Select region: `ap-south-1` (Mumbai)

### 1.2 Run Migrations
Run in order in the Supabase SQL Editor:

```
supabase/migrations/20240001_extensions_and_enums.sql
supabase/migrations/20240002_users_and_roles.sql
supabase/migrations/20240003_crm_packages.sql
supabase/migrations/20240004_guests_rooms_bookings.sql
supabase/migrations/20240005_operations.sql
supabase/migrations/20240006_activities_shop_payments.sql
supabase/migrations/20240007_views_functions.sql
```

Or use Supabase CLI:
```bash
supabase db push
```

### 1.3 Storage Buckets
Create these buckets in Supabase Storage (Settings → Storage):
- `guest-documents` — Private
- `room-images` — Public
- `activity-images` — Public
- `artisan-portfolio` — Public
- `invoices` — Private
- `shop-products` — Public
- `housekeeping-photos` — Private

### 1.4 Get API Keys
Go to Project Settings → API:
- Copy `Project URL` → `SUPABASE_URL`
- Copy `anon public` key → `SUPABASE_ANON_KEY`

---

## Step 2: Firebase Setup

### 2.1 Create Firebase Project
1. Go to https://console.firebase.google.com
2. Create project: `anjanvel-erp`
3. Enable Cloud Messaging (FCM)

### 2.2 Android Setup
1. Add Android app with package name: `com.anjanvel.erp`
2. Download `google-services.json` → place in `flutter_app/android/app/`

### 2.3 iOS Setup
1. Add iOS app with bundle ID: `com.anjanvel.erp`
2. Download `GoogleService-Info.plist` → place in `flutter_app/ios/Runner/`

---

## Step 3: Flutter Environment Setup

### 3.1 Create .env file
```bash
cp flutter_app/.env.example flutter_app/.env
```

Edit `.env`:
```env
SUPABASE_URL=https://xxxxxxxxxxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### 3.2 Install Dependencies
```bash
cd flutter_app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### 3.3 Run Development
```bash
flutter run
```

---

## Step 4: Build & Deploy

### Android APK (Debug)
```bash
cd flutter_app
flutter build apk --debug
# Output: build/app/outputs/flutter-apk/app-debug.apk
```

### Android APK (Release)
```bash
flutter build apk --release --obfuscate --split-debug-info=symbols/
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Android App Bundle (Play Store)
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### iOS Build
```bash
flutter build ios --release
# Then archive in Xcode for App Store submission
```

### Web Build (Admin Portal)
```bash
flutter build web --release --base-href=/
# Output: build/web/
# Deploy to: Firebase Hosting, Netlify, or Vercel
```

---

## Step 5: Supabase Edge Functions

Deploy edge functions for WhatsApp, notifications, and invoice generation:

```bash
supabase functions deploy send-whatsapp
supabase functions deploy send-notification
supabase functions deploy generate-invoice
supabase functions deploy generate-qr-pass
```

Set secrets:
```bash
supabase secrets set WHATSAPP_TOKEN=your_token
supabase secrets set FCM_SERVER_KEY=your_fcm_key
```

---

## Step 6: First Admin User

After migrations, create the first Owner account:

1. Go to Supabase Dashboard → Authentication → Users
2. Create user with email and password
3. In SQL Editor, run:
```sql
INSERT INTO public.users (id, full_name, email, role)
VALUES (
  '<auth_user_id>',
  'Resort Owner',
  'owner@anjanvel.com',
  'OWNER'
);
```

---

## Architecture Overview

```
flutter_app/lib/
├── main.dart
├── core/
│   ├── constants/          # App constants, routes, roles
│   ├── models/             # Shared models (AppUser, etc.)
│   ├── providers/          # Global providers (auth, supabase)
│   ├── router/             # GoRouter navigation
│   ├── services/           # PDF, Excel, Notifications, Edge Functions
│   └── theme/              # AppTheme, colors, typography
├── features/
│   ├── auth/               # Splash, Login, OTP, Forgot Password
│   ├── dashboard/          # Owner, Manager, Kitchen, Housekeeping dashboards
│   ├── bookings/           # List, Detail, Create, Calendar
│   ├── guests/             # List, Profile
│   ├── rooms/              # Dashboard, Detail, Allocation
│   ├── checkin/            # Check-in, Check-out
│   ├── food/               # Orders, Meal Planning
│   ├── activities/         # List, Detail, Registration
│   ├── heritage/           # Heritage Walk, Guide Dashboard
│   ├── inventory/          # List, Stock Movement
│   ├── shop/               # Products, Cart, Checkout
│   ├── leads/              # CRM Lead Management
│   ├── maintenance/        # Tickets
│   ├── reports/            # Analytics Dashboard
│   ├── notifications/      # Push Notifications
│   ├── profile/            # User Profile
│   └── settings/           # App Settings
└── shared/
    └── widgets/            # Reusable UI components
```

---

## Module Status

| Module | Schema | Service | Screens |
|--------|--------|---------|---------|
| Auth | ✅ | ✅ | ✅ |
| Users/Roles | ✅ | ✅ | ✅ |
| CRM/Leads | ✅ | ✅ | ✅ Stub |
| Packages | ✅ | ✅ | ✅ |
| Bookings | ✅ | ✅ | ✅ |
| Guests | ✅ | ✅ | ✅ Stub |
| Rooms | ✅ | ✅ | ✅ |
| Check-in/out | ✅ | ✅ | ✅ Stub |
| Housekeeping | ✅ | — | ✅ Stub |
| Maintenance | ✅ | — | ✅ Stub |
| Food | ✅ | — | ✅ |
| Inventory | ✅ | — | ✅ Stub |
| Activities | ✅ | — | ✅ Stub |
| Heritage Walk | ✅ | — | ✅ Stub |
| Artisans | ✅ | — | — |
| Shop | ✅ | — | ✅ Stub |
| Payments | ✅ | — | — |
| Reports | ✅ | — | ✅ |
| WhatsApp CRM | ✅ | ✅ | — |
| Notifications | ✅ | ✅ | ✅ Stub |

---

## Environment Variables

```env
# .env
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_ANON_KEY=eyJ...
```

## Android Signing (Release)
Create `flutter_app/android/key.properties`:
```
storePassword=<your_store_password>
keyPassword=<your_key_password>
keyAlias=anjanvel
storeFile=<path_to_keystore.jks>
```

Generate keystore:
```bash
keytool -genkey -v -keystore anjanvel.jks -alias anjanvel -keyalg RSA -keysize 2048 -validity 10000
```
