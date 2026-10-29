import type { Game } from '../types/game';

/**
 * Normaliserar IGDB-betyg så att de alltid landar på en enhetlig 0-10 skala.
 */
export function normalizeIgdbRating(val: any): number | undefined {
  if (val === null || val === undefined) return undefined;
  const num = Number(val);
  if (isNaN(num) || num <= 0) return undefined;
  // Om värdet är > 10 har det sparats på en 0-100 skala (t.ex. 84.5 -> 8.5)
  if (num > 10) {
    return Math.round((num / 10) * 10) / 10;
  }
  // Om värdet är <= 5.0 beror det oftast på den tidigare iOS-buggen där totalRating (0-100) delades med 20.0
  // (t.ex. 84 / 20 = 4.2 -> ska vara 8.4 på en 0-10 skala)
  if (num <= 5.0) {
    return Math.round((num * 2) * 10) / 10;
  }
  // Redan på en 0-10 skala (t.ex. 8.4)
  return Math.round(num * 10) / 10;
}

export interface GameMetadataPayload {
  completed_year?: number | null;
  completed_date?: string | null;
  story_progress?: string | null;
  hours_played?: number | null;
  progress_note?: string | null;
  note_updated_at?: string | null;
  is_backlog?: boolean | null;
  is_owned?: boolean | null;
  last_played_date?: string | null;
  started_playing_date?: string | null;
  paused_date?: string | null;
  priority?: number | null;
  play_types?: string[] | null;
}

export const META_REGEX = /^<!--GS_META:([\s\S]*?)-->\r?\n?/;

export function unpackGameNotes(rawNotes: string | null | undefined): { notes: string; meta: GameMetadataPayload } {
  if (!rawNotes) {
    return { notes: '', meta: {} };
  }
  const match = rawNotes.match(META_REGEX);
  if (!match) {
    return { notes: rawNotes, meta: {} };
  }
  try {
    const meta = JSON.parse(match[1]);
    const cleanNotes = rawNotes.slice(match[0].length);
    return { notes: cleanNotes, meta: meta || {} };
  } catch {
    return { notes: rawNotes, meta: {} };
  }
}

export function packGameNotes(userNotes: string | null | undefined, meta: GameMetadataPayload): string {
  const cleanNotes = (userNotes || '').replace(META_REGEX, '').trim();
  const cleanMeta: Record<string, any> = {};

  if (meta.completed_year !== undefined && meta.completed_year !== null) cleanMeta.completed_year = Number(meta.completed_year);
  else if (meta.completed_year === null) cleanMeta.completed_year = null;
  if (meta.completed_date) cleanMeta.completed_date = meta.completed_date;
  if (meta.story_progress) cleanMeta.story_progress = meta.story_progress;
  if (meta.hours_played !== undefined && meta.hours_played !== null) cleanMeta.hours_played = Number(meta.hours_played);
  if (meta.progress_note) cleanMeta.progress_note = meta.progress_note;
  if (meta.note_updated_at) cleanMeta.note_updated_at = meta.note_updated_at;
  if (meta.is_backlog !== undefined && meta.is_backlog !== null) cleanMeta.is_backlog = Boolean(meta.is_backlog);
  if (meta.is_owned !== undefined && meta.is_owned !== null) cleanMeta.is_owned = Boolean(meta.is_owned);
  if (meta.last_played_date) cleanMeta.last_played_date = meta.last_played_date;
  if (meta.started_playing_date) cleanMeta.started_playing_date = meta.started_playing_date;
  if (meta.paused_date) cleanMeta.paused_date = meta.paused_date;
  if (meta.priority !== undefined && meta.priority !== null) cleanMeta.priority = Number(meta.priority);
  if (Array.isArray(meta.play_types) && meta.play_types.length > 0) cleanMeta.play_types = meta.play_types;

  if (Object.keys(cleanMeta).length === 0) {
    return cleanNotes;
  }

  const metaStr = `<!--GS_META:${JSON.stringify(cleanMeta)}-->`;
  return cleanNotes ? `${metaStr}\n${cleanNotes}` : metaStr;
}

