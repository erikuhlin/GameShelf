import { createClient } from '@supabase/supabase-js';
import { Game, GameCollection } from '@/types/game';
import { normalizePlayStatus, inferPlayTypes } from './statusHelper';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || 'http://127.0.0.1:54321';
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || 'dummy_key';

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
  },
  realtime: {
    params: {
      eventsPerSecond: 10,
    },
  },
});

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
  last_played_date?: string | null;
  play_types?: string[] | null;
}

const META_REGEX = /^<!--GS_META:([\s\S]*?)-->\r?\n?/;

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
  if (meta.completed_date) cleanMeta.completed_date = meta.completed_date;
  if (meta.story_progress) cleanMeta.story_progress = meta.story_progress;
  if (meta.hours_played !== undefined && meta.hours_played !== null) cleanMeta.hours_played = Number(meta.hours_played);
  if (meta.progress_note) cleanMeta.progress_note = meta.progress_note;
  if (meta.note_updated_at) cleanMeta.note_updated_at = meta.note_updated_at;
  if (meta.is_backlog !== undefined && meta.is_backlog !== null) cleanMeta.is_backlog = Boolean(meta.is_backlog);
  if (meta.last_played_date) cleanMeta.last_played_date = meta.last_played_date;
  if (Array.isArray(meta.play_types) && meta.play_types.length > 0) cleanMeta.play_types = meta.play_types;

  if (Object.keys(cleanMeta).length === 0) {
    return cleanNotes;
  }

  const metaStr = `<!--GS_META:${JSON.stringify(cleanMeta)}-->`;
  return cleanNotes ? `${metaStr}\n${cleanNotes}` : metaStr;
}

/**
 * Strips unknown PostgreSQL columns from game updates/inserts to prevent PostgREST PGRST204 errors,
 * while safely persisting extra metadata (completed_year, story_progress, hours_played, etc.) inside the notes column.
 */
export function sanitizeUserGamePayload(updates: Partial<Game>, existingGame?: Partial<Game>): Record<string, any> {
  const merged: Partial<Game> = {
    ...existingGame,
    ...updates,
  };

  const userNotes = updates.notes !== undefined ? updates.notes : (existingGame?.notes ?? '');
  const { meta: existingMeta } = unpackGameNotes(existingGame?.notes);

  const mergedMeta: GameMetadataPayload = {
    ...existingMeta,
    completed_year: merged.completed_year !== undefined ? merged.completed_year : existingMeta.completed_year,
    completed_date: merged.completed_date !== undefined ? merged.completed_date : existingMeta.completed_date,
    story_progress: merged.story_progress !== undefined ? merged.story_progress : existingMeta.story_progress,
    hours_played: merged.hours_played !== undefined ? merged.hours_played : existingMeta.hours_played,
    progress_note: merged.progress_note !== undefined ? merged.progress_note : existingMeta.progress_note,
    note_updated_at: merged.note_updated_at !== undefined ? merged.note_updated_at : existingMeta.note_updated_at,
    is_backlog: merged.is_backlog !== undefined ? merged.is_backlog : existingMeta.is_backlog,
    last_played_date: merged.last_played_date !== undefined ? merged.last_played_date : existingMeta.last_played_date,
    play_types: merged.play_types !== undefined ? merged.play_types : existingMeta.play_types,
  };

  const finalNotes = packGameNotes(userNotes, mergedMeta);

  // Exclusively map columns present in Supabase 'user_games' schema
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

  payload.notes = finalNotes;

  return payload;
}

// Database response mapping helpers
export function mapSupabaseGame(row: any): Game {
  const normalized = normalizePlayStatus(row.status);
  const isOwned =
    normalized.is_owned_override !== undefined
      ? normalized.is_owned_override
      : (row.is_owned ?? true);

  const { notes: cleanNotes, meta } = unpackGameNotes(row.notes);

  const genres = row.genres || [];
  const title = row.title || '';
  const storedTypes = Array.isArray(row.play_types)
    ? row.play_types
    : (Array.isArray(meta.play_types) ? meta.play_types : null);
  const playTypes =
    storedTypes && storedTypes.length > 0 && !(storedTypes.length === 1 && storedTypes[0] === 'singlePlayer')
      ? storedTypes
      : inferPlayTypes({ title, genres });

  const currentYear = new Date().getFullYear();
  const fallbackYear = row.updated_at
    ? new Date(row.updated_at).getFullYear()
    : row.created_at
    ? new Date(row.created_at).getFullYear()
    : currentYear;

  const isCompleted = normalized.status === 'completed' || (normalized.status as string) === 'Klar';

  const completedYear =
    meta.completed_year !== undefined && meta.completed_year !== null
      ? Number(meta.completed_year)
      : row.completed_year !== undefined && row.completed_year !== null
      ? Number(row.completed_year)
      : isCompleted
      ? fallbackYear
      : null;

  const completedDate =
    meta.completed_date ||
    row.completed_date ||
    (isCompleted ? row.updated_at || row.created_at || new Date().toISOString() : null);

  return {
    id: row.id,
    user_id: row.user_id,
    title: row.title,
    platforms: row.platforms || [],
    release_year: row.release_year,
    genres,
    developers: row.developers || [],
    status: normalized.status,
    rating: row.rating ? Math.round(Number(row.rating)) : undefined,
    igdb_rating: normalizeIgdbRating(row.igdb_rating),
    cover_url: row.cover_url,
    igdb_id: row.igdb_id ? Number(row.igdb_id) : undefined,
    first_release_date: row.first_release_date ? Number(row.first_release_date) : undefined,
    estimated_hours: row.estimated_hours,
    is_owned: isOwned,
    notes: cleanNotes,
    todos: Array.isArray(row.todos) ? row.todos : [],
    created_at: row.created_at,
    updated_at: row.updated_at,
    is_backlog: meta.is_backlog !== undefined ? Boolean(meta.is_backlog) : (row.is_backlog !== undefined ? Boolean(row.is_backlog) : normalized.is_backlog),
    play_types: playTypes,
    last_played_date: meta.last_played_date || row.last_played_date || null,
    completed_year: completedYear,
    completed_date: completedDate,
    story_progress: meta.story_progress || row.story_progress || (isCompleted ? 'completed' : null),
    hours_played:
      meta.hours_played !== undefined && meta.hours_played !== null
        ? Number(meta.hours_played)
        : row.hours_played !== undefined && row.hours_played !== null
        ? Number(row.hours_played)
        : null,
    progress_note: meta.progress_note || row.progress_note || null,
    note_updated_at: meta.note_updated_at || row.note_updated_at || null,
  };
}

export function mapSupabaseCollection(row: any): GameCollection {
  return {
    id: row.id,
    user_id: row.user_id,
    name: row.name,
    description: row.description || '',
    game_ids: row.game_ids || [],
    created_at: row.created_at,
    updated_at: row.updated_at,
  };
}
