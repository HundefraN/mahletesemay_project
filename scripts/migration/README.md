# 🚀 Mahlete Semay - Supabase ETL & Media Migration Suite

This utility performs the automated extraction, transformation, media transfer, and loading (ETL) of your legacy data (Firestore & Cloudinary / Firebase Storage) into Supabase PostgreSQL and Storage.

---

## 📌 Features

- **Automated Data ETL**: Migrates `artists`, `albums`, `songs`, `vocal_plans`, `vocal_plan_days`, `general_exercises`, `moderators`, `suggestions`, and `activity_logs`.
- **Automated Media Transfer**: Downloads images and audio files from Cloudinary, Firebase Storage, or HTTP links and uploads them directly to Supabase Storage public buckets (`covers`, `audio`, `avatars`).
- **Automatic URL Remapping**: Replaces legacy Cloudinary/Firebase links in database records with your new public Supabase CDN URLs (`https://<project-ref>.supabase.co/storage/v1/object/public/...`).
- **Idempotent & Safe**: Uses `upsert` with `onConflict: 'id'` and detects already-migrated Supabase URLs so it can be re-run safely anytime.
- **Relational Integrity**: Cleans and validates foreign keys (`artist_id`, `album_id`, `plan_id`) to prevent database constraint violations.
- **Dual Source Support**: Direct live Firestore extraction via Firebase Admin SDK OR offline JSON files (`scripts/migration/data_dump/`).

---

## 🛠️ Prerequisites & Setup

### Step 1: Install Dependencies
Open your terminal and navigate to the migration directory:
```bash
cd scripts/migration
npm install
```

### Step 2: Configure Environment Variables
Copy `.env.example` to `.env` (or let it read from your root `.env`):
```bash
cp .env.example .env
```

Edit `scripts/migration/.env`:
```env
# Required: Supabase URL and Service Role Key (from Supabase Dashboard -> Settings -> API -> service_role secret)
SUPABASE_URL=https://onsvnudakxkrqazrufar.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# Optional if you are extracting live from Firebase:
FIREBASE_SERVICE_ACCOUNT_KEY=./serviceAccountKey.json
```

> [!TIP]
> **Where to get `serviceAccountKey.json`:**
> 1. Go to [Firebase Console](https://console.firebase.google.com/).
> 2. Project Settings ⚙️ -> **Service accounts**.
> 3. Click **Generate new private key** and save the JSON file as `scripts/migration/serviceAccountKey.json`.

---

## 🏃 Running the Migration

### 1. Test Run (Dry-Run Mode)
Simulate the entire process to inspect record counts and media mapping without making changes to Supabase:
```bash
npm run dry-run
# OR
node migrate.js --dry-run
```

### 2. Execute Live Migration
Run the full data ETL and media transfer into Supabase:
```bash
npm run migrate
# OR
node migrate.js
```

### 3. Verify Database Row Counts
Check current row counts in your Supabase tables:
```bash
npm run verify
# OR
node migrate.js --verify-only
```

---

## ⚙️ Advanced CLI Options

| Command | Purpose |
| :--- | :--- |
| `node migrate.js` | Full live migration (Data + Media) from Firebase |
| `node migrate.js --dry-run` | Simulated dry-run without writing to database or storage |
| `node migrate.js --skip-media` | Migrate only tabular database records (fast) |
| `node migrate.js --media-only` | Transfer media and update existing database URLs |
| `node migrate.js --source=json` | Offline migration using local files in `scripts/migration/data_dump/` |
| `node migrate.js --verify-only` | Test connection and display row counts |

---

## 📁 Offline JSON Mode (Alternative to Firebase Admin Key)

If you have JSON export files instead of a Firebase Admin key, place them in `scripts/migration/data_dump/`:
```
scripts/migration/data_dump/
├── artists.json
├── albums.json
├── songs.json
├── vocal_plan_days.json
└── general_exercises.json
```
Then run:
```bash
node migrate.js --source=json
```

---

## 🔍 Verification After Migration

1. **Supabase Database**: Go to **Supabase Dashboard -> Table Editor** to confirm rows in `artists`, `albums`, `songs`, `vocal_plan_days`, and `general_exercises`.
2. **Supabase Storage**: Go to **Storage Explorer** and verify that files exist in `covers` and `audio` buckets.
3. **Flutter App**: Launch your Flutter application (`flutter run`). All artists, covers, songs, and vocal exercise audio should now stream directly from Supabase!
