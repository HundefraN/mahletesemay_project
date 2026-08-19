#!/usr/bin/env node

/**
 * ==============================================================================
 * Mahlete Semay - Supabase ETL and Media Migration CLI
 * ==============================================================================
 * Transfers legacy database records and media files (Cloudinary / Firebase / Web)
 * to Supabase PostgreSQL tables and Supabase Storage buckets.
 */

import path from 'path';
import fs from 'fs';
import { config, validateConfig } from './lib/config.js';
import { FirebaseExporter } from './lib/firebase_exporter.js';
import { JsonExporter } from './lib/json_exporter.js';
import { SupabaseImporter } from './lib/supabase_importer.js';
import { MediaTransferEngine } from './lib/media_transfer.js';
import {
  transformArtist,
  transformAlbum,
  transformSong,
  transformVocalPlanDay,
  transformGeneralExercise,
  transformModerator,
  transformSuggestion,
  transformActivityLog,
  transformInvitation,
  transformInviteCode,
} from './lib/transformers.js';

// Parse CLI Flags
const args = process.argv.slice(2);
const options = {
  dryRun: args.includes('--dry-run'),
  skipMedia: args.includes('--skip-media') || args.includes('--data-only'),
  mediaOnly: args.includes('--media-only'),
  verifyOnly: args.includes('--verify-only') || args.includes('--verify'),
  source: args.find(a => a.startsWith('--source='))?.split('=')[1] || 'firebase',
  jsonDir: args.find(a => a.startsWith('--json-dir='))?.split('=')[1] || config.paths.dataDir,
  help: args.includes('--help') || args.includes('-h'),
};

function printHelp() {
  console.log(`
🎶 Mahlete Semay - Migration CLI 🎶

Usage:
  node migrate.js [options]

Options:
  --dry-run          Simulate migration without modifying Supabase DB or Storage.
  --skip-media       Migrate only database records, skipping media downloads/uploads.
  --media-only       Only process media transfers and update DB URLs.
  --source=<type>    Data source: 'firebase' (default) or 'json' (offline mode).
  --json-dir=<path>  Directory path containing JSON files when source=json.
  --verify-only      Verify Supabase connection and display current row counts.
  --help, -h         Show this help screen.

Examples:
  node migrate.js                         # Run complete migration from Firebase
  node migrate.js --dry-run               # Test run without making any changes
  node migrate.js --source=json           # Migrate from local data_dump/*.json files
  node migrate.js --skip-media            # Migrate records only
  node migrate.js --verify-only           # Check Supabase status
`);
}

if (options.help) {
  printHelp();
  process.exit(0);
}

