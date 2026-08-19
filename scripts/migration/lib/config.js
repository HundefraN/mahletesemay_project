import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import dotenv from 'dotenv';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const migrationDir = path.resolve(__dirname, '..');
const projectRootDir = path.resolve(migrationDir, '../..');

// Load .env from scripts/migration/.env first, fallback to workspace root .env
const localEnvPath = path.join(migrationDir, '.env');
const rootEnvPath = path.join(projectRootDir, '.env');

if (fs.existsSync(localEnvPath)) {
  dotenv.config({ path: localEnvPath });
} else if (fs.existsSync(rootEnvPath)) {
  dotenv.config({ path: rootEnvPath });
} else {
  dotenv.config();
}

export const config = {
  supabaseUrl: process.env.SUPABASE_URL || 'https://onsvnudakxkrqazrufar.supabase.co',
  supabaseKey: process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY || '',
  isServiceRole: Boolean(process.env.SUPABASE_SERVICE_ROLE_KEY),
  firebaseServiceAccountKey: process.env.FIREBASE_SERVICE_ACCOUNT_KEY || path.join(migrationDir, 'serviceAccountKey.json'),
  buckets: {
    covers: process.env.SUPABASE_COVERS_BUCKET || 'covers',
    audio: process.env.SUPABASE_AUDIO_BUCKET || 'audio',
    avatars: process.env.SUPABASE_AVATARS_BUCKET || 'avatars',
  },
  batchSize: parseInt(process.env.BATCH_SIZE || '50', 10),
  mediaConcurrency: parseInt(process.env.MEDIA_CONCURRENCY || '5', 10),
  paths: {
    migrationDir,
    projectRootDir,
    dataDir: path.join(migrationDir, 'data_dump'),
  }
};

export function validateConfig(options = {}) {
  const errors = [];
  if (!config.supabaseUrl) {
    errors.push('Missing SUPABASE_URL in environment or .env file');
  }
  if (!config.supabaseKey) {
    errors.push('Missing SUPABASE_SERVICE_ROLE_KEY (or SUPABASE_ANON_KEY) in environment or .env file');
  }
  return errors;
}