/**
 * Strips unknown PostgreSQL columns from game updates/inserts to prevent PostgREST PGRST204 errors,
 * while safely persisting first-class metadata columns and keeping notes clean.
 */
export function sanitizeUserGamePayload(updates: Partial<Game>, existingGame?: Partial<Game>): Record<string, any> {
  const merged: Partial<Game> = {
    ...existingGame,
    ...updates,
  };

  // Safely extract existing metadata if legacy notes exist
  const { notes: existingNotes, meta: existingMeta } = unpackGameNotes(existingGame?.notes);
  const userNotes = updates.notes !== undefined 
    ? unpackGameNotes(updates.notes).notes 
    : existingNotes;

  const mergedMeta: GameMetadataPayload = {
    completed_year: merged.completed_year !== undefined ? merged.completed_year : existingMeta.completed_year,
    completed_date: merged.completed_date !== undefined ? merged.completed_date : existingMeta.completed_date,
    story_progress: merged.story_progress !== undefined ? merged.story_progress : existingMeta.story_progress,
    hours_played: merged.hours_played !== undefined ? merged.hours_played : existingMeta.hours_played,
    progress_note: merged.progress_note !== undefined ? merged.progress_note : existingMeta.progress_note,
    note_updated_at: merged.note_updated_at !== undefined ? merged.note_updated_at : existingMeta.note_updated_at,
    is_backlog: merged.is_backlog !== undefined ? merged.is_backlog : existingMeta.is_backlog,
    is_owned: merged.is_owned !== undefined ? merged.is_owned : existingMeta.is_owned,
    last_played_date: merged.last_played_date !== undefined ? merged.last_played_date : existingMeta.last_played_date,
    play_types: merged.play_types !== undefined ? merged.play_types : existingMeta.play_types,
  };

  // Map both standard and new metadata columns in Supabase 'user_games' schema
  const payload: Record<string, any> = {
    updated_at: new Date().toISOString(),
  };

  if (updates.id !== undefined) payload.id = updates.id;
  if (updates.user_id !== undefined) payload.user_id = updates.user_id;
  if (updates.title !== undefined) payload.title = updates.title;
  if (updates.cover_url !== undefined) payload.cover_url = updates.cover_url;
  if ((updates as any).platform !== undefined) payload.platform = (updates as any).platform;
  else if (updates.platforms && updates.platforms.length > 0) payload.platform = updates.platforms[0];
  if (updates.platforms !== undefined) payload.platforms = updates.platforms;
  if (updates.genres !== undefined) payload.genres = updates.genres;
  if (updates.developers !== undefined) payload.developers = updates.developers;
  if (updates.status !== undefined) payload.status = updates.status;
  if (updates.rating !== undefined) payload.rating = updates.rating;
  if (updates.igdb_rating !== undefined) payload.igdb_rating = updates.igdb_rating;
  if (updates.release_year !== undefined) payload.release_year = updates.release_year;
  if (updates.first_release_date !== undefined) payload.first_release_date = updates.first_release_date;
  if (updates.estimated_hours !== undefined) payload.estimated_hours = updates.estimated_hours;
  if (updates.is_owned !== undefined) payload.is_owned = updates.is_owned;
  if (updates.todos !== undefined) payload.todos = updates.todos;
  if (updates.igdb_id !== undefined) payload.igdb_id = updates.igdb_id;

  // New first-class metadata columns
  if (merged.story_progress !== undefined) payload.story_progress = merged.story_progress;
  if (merged.hours_played !== undefined) payload.hours_played = merged.hours_played;
  if (merged.progress_note !== undefined) payload.progress_note = merged.progress_note;
  if (merged.note_updated_at !== undefined) payload.note_updated_at = merged.note_updated_at;
  if (merged.play_types !== undefined) payload.play_types = merged.play_types;
  if (merged.priority !== undefined) payload.priority = merged.priority;
  if (merged.is_backlog !== undefined) payload.is_backlog = merged.is_backlog;
  if (merged.last_played_date !== undefined) payload.last_played_date = merged.last_played_date;
  if (merged.completed_year !== undefined) payload.completed_year = merged.completed_year;
  if (merged.completed_date !== undefined) payload.completed_date = merged.completed_date;

  // Store clean user notes (without tag clutter)
  payload.notes = userNotes;

  return payload;
}