async function run() {
  console.log('='.repeat(70));
  console.log('🚀 MAHLETE SEMAY - SUPABASE DATA & MEDIA MIGRATION');
  console.log('='.repeat(70));
  console.log(`📡 Supabase Endpoint : ${config.supabaseUrl}`);
  console.log(`🔑 Key Type         : ${config.isServiceRole ? 'Service Role Secret (RLS Bypass)' : 'Standard Key'}`);
  console.log(`📦 Data Source      : ${options.source.toUpperCase()}`);
  console.log(`🛠️ Mode             : ${options.dryRun ? 'DRY-RUN (Simulated)' : 'LIVE MIGRATION'}`);
  console.log(`🎨 Media Transfer   : ${options.skipMedia ? 'SKIPPED' : 'ENABLED'}`);
  console.log('='.repeat(70) + '\n');

  // 1. Validate Config
  const validationErrors = validateConfig(options);
  if (validationErrors.length > 0) {
    console.error('❌ Configuration Errors:');
    validationErrors.forEach(err => console.error(`   - ${err}`));
    console.error('\nPlease update your .env file or environment variables before proceeding.\n');
    process.exit(1);
  }

  // 2. Initialize Importer
  const importer = new SupabaseImporter(config);
  const connTest = await importer.testConnection();
  if (!connTest.success) {
    console.error(`❌ Could not connect to Supabase: ${connTest.message}`);
    process.exit(1);
  }
  console.log(`✅ Supabase connection verified: ${connTest.message}`);

  // If verify-only mode requested
  if (options.verifyOnly) {
    console.log('\n📊 Checking current Supabase table row counts...');
    const tables = ['artists', 'albums', 'songs', 'vocal_plan_days', 'general_exercises', 'moderators', 'suggestions'];
    for (const tbl of tables) {
      try {
        const { count, error } = await importer.client.from(tbl).select('*', { count: 'exact', head: true });
        console.log(`  - ${tbl.padEnd(20)} : ${error ? `Error (${error.message})` : `${count} rows`}`);
      } catch (e) {
        console.log(`  - ${tbl.padEnd(20)} : Error (${e.message})`);
      }
    }
    console.log('\n✨ Verification check complete.');
    process.exit(0);
  }

  // 3. Ensure Storage Buckets
  if (!options.dryRun && !options.skipMedia) {
    await importer.ensureBuckets();
  }

  // 4. Initialize Media Transfer Engine
  const mediaEngine = new MediaTransferEngine(importer.client, config);

  // 5. Extract Legacy Data
  let rawData = {
    artists: [],
    albums: [],
    songs: [],
    generalExercises: [],
    vocalPlans: [],
    moderators: [],
    suggestions: [],
    invitations: [],
    activityLogs: [],
    inviteCodes: [],
  };

  if (options.source === 'json') {
    const jsonExporter = new JsonExporter(options.jsonDir);
    rawData = await jsonExporter.exportAll();
  } else {
    try {
      const fbExporter = new FirebaseExporter(config.firebaseServiceAccountKey);
      rawData = await fbExporter.exportAll();
    } catch (err) {
      console.error(`\n❌ Firebase Export Error: ${err.message}`);
      console.log('\n💡 Tip: If you don\'t have a Firebase service account key, you can export your Firestore collections as JSON into scripts/migration/data_dump/ and run with --source=json\n');
      process.exit(1);
    }
  }

  console.log(`\n📋 Raw Records Extracted:`);
  console.log(`  - Artists            : ${rawData.artists.length}`);
  console.log(`  - Albums             : ${rawData.albums.length}`);
  console.log(`  - Songs              : ${rawData.songs.length}`);
  console.log(`  - Vocal Plans        : ${rawData.vocalPlans.length}`);
  console.log(`  - General Exercises  : ${rawData.generalExercises.length}`);
  console.log(`  - Moderators         : ${rawData.moderators.length}`);
  console.log(`  - Suggestions        : ${rawData.suggestions.length}`);
  console.log(`  - Invitations        : ${rawData.invitations.length}`);
  console.log(`  - Activity Logs      : ${rawData.activityLogs.length}`);
  console.log(`  - Invite Codes       : ${rawData.inviteCodes.length}`);

  // Summary statistics tracker
  const stats = {
    artists: 0,
    albums: 0,
    songs: 0,
    vocalPlans: 0,
    vocalPlanDays: 0,
    generalExercises: 0,
    moderators: 0,
    suggestions: 0,
    mediaTransferred: 0,
    mediaSkipped: 0,
  };

  // Track valid IDs for foreign key integrity
  const validArtistIds = new Set();
  const validAlbumIds = new Set();

  // ---------------------------------------------------------------------------
  // A. PROCESS ARTISTS
  // ---------------------------------------------------------------------------
  console.log('\n🎙️ [1/6] Processing Artists & Profile Media...');
  const transformedArtists = [];

  for (const doc of rawData.artists) {
    const artist = transformArtist(doc.id, doc.data);
    validArtistIds.add(artist.id);

    if (!options.skipMedia && artist.image_url) {
      if (mediaEngine.isSupabaseUrl(artist.image_url)) {
        stats.mediaSkipped++;
      } else {
        const destPath = `artists/${artist.id}`;
        artist.image_url = await mediaEngine.transferMedia({
          sourceUrl: artist.image_url,
          bucket: config.buckets.covers,
          destinationPath: destPath,
          defaultType: 'image',
          dryRun: options.dryRun,
        });
        stats.mediaTransferred++;
      }
    }
    transformedArtists.push(artist);
  }

  if (!options.dryRun) {
    const res = await importer.batchUpsert('artists', transformedArtists);
    stats.artists = res.count;
    console.log(`  ✅ Upserted ${res.count}/${transformedArtists.length} Artists into public.artists`);
  } else {
    stats.artists = transformedArtists.length;
    console.log(`  [Dry-Run] Simulated ${transformedArtists.length} Artists`);
  }

  // ---------------------------------------------------------------------------
  // B. PROCESS ALBUMS
  // ---------------------------------------------------------------------------
  console.log('\n💿 [2/6] Processing Albums & Cover Art...');
  const transformedAlbums = [];

  for (const doc of rawData.albums) {
    const album = transformAlbum(doc.id, doc.data);

    // Ensure valid foreign key
    if (album.artist_id && !validArtistIds.has(album.artist_id)) {
      album.artist_id = null;
    }
    validAlbumIds.add(album.id);

    if (!options.skipMedia && album.cover_image_url) {
      if (mediaEngine.isSupabaseUrl(album.cover_image_url)) {
        stats.mediaSkipped++;
      } else {
        const destPath = `albums/${album.id}`;
        album.cover_image_url = await mediaEngine.transferMedia({
          sourceUrl: album.cover_image_url,
          bucket: config.buckets.covers,
          destinationPath: destPath,
          defaultType: 'image',
          dryRun: options.dryRun,
        });
        stats.mediaTransferred++;
      }
    }
    transformedAlbums.push(album);
  }

  if (!options.dryRun) {
    const res = await importer.batchUpsert('albums', transformedAlbums);
    stats.albums = res.count;
    console.log(`  ✅ Upserted ${res.count}/${transformedAlbums.length} Albums into public.albums`);
  } else {
    stats.albums = transformedAlbums.length;
    console.log(`  [Dry-Run] Simulated ${transformedAlbums.length} Albums`);
  }

  // ---------------------------------------------------------------------------
  // C. PROCESS SONGS
  // ---------------------------------------------------------------------------
  console.log('\n🎵 [3/6] Processing Songs & Lyrics...');
  const transformedSongs = [];

  for (const doc of rawData.songs) {
    const song = transformSong(doc.id, doc.data);

    // Sanitize foreign keys
    if (song.artist_id && !validArtistIds.has(song.artist_id)) {
      song.artist_id = null;
    }
    if (song.album_id && !validAlbumIds.has(song.album_id)) {
      song.album_id = null;
    }

    transformedSongs.push(song);
  }

  if (!options.dryRun) {
    const res = await importer.batchUpsert('songs', transformedSongs);
    stats.songs = res.count;
    console.log(`  ✅ Upserted ${res.count}/${transformedSongs.length} Songs into public.songs`);
  } else {
    stats.songs = transformedSongs.length;
    console.log(`  [Dry-Run] Simulated ${transformedSongs.length} Songs`);
  }

  // ---------------------------------------------------------------------------
  // D. PROCESS VOCAL PLANS & PLAN DAYS
  // ---------------------------------------------------------------------------
  console.log('\n🧘 [4/6] Processing Vocal Plans & Exercise Audio...');
  const planRows = [];
  const transformedPlanDays = [];

  for (const plan of rawData.vocalPlans) {
    planRows.push({
      id: plan.planId,
      title: plan.planId.replace('_', ' ').toUpperCase(),
      description: `Vocal training routine for ${plan.planId}`,
      created_at: new Date().toISOString(),
    });

    for (const dayDoc of plan.days) {
      const day = transformVocalPlanDay(dayDoc.id, plan.planId, dayDoc.data);

      if (!options.skipMedia && day.audio_url && !day.is_rest_day) {
        if (mediaEngine.isSupabaseUrl(day.audio_url)) {
          stats.mediaSkipped++;
        } else {
          const destPath = `vocal_plans/${plan.planId}/${day.id}`;
          day.audio_url = await mediaEngine.transferMedia({
            sourceUrl: day.audio_url,
            bucket: config.buckets.audio,
            destinationPath: destPath,
            defaultType: 'audio',
            dryRun: options.dryRun,
          });
          stats.mediaTransferred++;
        }
      }
      transformedPlanDays.push(day);
    }
  }

  if (!options.dryRun) {
    if (planRows.length > 0) {
      await importer.batchUpsert('vocal_plans', planRows);
      stats.vocalPlans = planRows.length;
    }
    const res = await importer.batchUpsert('vocal_plan_days', transformedPlanDays);
    stats.vocalPlanDays = res.count;
    console.log(`  ✅ Upserted ${res.count}/${transformedPlanDays.length} Vocal Plan Days across ${planRows.length} plans`);
  } else {
    stats.vocalPlans = planRows.length;
    stats.vocalPlanDays = transformedPlanDays.length;
    console.log(`  [Dry-Run] Simulated ${transformedPlanDays.length} Vocal Plan Days across ${planRows.length} plans`);
  }

  // ---------------------------------------------------------------------------
  // E. PROCESS GENERAL EXERCISES
  // ---------------------------------------------------------------------------
  console.log('\n🏋️ [5/6] Processing General Exercises & Audio...');
  const transformedExercises = [];

  for (const doc of rawData.generalExercises) {
    const exercise = transformGeneralExercise(doc.id, doc.data);

    if (!options.skipMedia && exercise.audio_url && !exercise.is_rest_day) {
      if (mediaEngine.isSupabaseUrl(exercise.audio_url)) {
        stats.mediaSkipped++;
      } else {
        const destPath = `general_exercises/${exercise.id}`;
        exercise.audio_url = await mediaEngine.transferMedia({
          sourceUrl: exercise.audio_url,
          bucket: config.buckets.audio,
          destinationPath: destPath,
          defaultType: 'audio',
          dryRun: options.dryRun,
        });
        stats.mediaTransferred++;
      }
    }
    transformedExercises.push(exercise);
  }

  if (!options.dryRun) {
    const res = await importer.batchUpsert('general_exercises', transformedExercises);
    stats.generalExercises = res.count;
    console.log(`  ✅ Upserted ${res.count}/${transformedExercises.length} General Exercises`);
  } else {
    stats.generalExercises = transformedExercises.length;
    console.log(`  [Dry-Run] Simulated ${transformedExercises.length} General Exercises`);
  }

  // ---------------------------------------------------------------------------
  // F. PROCESS AUXILIARY TABLES (Moderators, Suggestions, Invitations, Activity)
  // ---------------------------------------------------------------------------
  console.log('\n👥 [6/6] Processing Auxiliary Collections (Moderators, Suggestions, Logs)...');

  if (rawData.moderators.length > 0) {
    const transformed = rawData.moderators.map(m => transformModerator(m.id, m.data));
    if (!options.dryRun) {
      const res = await importer.batchUpsert('moderators', transformed);
      stats.moderators = res.count;
      console.log(`  ✅ Upserted ${res.count} Moderators`);
    }
  }

  if (rawData.suggestions.length > 0) {
    const transformed = rawData.suggestions.map(s => transformSuggestion(s.id, s.data));
    if (!options.dryRun) {
      const res = await importer.batchUpsert('suggestions', transformed);
      stats.suggestions = res.count;
      console.log(`  ✅ Upserted ${res.count} Lyric Suggestions`);
    }
  }

  if (rawData.invitations.length > 0) {
    const transformed = rawData.invitations.map(i => transformInvitation(i.id, i.data));
    if (!options.dryRun) {
      await importer.batchUpsert('invitations', transformed);
    }
  }

  if (rawData.activityLogs.length > 0) {
    const transformed = rawData.activityLogs.map(a => transformActivityLog(a.id, a.data));
    if (!options.dryRun) {
      await importer.batchUpsert('activity_logs', transformed);
    }
  }

  if (rawData.inviteCodes.length > 0) {
    const transformed = rawData.inviteCodes.map(c => transformInviteCode(c.id, c.data));
    if (!options.dryRun) {
      await importer.batchUpsert('invite_codes', transformed, 'code');
    }
  }

  // ---------------------------------------------------------------------------
  // FINAL SUMMARY REPORT
  // ---------------------------------------------------------------------------
  console.log('\n' + '='.repeat(70));
  console.log('🎉 MIGRATION PROCESS COMPLETED!');
  console.log('='.repeat(70));
  console.table([
    { Entity: 'Artists', Count: stats.artists, Target: 'public.artists' },
    { Entity: 'Albums', Count: stats.albums, Target: 'public.albums' },
    { Entity: 'Songs', Count: stats.songs, Target: 'public.songs' },
    { Entity: 'Vocal Plans', Count: stats.vocalPlans, Target: 'public.vocal_plans' },
    { Entity: 'Vocal Plan Days', Count: stats.vocalPlanDays, Target: 'public.vocal_plan_days' },
    { Entity: 'General Exercises', Count: stats.generalExercises, Target: 'public.general_exercises' },
    { Entity: 'Moderators', Count: stats.moderators, Target: 'public.moderators' },
    { Entity: 'Suggestions', Count: stats.suggestions, Target: 'public.suggestions' },
    { Entity: 'Media Files Uploaded', Count: stats.mediaTransferred, Target: 'Supabase Storage' },
    { Entity: 'Media Files Skipped (Already Supabase)', Count: stats.mediaSkipped, Target: 'Supabase Storage' },
  ]);
  console.log('='.repeat(70));
}

run().catch(err => {
  console.error('\n💥 Unhandled Migration Error:', err);
  process.exit(1);
});
