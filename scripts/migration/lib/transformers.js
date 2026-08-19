/**
 * Schema Transformers for Mahlete Semay Migration
 * Normalizes legacy Firestore/JSON documents to Supabase PostgreSQL table schemas.
 */

export function parseTimestamp(val) {
  if (!val) return new Date().toISOString();
  if (val instanceof Date) return val.toISOString();
  if (typeof val === 'object' && typeof val.toDate === 'function') {
    return val.toDate().toISOString();
  }
  if (typeof val === 'object' && val._seconds !== undefined) {
    return new Date(val._seconds * 1000).toISOString();
  }
  if (typeof val === 'object' && val.seconds !== undefined) {
    return new Date(val.seconds * 1000).toISOString();
  }
  if (typeof val === 'number') {
    return new Date(val).toISOString();
  }
  if (typeof val === 'string') {
    const parsed = new Date(val);
    if (!isNaN(parsed.getTime())) {
      return parsed.toISOString();
    }
  }
  return new Date().toISOString();
}

export function transformArtist(docId, data) {
  return {
    id: docId || data.id,
    name: data.name || '',
    image_url: data.imageUrl || data.image_url || '',
    region: data.region || '',
    created_at: parseTimestamp(data.createdAt || data.created_at || data.timestamp),
  };
}

export function transformAlbum(docId, data) {
  const yearNum = parseInt(data.year, 10);
  const volumeNum = parseInt(data.volume, 10);

  return {
    id: docId || data.id,
    title: data.title || '',
    artist_id: data.artistId || data.artist_id || null,
    artist_name: data.artistName || data.artist_name || '',
    cover_image_url: data.coverImageUrl || data.cover_image_url || '',
    year: isNaN(yearNum) ? null : yearNum,
    volume: isNaN(volumeNum) ? null : volumeNum,
    created_at: parseTimestamp(data.createdAt || data.created_at || data.timestamp),
  };
}

export function transformSong(docId, data) {
  const viewCountNum = parseInt(data.viewCount || data.view_count || '0', 10);

  return {
    id: docId || data.id,
    title: data.title || '',
    artist_id: data.artistId || data.artist_id || null,
    artist_name: data.artistName || data.artist_name || '',
    album_id: data.albumId || data.album_id || null,
    album_title: data.albumTitle || data.album_title || '',
    lyrics: data.lyrics || '',
    scale: data.scale || null,
    rhythm: data.rhythm || null,
    view_count: isNaN(viewCountNum) ? 0 : viewCountNum,
    created_at: parseTimestamp(data.createdAt || data.created_at || data.timestamp),
  };
}

export function transformVocalPlanDay(docId, planId, data) {
  const dayNumberNum = parseInt(data.dayNumber || data.day_number || '0', 10);
  const isRest = data.isRestDay === true || data.is_rest_day === true || data.isRestDay === 'true';

  return {
    id: docId || data.id,
    plan_id: planId || data.planId || data.plan_id,
    day_number: isNaN(dayNumberNum) ? 0 : dayNumberNum,
    title: data.title || '',
    description: data.description || '',
    audio_url: isRest ? null : (data.audioUrl || data.audio_url || null),
    is_rest_day: isRest,
    created_at: parseTimestamp(data.createdAt || data.created_at || data.timestamp),
  };
}

export function transformGeneralExercise(docId, data) {
  const dayNumberNum = parseInt(data.dayNumber || data.day_number || '0', 10);
  const isRest = data.isRestDay === true || data.is_rest_day === true || data.isRestDay === 'true';

  return {
    id: docId || data.id,
    day_number: isNaN(dayNumberNum) ? 0 : dayNumberNum,
    title: data.title || '',
    description: data.description || '',
    audio_url: data.audioUrl || data.audio_url || null,
    is_rest_day: isRest,
    created_at: parseTimestamp(data.createdAt || data.created_at || data.timestamp),
  };
}

export function transformModerator(docId, data) {
  return {
    id: docId || data.id,
    email: data.email || '',
    first_name: data.firstName || data.first_name || '',
    last_name: data.lastName || data.last_name || '',
    username: data.username || '',
    role: data.role || 'moderator',
    status: data.status || 'active',
    approved_devices: Array.isArray(data.approvedDevices || data.approved_devices)
      ? (data.approvedDevices || data.approved_devices)
      : [],
    pending_device: data.pendingDevice || data.pending_device || null,
    last_login: data.lastLogin ? parseTimestamp(data.lastLogin) : null,
    created_at: parseTimestamp(data.createdAt || data.created_at),
  };
}

export function transformSuggestion(docId, data) {
  return {
    id: docId || data.id,
    song_title: data.songTitle || data.song_title || '',
    artist_name: data.artistName || data.artist_name || '',
    lyrics: data.lyrics || '',
    submitted_by: data.submittedBy || data.submitted_by || null,
    submitted_at: parseTimestamp(data.submittedAt || data.submitted_at || data.createdAt),
    status: data.status || 'pending',
  };
}

export function transformActivityLog(docId, data) {
  return {
    id: docId || data.id,
    moderator_id: data.moderatorId || data.moderator_id || '',
    moderator_name: data.moderatorName || data.moderator_name || '',
    action: data.action || '',
    details: data.details || '',
    is_seen: Boolean(data.isSeen !== undefined ? data.isSeen : data.is_seen),
    timestamp: parseTimestamp(data.timestamp || data.createdAt),
  };
}

export function transformInvitation(docId, data) {
  return {
    id: docId || data.id,
    code: data.code || '',
    email: data.email || '',
    first_name: data.firstName || data.first_name || '',
    last_name: data.lastName || data.last_name || '',
    status: data.status || 'pending',
    created_by: data.createdBy || data.created_by || '',
    claimed_by: data.claimedBy || data.claimed_by || null,
    claimed_at: data.claimedAt ? parseTimestamp(data.claimedAt) : null,
    created_at: parseTimestamp(data.createdAt || data.created_at),
  };
}

export function transformInviteCode(code, data) {
  return {
    code: code || data.code,
    used: Boolean(data.used),
    used_by: data.usedBy || data.used_by || null,
    created_at: parseTimestamp(data.createdAt || data.created_at),
  };
}