/**
 * Fallback payload builder when the remote Supabase 'user_games' table only has the core columns
 * (packing extended metadata safely into <!--GS_META:...--> inside notes while preserving todos).
 */
export function buildCoreUserGamePayload(updates: Partial<Game>, existingGame?: Partial<Game>): Record<string, any> {
  const merged: Partial<Game> = {
    ...existingGame,
    ...updates,
  };

  const { notes: existingNotes, meta: existingMeta } = unpackGameNotes(existingGame?.notes);
  const userNotes = updates.notes !== undefined
    ? unpackGameNotes(updates.notes).notes
    : existingNotes;

  const mergedMeta: GameMetadataPayload = {
    completed_year: merged.completed_year !== undefined ? merged.completed_year : existingMeta.completed_year,
    completed_date: merged.completed_date !== undefined ? merged.completed_date : existingMeta.completed_date,
    story_progress: merged.story_progress !== undefined ? merged.story_progress : existingMeta.story_progress,
    hours_played: merged.hours_played !== undefined ? merged.hours_played : existingMeta.hours_played,
    progress_note: merged.progress_note !== undefined ? merged.progress_note : existingMeta.progress_note,
    note_updated_at: merged.note_updated_at !== undefined ? merged.note_updated_at : existingMeta.note_updated_at,
    is_backlog: merged.is_backlog !== undefined ? merged.is_backlog : existingMeta.is_backlog,
    is_owned: merged.is_owned !== undefined ? merged.is_owned : existingMeta.is_owned,
    last_played_date: merged.last_played_date !== undefined ? merged.last_played_date : existingMeta.last_played_date,
    started_playing_date: merged.started_playing_date !== undefined ? merged.started_playing_date : existingMeta.started_playing_date,
    paused_date: merged.paused_date !== undefined ? merged.paused_date : existingMeta.paused_date,
    play_types: merged.play_types !== undefined ? merged.play_types : existingMeta.play_types,
  };

  const payload: Record<string, any> = {
    updated_at: new Date().toISOString(),
  };

  if (updates.id !== undefined) payload.id = updates.id;
  if (updates.user_id !== undefined) payload.user_id = updates.user_id;
  if (updates.title !== undefined) payload.title = updates.title;
  if (updates.cover_url !== undefined) payload.cover_url = updates.cover_url;
  if ((updates as any).platform !== undefined) payload.platform = (updates as any).platform;
  else if (updates.platforms && updates.platforms.length > 0) payload.platform = updates.platforms[0];
  if (updates.platforms !== undefined) payload.platforms = updates.platforms;
  if (updates.genres !== undefined) payload.genres = updates.genres;
  if (updates.developers !== undefined) payload.developers = updates.developers;
  if (updates.status !== undefined) payload.status = updates.status;
  if (updates.rating !== undefined) payload.rating = updates.rating;
  if (updates.igdb_rating !== undefined) payload.igdb_rating = updates.igdb_rating;
  if (updates.release_year !== undefined) payload.release_year = updates.release_year;
  if (updates.estimated_hours !== undefined) payload.estimated_hours = updates.estimated_hours;
  if (updates.is_owned !== undefined) payload.is_owned = updates.is_owned;
  if (updates.todos !== undefined) payload.todos = updates.todos;
  else if (merged.todos !== undefined) payload.todos = merged.todos;
  if (updates.igdb_id !== undefined) payload.igdb_id = updates.igdb_id;

  payload.notes = packGameNotes(userNotes, mergedMeta);

  return payload;
}
