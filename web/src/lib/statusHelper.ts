import { PlayStatus, GamePlayType, Game } from '@/types/game';

/**
 * Normaliserar inkommande statussträngar från Supabase, localStorage eller äldre format.
 */
export function normalizePlayStatus(raw?: string | null): {
  status: PlayStatus;
  is_backlog: boolean;
  is_owned_override?: boolean;
} {
  const s = (raw || '').toLowerCase().trim();

  switch (s) {
    case 'playing':
    case 'spelar':
    case 'spelar nu':
    case 'inprogress':
    case 'in_progress':
    case 'pågående':
    case 'aktiv':
      return { status: 'playing', is_backlog: false };

    case 'backlog':
      return { status: 'notStarted', is_backlog: true };

    case 'unplayed':
    case 'ej spelat':
    case 'ej påbörjat':
    case 'inte påbörjat':
    case 'inte spelat':
    case 'notstarted':
    case 'not_started':
      return { status: 'notStarted', is_backlog: false };

    case 'paused':
    case 'pausat':
    case 'tar paus':
      return { status: 'paused', is_backlog: false };

    case 'completed':
    case 'klar':
    case 'klart':
    case 'genomspelat':
    case 'inte aktiv längre':
    case '100%':
    case '100 %':
    case 'hundredpercent':
      return { status: 'completed', is_backlog: false };

    case 'abandoned':
    case 'avbruten':
    case 'avbrutet':
    case 'droppat':
    case 'dropped':
    case 'slutat spela':
      return { status: 'abandoned', is_backlog: false };

    case 'wishlist':
    case 'önskelista':
      return { status: 'notStarted', is_backlog: false, is_owned_override: false };

    default:
      return { status: 'notStarted', is_backlog: false };
  }
}

/**
 * Automatisk inferens av speltyp baserat på titel, genrer och spellägen.
 */
export function inferPlayTypes(game: {
  title?: string;
  genres?: string[];
  game_modes?: string[];
}): GamePlayType[] {
  const types = new Set<GamePlayType>();

  const allModes = (game.game_modes || []).map((m) => m.toLowerCase());
  const allGenres = (game.genres || []).map((g) => g.toLowerCase());
  const lowerTitle = (game.title || '').toLowerCase();

  for (const mode of allModes) {
    if (mode.includes('single player') || mode === 'singleplayer') {
      types.add('singlePlayer');
    }
    if (
      mode.includes('multiplayer') ||
      mode.includes('battle royale') ||
      mode.includes('mmo') ||
      mode.includes('split screen')
    ) {
      types.add('multiplayer');
    }
    if (
      mode.includes('co-operative') ||
      mode.includes('cooperative') ||
      mode.includes('coop') ||
      mode.includes('co-op')
    ) {
      types.add('coOp');
    }
  }

  const combinedText = `${lowerTitle} ${allGenres.join(' ')} ${allModes.join(' ')}`;

  const multiplayerKeywords = [
    'multiplayer',
    'online',
    'co-op',
    'cooperative',
    'coop',
    'samarbete',
    'split screen',
    'battle royale',
    'mmo',
    'mmorpg',
    'massively multiplayer',
    'live service',
    'hell let loose',
    'helldivers',
    'warzone',
    'apex legends',
    'fortnite',
    'destiny',
    'overwatch',
    'valorant',
    'counter-strike',
    'world of warcraft',
    'final fantasy xiv',
    'league of legends',
    'dota',
    'rocket league',
    'rainbow six',
    'rainbow 6',
    'genshin impact',
    'battlefield',
    'call of duty',
    'pubg',
    'dead by daylight',
    'squad',
    'rust',
    'dayz',
    'sea of thieves',
    'deep rock galactic',
    'warframe',
    'smite',
    'team fortress',
    'street fighter',
    'tekken',
    'mortal kombat',
    'smash bros',
    'overcooked',
    'it takes two',
    'among us',
    'phasmophobia',
    'lethal company',
    'enlisted',
    'insurgency',
    'arma',
    'fall guys',
    'roblox',
    'hunt: showdown',
    'the finals',
    'arc raiders',
    'escape from tarkov',
    'tarkov',
    'chivalry',
    'mordhau',
    'payday',
    'left 4 dead',
    'back 4 blood',
    'borderlands',
    'diablo',
    'path of exile',
    'fifa',
    'fc 24',
    'fc 25',
    'ea sports',
    'nba 2k',
    'madden',
    'nhl',
  ];

  const ongoingKeywords = [
    'mmo',
    'mmorpg',
    'massively multiplayer',
    'live service',
    'battle royale',
    'hell let loose',
    'helldivers',
    'warzone',
    'apex legends',
    'fortnite',
    'destiny',
    'overwatch',
    'valorant',
    'counter-strike',
    'world of warcraft',
    'final fantasy xiv',
    'league of legends',
    'dota',
    'rocket league',
    'rainbow six',
    'rainbow 6',
    'genshin impact',
    'pubg',
    'dead by daylight',
    'rust',
    'sea of thieves',
    'warframe',
    'the finals',
    'roblox',
    'fall guys',
    'hunt: showdown',
    'escape from tarkov',
    'tarkov',
  ];

  for (const kw of multiplayerKeywords) {
    if (combinedText.includes(kw)) {
      types.add('multiplayer');
      break;
    }
  }

  for (const kw of ongoingKeywords) {
    if (combinedText.includes(kw)) {
      types.add('ongoing');
      types.add('multiplayer');
      break;
    }
  }

  if (
    combinedText.includes('co-op') ||
    combinedText.includes('cooperative') ||
    combinedText.includes('coop') ||
    combinedText.includes('samarbete')
  ) {
    types.add('coOp');
  }

  if (types.size === 0) {
    types.add('singlePlayer');
  }

  const order: GamePlayType[] = ['singlePlayer', 'multiplayer', 'coOp', 'ongoing'];
  return order.filter((t) => types.has(t));
}

