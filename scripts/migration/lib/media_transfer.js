/**
 * Media Transfer Engine
 * Downloads media from Cloudinary / Firebase Storage / Web and uploads to Supabase Storage.
 */

import path from 'path';
import mime from 'mime-types';

export class MediaTransferEngine {
  constructor(supabaseClient, config) {
    this.supabase = supabaseClient;
    this.config = config;
    this.urlCache = new Map(); // Old URL -> New Supabase URL
  }

  isSupabaseUrl(url) {
    if (!url || typeof url !== 'string') return false;
    return url.includes('/storage/v1/object/public/') || url.includes('.supabase.co/storage/');
  }

  isValidUrl(url) {
    if (!url || typeof url !== 'string') return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  inferExtensionAndMime(url, responseHeaders, defaultType = 'image') {
    let contentType = responseHeaders.get('content-type') || '';
    if (contentType.includes(';')) {
      contentType = contentType.split(';')[0].trim();
    }

    let ext = '';
    // Try to get extension from URL path
    try {
      const parsedUrl = new URL(url);
      const pathname = parsedUrl.pathname;
      const parsedExt = path.extname(pathname).toLowerCase();
      if (parsedExt && parsedExt.length <= 5) {
        ext = parsedExt;
      }
    } catch (_) {}

    // If no valid ext from URL, infer from contentType
    if (!ext && contentType) {
      const lookupExt = mime.extension(contentType);
      if (lookupExt) {
        ext = `.${lookupExt}`;
      }
    }

    // Default fallbacks
    if (!ext) {
      ext = defaultType === 'audio' ? '.mp3' : '.jpg';
    }
    if (!contentType) {
      contentType = mime.lookup(ext) || (defaultType === 'audio' ? 'audio/mpeg' : 'image/jpeg');
    }

    return { ext, contentType };
  }

  /**
   * Downloads a media file from source URL and uploads it to Supabase Storage bucket.
   * Returns the new Supabase public URL.
   */
  async transferMedia({
    sourceUrl,
    bucket,
    destinationPath,
    defaultType = 'image',
    dryRun = false,
  }) {
    if (!this.isValidUrl(sourceUrl)) {
      return sourceUrl || '';
    }

    // If it's already a Supabase Storage URL, no need to re-upload
    if (this.isSupabaseUrl(sourceUrl)) {
      return sourceUrl;
    }

    // Check memory cache
    if (this.urlCache.has(sourceUrl)) {
      return this.urlCache.get(sourceUrl);
    }

    if (dryRun) {
      const mockExt = defaultType === 'audio' ? '.mp3' : '.jpg';
      const mockPath = destinationPath.includes('.') ? destinationPath : `${destinationPath}${mockExt}`;
      const mockPublicUrl = `${this.config.supabaseUrl}/storage/v1/object/public/${bucket}/${mockPath}`;
      this.urlCache.set(sourceUrl, mockPublicUrl);
      return mockPublicUrl;
    }

    try {
      // 1. Download file buffer
      const response = await fetch(sourceUrl, {
        headers: {
          'User-Agent': 'MahleteSemayMigrationEngine/1.0',
        },
      });

      if (!response.ok) {
        console.warn(`⚠️ Failed to download media (${response.status}): ${sourceUrl}`);
        return sourceUrl; // Fallback to original URL on download error
      }

      const arrayBuffer = await response.arrayBuffer();
      const buffer = Buffer.from(arrayBuffer);

      // 2. Infer extension and MIME type
      const { ext, contentType } = this.inferExtensionAndMime(sourceUrl, response.headers, defaultType);

      // Ensure proper extension on destination path
      let fullStoragePath = destinationPath;
      if (!path.extname(fullStoragePath)) {
        fullStoragePath = `${destinationPath}${ext}`;
      }

      // 3. Upload to Supabase Storage
      const { data, error } = await this.supabase.storage
        .from(bucket)
        .upload(fullStoragePath, buffer, {
          contentType,
          cacheControl: '3600',
          upsert: true,
        });

      if (error) {
        console.warn(`⚠️ Supabase upload failed for ${fullStoragePath}: ${error.message}`);
        return sourceUrl;
      }

      // 4. Retrieve Public URL
      const { data: publicUrlData } = this.supabase.storage
        .from(bucket)
        .getPublicUrl(fullStoragePath);

      const publicUrl = publicUrlData?.publicUrl || `${this.config.supabaseUrl}/storage/v1/object/public/${bucket}/${fullStoragePath}`;
      this.urlCache.set(sourceUrl, publicUrl);

      return publicUrl;
    } catch (err) {
      console.warn(`⚠️ Error transferring media [${sourceUrl}]: ${err.message}`);
      return sourceUrl;
    }
  }

  /**
   * Concurrently processes a list of tasks with a worker pool limit.
   */
  async pool(items, concurrency, fn) {
    const results = [];
    const executing = [];

    for (const item of items) {
      const p = Promise.resolve().then(() => fn(item));
      results.push(p);

      if (concurrency <= items.length) {
        const e = p.then(() => executing.splice(executing.indexOf(e), 1));
        executing.push(e);
        if (executing.length >= concurrency) {
          await Promise.race(executing);
        }
      }
    }
    return Promise.all(results);
  }
}
