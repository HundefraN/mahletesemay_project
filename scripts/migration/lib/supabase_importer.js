/**
 * Supabase Importer Module
 * Handles batch upsert into PostgreSQL tables and bucket initialization.
 */

import { createClient } from '@supabase/supabase-js';

export class SupabaseImporter {
  constructor(config) {
    this.config = config;
    this.client = createClient(config.supabaseUrl, config.supabaseKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });
  }

  /**
   * Validates database and storage connection.
   */
  async testConnection() {
    try {
      const { data, error } = await this.client.from('artists').select('id').limit(1);
      if (error && error.code !== 'PGRST116') {
        return { success: false, message: `Database error: ${error.message}` };
      }
      return { success: true, message: 'Connected successfully to Supabase' };
    } catch (err) {
      return { success: false, message: `Connection error: ${err.message}` };
    }
  }

  /**
   * Ensures the required storage buckets exist and are marked as public.
   */
  async ensureBuckets() {
    const buckets = [this.config.buckets.covers, this.config.buckets.audio, this.config.buckets.avatars];
    console.log('🪣 Verifying Supabase Storage buckets...');

    for (const bucketName of buckets) {
      try {
        const { data: bucket, error } = await this.client.storage.getBucket(bucketName);
        if (error || !bucket) {
          console.log(`  ➕ Creating bucket '${bucketName}' (public)...`);
          const { error: createErr } = await this.client.storage.createBucket(bucketName, {
            public: true,
          });
          if (createErr && !createErr.message.includes('already exists')) {
            console.warn(`  ⚠️ Could not create bucket '${bucketName}': ${createErr.message}`);
          }
        } else {
          console.log(`  ✅ Bucket '${bucketName}' ready (public: ${bucket.public})`);
        }
      } catch (err) {
        console.warn(`  ⚠️ Bucket check note for '${bucketName}': ${err.message}`);
      }
    }
  }

  /**
   * Batch upserts records into a Supabase table.
   */
  async batchUpsert(tableName, records, primaryKey = 'id') {
    if (!records || records.length === 0) {
      return { count: 0, errors: [] };
    }

    const batchSize = this.config.batchSize || 50;
    let insertedCount = 0;
    const errors = [];

    for (let i = 0; i < records.length; i += batchSize) {
      const batch = records.slice(i, i + batchSize);
      try {
        const { data, error } = await this.client
          .from(tableName)
          .upsert(batch, { onConflict: primaryKey });

        if (error) {
          console.error(`  ❌ Error upserting batch into ${tableName} (rows ${i}..${i + batch.length}): ${error.message}`);
          errors.push(error.message);
        } else {
          insertedCount += batch.length;
        }
      } catch (err) {
        console.error(`  ❌ Unexpected error upserting into ${tableName}: ${err.message}`);
        errors.push(err.message);
      }
    }

    return { count: insertedCount, errors };
  }

  /**
   * Helper to verify existing artists and albums to clean up orphaned foreign keys.
   */
  async getExistingIds(tableName) {
    try {
      const { data, error } = await this.client.from(tableName).select('id');
      if (error || !data) return new Set();
      return new Set(data.map(row => row.id));
    } catch (_) {
      return new Set();
    }
  }
}