/**
 * Avgör om ett spel ska behandlas som multiplayer eller ongoing.
 */
export function isMultiplayerOrOngoing(game?: Partial<Game> | null): boolean {
  if (!game) return false;
  if (game.play_types && game.play_types.length > 0) {
    return (
      game.play_types.includes('multiplayer') ||
      game.play_types.includes('ongoing') ||
      game.play_types.includes('coOp')
    );
  }
  // Fallback via automatisk inferens
  const inferred = inferPlayTypes({
    title: game.title,
    genres: game.genres,
  });
  return (
    inferred.includes('multiplayer') ||
    inferred.includes('ongoing') ||
    inferred.includes('coOp')
  );
}

/**
 * Dynamisk statustitel baserat på speltyp.
 */
export function getStatusDisplayTitle(
  status: PlayStatus,
  isMultiplayer: boolean
): string {
  if (isMultiplayer) {
    switch (status) {
      case 'notStarted':
        return 'Inte spelat';
      case 'playing':
        return 'Aktiv';
      case 'paused':
        return 'Tar paus';
      case 'completed':
        return 'Inte aktiv längre';
      case 'abandoned':
        return 'Slutat spela';
    }
  } else {
    switch (status) {
      case 'notStarted':
        return 'Inte påbörjat';
      case 'playing':
        return 'Spelar nu';
      case 'paused':
        return 'Pausat';
      case 'completed':
        return 'Genomspelat';
      case 'abandoned':
        return 'Avbrutet';
    }
  }
}

/**
 * Färgkod per status
 */
export function getStatusColor(status: PlayStatus): {
  bg: string;
  border: string;
  text: string;
  indicator: string;
} {
  switch (status) {
    case 'playing':
      return {
        bg: 'bg-emerald-950/70',
        border: 'border-emerald-500/40',
        text: 'text-emerald-300',
        indicator: 'bg-emerald-500',
      };
    case 'notStarted':
      return {
        bg: 'bg-zinc-900/70',
        border: 'border-zinc-700/50',
        text: 'text-zinc-400',
        indicator: 'bg-zinc-500',
      };
    case 'paused':
      return {
        bg: 'bg-amber-950/70',
        border: 'border-amber-500/40',
        text: 'text-amber-300',
        indicator: 'bg-amber-500',
      };
    case 'completed':
      return {
        bg: 'bg-teal-950/70',
        border: 'border-teal-500/40',
        text: 'text-teal-300',
        indicator: 'bg-teal-500',
      };
    case 'abandoned':
      return {
        bg: 'bg-zinc-800/70',
        border: 'border-zinc-600/40',
        text: 'text-zinc-400',
        indicator: 'bg-zinc-600',
      };
  }
}

/**
 * Formaterar senast spelat
 */
export function formatLastPlayed(dateStr?: string | null): string | null {
  if (!dateStr) return null;
  const d = new Date(dateStr);
  if (isNaN(d.getTime())) return null;

  const now = new Date();
  const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const startOfPlayed = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  const diffDays = Math.round(
    (startOfToday.getTime() - startOfPlayed.getTime()) / (1000 * 60 * 60 * 24)
  );

  if (diffDays === 0) return 'Senast spelat idag';
  if (diffDays === 1) return 'Senast spelat igår';
  if (diffDays < 7) return `Senast spelat för ${diffDays} dagar sedan`;
  return `Senast spelat ${d.toLocaleDateString('sv-SE')}`;
}
