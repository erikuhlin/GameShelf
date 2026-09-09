'use client';

import React, { useState, useEffect, useMemo } from 'react';
import { Game, PlayStatus } from '@/types/game';
import { normalizeIgdbRating } from '@/lib/supabase';
import { StatusBadge } from './StatusBadge';
import { getStatusDisplayTitle, isMultiplayerOrOngoing } from '@/lib/statusHelper';
import {
  Sparkles,
  Dices,
  Flame,
  Calendar,
  Layers,
  Newspaper,
  ExternalLink,
  Plus,
  Check,
  Search,
  RefreshCw,
  Star,
  Gamepad,
  ArrowRight,
  Play,
  Bookmark,
  BookmarkCheck,
  ChevronDown,
  Target,
  Hourglass,
  Trophy,
  Heart,
} from 'lucide-react';
import { UserProfile } from '@/types/profile';
import { AVATAR_PRESETS } from '@/lib/profileStore';
import { GamingGoalModal } from './GamingGoalModal';

interface DiscoverViewProps {
  games: Game[];
  onSelectGame: (game: Game) => void;
  onAddGame: (game: Game) => void;
  onOpenRouletteModal?: () => void;
  onOpenSearchWithQuery?: (query: string) => void;
  userProfile?: UserProfile;
  onOpenProfileModal?: () => void;
  onUpdateProfile?: (updated: UserProfile) => void;
  onToggleTargetGoal?: (gameId: string) => void;
}

interface NewsItem {
  id: string;
  title: string;
  source: string;
  link: string;
  published: string;
  publishedTimestamp: number;
  image?: string | null;
  summary?: string;
  category?: 'Recension' | 'Nyhet' | 'Trailer' | 'Uppdatering' | 'Guide' | 'Förhandstitt';
  platform?: 'PlayStation' | 'Xbox' | 'Nintendo' | 'PC' | 'Multi';
}

const GENRE_LIST = [
  { id: 'Action', label: 'Action' },
  { id: 'Role-playing (RPG)', label: 'RPG' },
  { id: 'Adventure', label: 'Äventyr' },
  { id: 'Shooter', label: 'Skjutspel' },
  { id: 'Horror', label: 'Skräck' },
  { id: 'Indie', label: 'Indie' },
  { id: 'Strategy', label: 'Strategi' },
  { id: 'Platform', label: 'Plattform' },
  { id: 'Racing', label: 'Racing' },
  { id: 'Fighting', label: 'Fighting' },
  { id: 'Simulator', label: 'Simulator' },
  { id: 'Puzzle', label: 'Pussel' },
  { id: 'Sport', label: 'Sport' },
];

const GENRE_SWEDISH_NAMES: Record<string, string> = {
  'role-playing (rpg)': 'RPG',
  'rpg': 'RPG',
  'shooter': 'Skjutspel',
  'adventure': 'Äventyr',
  'hack and slash/beat \'em up': 'Action',
  'action': 'Action',
  'platform': 'Plattform',
  'racing': 'Racing',
  'fighting': 'Fighting',
  'horror': 'Skräck',
  'strategy': 'Strategi',
  'real time strategy (rts)': 'RTS',
  'turn-based strategy (tbs)': 'Turbaserat',
  'tactical': 'Taktik',
  'simulator': 'Simulator',
  'puzzle': 'Pussel',
  'sport': 'Sport',
  'arcade': 'Arkad',
  'indie': 'Indie',
  'card & board game': 'Kortspel',
  'point-and-click': 'Äventyr',
  'visual novel': 'Visuell roman',
};

const GENRE_HIERARCHY = [
  'role-playing (rpg)',
  'rpg',
  'horror',
  'hack and slash/beat \'em up',
  'fighting',
  'racing',
  'sport',
  'strategy',
  'real time strategy (rts)',
  'shooter',
  'platform',
  'puzzle',
  'simulator',
  'adventure',
  'arcade',
  'indie',
];

export function getPrimaryGenre(genres?: string[], preferredGenre?: string): string {
  if (!genres || genres.length === 0) {
    if (preferredGenre) {
      return GENRE_SWEDISH_NAMES[preferredGenre.toLowerCase()] || preferredGenre;
    }
    return 'Spel';
  }

  // 1. Om användaren filtrerar på en specifik genre (t.ex. RPG) och spelet har den: prioritera den!
  if (preferredGenre) {
    const prefLower = preferredGenre.toLowerCase();
    const match = genres.find(
      (g) => g.toLowerCase() === prefLower || g.toLowerCase().includes(prefLower) || prefLower.includes(g.toLowerCase())
    );
    if (match) {
      return GENRE_SWEDISH_NAMES[match.toLowerCase()] || match;
    }
  }

  // 2. Prioriteringsordning: Välj spelets mest definierande genre (t.ex. RPG eller Skräck framför generiskt Äventyr)
  for (const prio of GENRE_HIERARCHY) {
    const match = genres.find((g) => g.toLowerCase() === prio || g.toLowerCase().includes(prio));
    if (match) {
      return GENRE_SWEDISH_NAMES[match.toLowerCase()] || match;
    }
  }

  return GENRE_SWEDISH_NAMES[genres[0].toLowerCase()] || genres[0];
}

export function getBadgeStyle(badge?: string | null): string {
  if (!badge) return 'bg-zinc-800 text-zinc-300 border-zinc-700';
  if (badge.includes('Toppsäljare')) return 'bg-amber-500/20 text-amber-300 border-amber-500/40';
  if (badge.includes('Twitch')) return 'bg-purple-500/20 text-purple-300 border-purple-500/40';
  if (badge.includes('Efterlängtat')) return 'bg-cyan-500/20 text-cyan-300 border-cyan-500/40';
  if (badge.includes('Söktrend')) return 'bg-rose-500/20 text-rose-300 border-rose-500/40';
  if (badge.includes('spelat') || badge.includes('Spelas')) return 'bg-emerald-500/20 text-emerald-300 border-emerald-500/40';
  if (badge.includes('Önskelistas')) return 'bg-blue-500/20 text-blue-300 border-blue-500/40';
  if (badge.includes('Topprecension')) return 'bg-yellow-500/20 text-yellow-300 border-yellow-500/40';
  if (badge.includes('Mediefokus')) return 'bg-red-500/20 text-red-300 border-red-500/40';
  if (badge.includes('Hett släpp')) return 'bg-orange-500/20 text-orange-300 border-orange-500/40';
  return 'bg-zinc-800/90 text-zinc-200 border-zinc-700';
}

export interface MonthOption {
  id: string;
  title: string;
  startDate?: number;
  endDate?: number;
  isMostHyped: boolean;
}

export const CALENDAR_PLATFORMS = [
  { id: 'all', label: 'Alla' },
  { id: 'ps5', label: 'PlayStation' },
  { id: 'pc', label: 'PC' },
  { id: 'switch', label: 'Nintendo Switch' },
  { id: 'xbox', label: 'Xbox Series' },
];

const PLATFORMS = ['Alla plattformar', 'PlayStation', 'Xbox', 'Nintendo', 'PC'];

export function DiscoverView({
  games,
  onSelectGame,
  onAddGame,
  onOpenRouletteModal,
  onOpenSearchWithQuery,
  userProfile,
  onOpenProfileModal,
  onUpdateProfile,
  onToggleTargetGoal,
}: DiscoverViewProps) {
  const [activeTab, setActiveTab] = useState<'discover' | 'calendar' | 'news'>('discover');

  // Spelmål modal state
  const [isGoalModalOpen, setIsGoalModalOpen] = useState(false);

  // --- Discover State ---
  const [trendingGames, setTrendingGames] = useState<Game[]>([]);
  const [trendingSort, setTrendingSort] = useState<'popularity' | 'rating' | 'newest'>('popularity');
  const [upcomingGames, setUpcomingGames] = useState<Game[]>([]);

  // Genre State
  const [selectedGenre, setSelectedGenre] = useState<string>('Action');
  const [genreGames, setGenreGames] = useState<Game[]>([]);
  const [genreSort, setGenreSort] = useState<'popularity' | 'rating' | 'newest'>('popularity');
  const [genreLimit, setGenreLimit] = useState<number>(12);
  const [isLoadingGenre, setIsLoadingGenre] = useState(true);
  const [isLoadingMoreGenre, setIsLoadingMoreGenre] = useState(false);

  const [isLoadingDiscover, setIsLoadingDiscover] = useState(true);

  // --- In-view Roulette State ---
  const [rouletteMode, setRouletteMode] = useState<'library' | 'igdb'>('library');
  const [rouletteFilter, setRouletteFilter] = useState<'all' | 'backlog' | 'playing'>('all');
  const [isSpinning, setIsSpinning] = useState(false);
  const [winnerGame, setWinnerGame] = useState<Game | null>(null);

  // --- Releasekalender State (Identiskt med iOS UpcomingReleasesView) ---
  const [selectedMonthID, setSelectedMonthID] = useState<string>('most_hyped');
  const [selectedCalendarPlatform, setSelectedCalendarPlatform] = useState<string>('all');
  const [showAllInMonth, setShowAllInMonth] = useState<boolean>(true);
  const [calendarGames, setCalendarGames] = useState<Game[]>([]);
  const [isLoadingCalendar, setIsLoadingCalendar] = useState<boolean>(false);

  // Dynamiska månadsval för releasekalendern (Mest hypade + 6 kommande månader)
  const monthOptions: MonthOption[] = useMemo(() => {
    const now = new Date();
    const localMidnight = Math.floor(new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0).getTime() / 1000);
    const utcMidnight = Math.floor(new Date(Date.UTC(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0)).getTime() / 1000);
    const startOfToday = Math.min(localMidnight, utcMidnight);

    const options: MonthOption[] = [
      {
        id: 'most_hyped',
        title: '🔥 Mest hypade',
        startDate: startOfToday,
        isMostHyped: true,
      },
    ];

    const formatter = new Intl.DateTimeFormat('sv-SE', { month: 'short', year: 'numeric' });

    for (let offset = 0; offset < 6; offset++) {
      const d = new Date(now.getFullYear(), now.getMonth() + offset, 1);
      const year = d.getFullYear();
      const month = d.getMonth();
      const startOfMonth =
        offset === 0
          ? startOfToday
          : Math.floor(new Date(year, month, 1, 0, 0, 0).getTime() / 1000);
      const endOfMonth = Math.floor(new Date(year, month + 1, 0, 23, 59, 59).getTime() / 1000);

      const rawTitle = formatter.format(d);
      const title = rawTitle.charAt(0).toUpperCase() + rawTitle.slice(1);
      options.push({
        id: `month_${year}_${month + 1}`,
        title,
        startDate: startOfMonth,
        endDate: endOfMonth,
        isMostHyped: false,
      });
    }

    return options;
  }, []);

  const currentMonthOption = useMemo(() => {
    return monthOptions.find((m) => m.id === selectedMonthID) || monthOptions[0];
  }, [monthOptions, selectedMonthID]);

  // Hämta spel till releasekalendern vid fliköppning eller filterändring
  const loadCalendarGames = async () => {
    const opt = currentMonthOption;
    const isHyped = opt.isMostHyped;
    const startTs = opt.startDate;
    const endTs = opt.endDate;

    let url = `/api/games/discover?category=upcoming&platform=${selectedCalendarPlatform}`;
    if (isHyped) {
      url += '&is_hyped=true&limit=40';
    } else {
      if (startTs) url += `&start_date=${startTs}`;
      if (endTs) url += `&end_date=${endTs}`;
      url += '&limit=150';
    }

    setIsLoadingCalendar(true);
    try {
      const res = await fetch(url);
      const data = await res.json();
      if (Array.isArray(data.results)) {
        setCalendarGames(data.results);
      }
    } catch (err) {
      console.error('Failed to load release calendar games:', err);
    } finally {
      setIsLoadingCalendar(false);
    }
  };

  useEffect(() => {
    if (activeTab === 'calendar') {
      loadCalendarGames();
    }
  }, [activeTab, selectedMonthID, selectedCalendarPlatform]);

  const displayedCalendarGames = useMemo(() => {
    if (currentMonthOption.isMostHyped || showAllInMonth || calendarGames.length <= 15) {
      return calendarGames;
    }
    const withHypes = calendarGames.filter((g) => (g.hypes || 0) > 0 || (g.rating || 0) > 0);
    return withHypes.length > 0 ? withHypes : calendarGames.slice(0, 15);
  }, [calendarGames, currentMonthOption.isMostHyped, showAllInMonth]);

  // Gruppera spelsläpp per datum (tidslinje i månadsvyn)
  const groupedCalendarReleases = useMemo(() => {
    const groups: Record<string, Game[]> = {};
    const orderMap: Record<string, number> = {};

    const now = new Date();
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();

    for (const game of displayedCalendarGames) {
      if (!game.first_release_date) {
        const yearKey = game.release_year ? `Kommande ${game.release_year}` : 'Kommande';
        if (!groups[yearKey]) {
          groups[yearKey] = [];
          orderMap[yearKey] = 9999999999999;
        }
        groups[yearKey].push(game);
        continue;
      }

      const ms =
        Number(game.first_release_date) < 10000000000
          ? Number(game.first_release_date) * 1000
          : Number(game.first_release_date);
      const dateObj = new Date(ms);
      const key = `${dateObj.getFullYear()}-${String(dateObj.getMonth() + 1).padStart(2, '0')}-${String(dateObj.getDate()).padStart(2, '0')}`;

      if (!groups[key]) {
        groups[key] = [];
        orderMap[key] = ms;
      }
      groups[key].push(game);
    }

    const sortedKeys = Object.keys(groups).sort((a, b) => (orderMap[a] || 0) - (orderMap[b] || 0));

    const dateFormatter = new Intl.DateTimeFormat('sv-SE', {
      weekday: 'long',
      day: 'numeric',
      month: 'long',
      year: 'numeric',
    });

    return sortedKeys.map((key) => {
      const gamesInGroup = groups[key];
      const ms = orderMap[key];

      if (ms >= 9999999999999) {
        return {
          dateKey: key,
          displayDate: key,
          countdown: '',
          games: gamesInGroup,
        };
      }

      const groupDate = new Date(ms);
      const groupStart = new Date(groupDate.getFullYear(), groupDate.getMonth(), groupDate.getDate()).getTime();
      const diffDays = Math.round((groupStart - todayStart) / (1000 * 60 * 60 * 24));

      let countdown = '';
      if (diffDays < 0) countdown = 'Släppt';
      else if (diffDays === 0) countdown = 'Idag';
      else if (diffDays === 1) countdown = 'Imorgon';
      else if (diffDays > 1 && diffDays <= 30) countdown = `Om ${diffDays} dagar`;
      else if (diffDays > 30) {
        const months = Math.max(1, Math.round(diffDays / 30.4));
        countdown = `Om ca ${months} mån`;
      }

      const rawStr = dateFormatter.format(groupDate);
      const displayDate = rawStr.charAt(0).toUpperCase() + rawStr.slice(1);

      return {
        dateKey: key,
        displayDate,
        countdown,
        games: gamesInGroup,
      };
    });
  }, [displayedCalendarGames]);

  // --- News State ---
  const [newsItems, setNewsItems] = useState<NewsItem[]>([]);
  const [isLoadingNews, setIsLoadingNews] = useState(false);
  const [newsSearch, setNewsSearch] = useState('');
  const [selectedNewsCategory, setSelectedNewsCategory] = useState<
    'all' | 'my_games' | 'reviews' | 'updates' | 'trailers' | 'previews' | 'saved'
  >('all');
  const [selectedNewsPlatform, setSelectedNewsPlatform] = useState<string>('Alla plattformar');
  const [selectedNewsSource, setSelectedNewsSource] = useState<string>('Alla källor');
  const [selectedNewsTimeRange, setSelectedNewsTimeRange] = useState<
    'all' | '24h' | '7d' | '30d' | 'older'
  >('all');
  const [savedNewsIds, setSavedNewsIds] = useState<string[]>([]);

  // Ladda sparade bokmärken
  useEffect(() => {
    if (typeof window !== 'undefined') {
      try {
        const saved = localStorage.getItem('gameshelf_saved_news_ids');
        if (saved) setSavedNewsIds(JSON.parse(saved));
      } catch (e) {}
    }
  }, []);

  const toggleSaveArticle = (e: React.MouseEvent, id: string) => {
    e.preventDefault();
    e.stopPropagation();
    const updated = savedNewsIds.includes(id)
      ? savedNewsIds.filter((item) => item !== id)
      : [id, ...savedNewsIds];
    setSavedNewsIds(updated);
    if (typeof window !== 'undefined') {
      localStorage.setItem('gameshelf_saved_news_ids', JSON.stringify(updated));
    }
  };

  // Spel som användaren för tillfället spelar
  const currentlyPlaying = useMemo(() => {
    return games.filter(
      (g) =>
        (g.status === 'playing' || (g.status as string) === 'Spelar nu') &&
        g.is_owned
    );
  }, [games]);

  // Nästa släpp i din önskelista (identiskt med regeln i iOS-appen)
  const nextWishlistRelease = useMemo(() => {
    const now = Date.now();
    const currentYear = new Date().getFullYear();

    const candidates = games.filter((g) => {
      if (g.is_owned) return false;
      if (g.first_release_date) {
        const ms =
          Number(g.first_release_date) < 10000000000
            ? Number(g.first_release_date) * 1000
            : Number(g.first_release_date);
        return ms > now;
      }
      return Boolean(g.release_year && g.release_year >= currentYear);
    });

    const getEffectiveDate = (g: Game): number => {
      if (g.first_release_date) {
        return Number(g.first_release_date) < 10000000000
          ? Number(g.first_release_date) * 1000
          : Number(g.first_release_date);
      }
      if (g.release_year) {
        return new Date(g.release_year, 11, 31).getTime();
      }
      return Infinity;
    };

    return (
      candidates.sort((a, b) => {
        const timeA = getEffectiveDate(a);
        const timeB = getEffectiveDate(b);
        if (timeA !== timeB) return timeA - timeB;
        return a.title.localeCompare(b.title);
      })[0] || null
    );
  }, [games]);

  const nextWishlistDays = useMemo(() => {
    if (!nextWishlistRelease?.first_release_date) return null;
    const ms =
      Number(nextWishlistRelease.first_release_date) < 10000000000
        ? Number(nextWishlistRelease.first_release_date) * 1000
        : Number(nextWishlistRelease.first_release_date);
    const diff = ms - Date.now();
    return Math.max(0, Math.ceil(diff / (1000 * 60 * 60 * 24)));
  }, [nextWishlistRelease]);

  const currentYear = new Date().getFullYear();

  // Spelmål beräkning: tar ENDAST hänsyn till spel där man satt klarat år till innevarande år (t.ex. 2026)
  const completedGamesCount = useMemo(() => {
    return games.filter(
      (g) =>
        (g.status === 'completed' || (g.status as string) === 'Klar') &&
        g.is_owned !== false &&
        Number(g.completed_year) === currentYear
    ).length;
  }, [games, currentYear]);

  const targetGames = useMemo(() => {
    const ids = new Set((userProfile?.targetGameIDs || []).map((id) => id.toLowerCase()));
    if (ids.size === 0) return [];
    return games.filter(
      (g) =>
        ids.has(g.id.toLowerCase()) ||
        (g.igdb_id !== undefined && g.igdb_id !== null && ids.has(String(g.igdb_id).toLowerCase()))
    );
  }, [games, userProfile?.targetGameIDs]);

  const completedTargetCount = useMemo(() => {
    return targetGames.filter(
      (g) => g.status === 'completed' || (g.status as string) === 'Klar'
    ).length;
  }, [targetGames]);

  const annualGoal =
    userProfile?.annualGamingGoal !== undefined && userProfile?.annualGamingGoal !== null
      ? userProfile.annualGamingGoal
      : 12;
  const goalProgressPct = Math.min(100, Math.round((completedGamesCount / annualGoal) * 100));

  const avatarPreset = userProfile?.avatarType?.startsWith('preset:')
    ? AVATAR_PRESETS.find((p) => p.id === userProfile.avatarType)
    : null;

  // Hämta trending och upcoming med lokal cache för omedelbar respons
  useEffect(() => {
    let isCancelled = false;

    async function loadDiscoverFeed() {
      // 1. Läs från cache för omedelbar rendering vid sidöppning
      const cacheKey = `gameshelf_discover_${trendingSort}`;
      if (typeof window !== 'undefined') {
        try {
          const cached = localStorage.getItem(cacheKey) || sessionStorage.getItem(cacheKey);
          if (cached) {
            const parsed = JSON.parse(cached);
            const hasTrending = Array.isArray(parsed.trending) && parsed.trending.length > 0;
            const hasUpcoming = Array.isArray(parsed.upcoming) && parsed.upcoming.length > 0;
            if (hasTrending) {
              setTrendingGames(parsed.trending);
            }
            if (hasUpcoming) {
              setUpcomingGames(parsed.upcoming);
            }
            if (hasTrending && hasUpcoming) {
              setIsLoadingDiscover(false);
            }
          }
        } catch (e) {}
      }

      try {
        const [trendRes, upRes] = await Promise.allSettled([
          fetch(`/api/games/discover?category=trending&sort=${trendingSort}&era=recent&limit=25`).then((r) => {
            if (!r.ok) throw new Error(`HTTP ${r.status}`);
            return r.json();
          }),
          fetch('/api/games/discover?category=upcoming&limit=20').then((r) => {
            if (!r.ok) throw new Error(`HTTP ${r.status}`);
            return r.json();
          }),
        ]);

        if (isCancelled) return;

        let freshTrending: Game[] = [];
        let freshUpcoming: Game[] = [];

        if (trendRes.status === 'fulfilled' && Array.isArray(trendRes.value?.results) && trendRes.value.results.length > 0) {
          freshTrending = trendRes.value.results;
          setTrendingGames(freshTrending);
        }
        if (upRes.status === 'fulfilled' && Array.isArray(upRes.value?.results) && upRes.value.results.length > 0) {
          freshUpcoming = upRes.value.results;
          setUpcomingGames(freshUpcoming);
        }

        if (typeof window !== 'undefined' && (freshTrending.length > 0 || freshUpcoming.length > 0)) {
          try {
            const dataToSave = JSON.stringify({
              trending: freshTrending.length > 0 ? freshTrending : trendingGames,
              upcoming: freshUpcoming.length > 0 ? freshUpcoming : upcomingGames,
            });
            localStorage.setItem(cacheKey, dataToSave);
            sessionStorage.setItem(cacheKey, dataToSave);
          } catch (e) {}
        }
      } catch (err) {
        console.error('Error loading discover feed:', err);
      } finally {
        if (!isCancelled) {
          setIsLoadingDiscover(false);
        }
      }
    }

    loadDiscoverFeed();
    return () => {
      isCancelled = true;
    };
  }, [trendingSort]);

  // Hämta genrespel vid byte av genre eller sortering
  useEffect(() => {
    let isCancelled = false;

    async function loadGenreGames() {
      setGenreLimit(12);

      const cacheKey = `gameshelf_genre_${selectedGenre}_${genreSort}`;
      if (typeof window !== 'undefined') {
        try {
          const cached = localStorage.getItem(cacheKey) || sessionStorage.getItem(cacheKey);
          if (cached) {
            const parsed = JSON.parse(cached);
            if (Array.isArray(parsed) && parsed.length > 0) {
              setGenreGames(parsed);
              setIsLoadingGenre(false);
            }
          }
        } catch (e) {}
      }

      try {
        const res = await fetch(
          `/api/games/discover?genre=${encodeURIComponent(selectedGenre)}&sort=${genreSort}&era=recent&limit=12`
        );
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const data = await res.json();
        if (!isCancelled && Array.isArray(data?.results) && data.results.length > 0) {
          setGenreGames(data.results);
          if (typeof window !== 'undefined') {
            try {
              const str = JSON.stringify(data.results);
              localStorage.setItem(cacheKey, str);
              sessionStorage.setItem(cacheKey, str);
            } catch (e) {}
          }
        }
      } catch (e) {
        console.error('Error loading genre games:', e);
      } finally {
        if (!isCancelled) {
          setIsLoadingGenre(false);
        }
      }
    }

    loadGenreGames();
    return () => {
      isCancelled = true;
    };
  }, [selectedGenre, genreSort]);

  // Hämta fler spel sömlöst utan att hoppa till toppen
  const handleLoadMoreGenre = async () => {
    const nextLimit = genreLimit + 12;
    setIsLoadingMoreGenre(true);
    try {
      const res = await fetch(
        `/api/games/discover?genre=${encodeURIComponent(selectedGenre)}&sort=${genreSort}&era=recent&limit=${nextLimit}`
      );
      const data = await res.json();
      if (data.results) {
        setGenreGames(data.results);
        setGenreLimit(nextLimit);
      }
    } catch (e) {
      console.error('Failed to load more genre games:', e);
    } finally {
      setIsLoadingMoreGenre(false);
    }
  };

  // Hämta nyheter vid flikbyte eller manuell uppdatering med persistent arkiverande sammanslagning
  const handleFetchNews = async (forceRefresh = false) => {
    setIsLoadingNews(true);
    try {
      const res = await fetch(`/api/news?t=${Date.now()}`, {
        cache: 'no-store',
      });
      if (!res.ok) {
        throw new Error(`HTTP ${res.status}`);
      }
      const data = await res.json();
      if (data.news && Array.isArray(data.news) && data.news.length > 0) {
        let existingArchive: NewsItem[] = [];
        if (!forceRefresh && typeof window !== 'undefined') {
          try {
            const raw = localStorage.getItem('gameshelf_news_archive');
            if (raw) existingArchive = JSON.parse(raw);
          } catch (e) {}
        }

        const merged = [...data.news, ...existingArchive];
        const seen = new Set<string>();
        const unique = merged.filter((item) => {
          const key = item.link || item.title.toLowerCase().replace(/[^a-z0-9]/g, '');
          if (seen.has(key)) return false;
          seen.add(key);
          return true;
        });

        unique.sort((a, b) => b.publishedTimestamp - a.publishedTimestamp);
        const finalArchive = unique.slice(0, 1000);

        setNewsItems(finalArchive);
        if (typeof window !== 'undefined') {
          try {
            localStorage.setItem('gameshelf_news_archive', JSON.stringify(finalArchive));
          } catch (e) {}
        }
      }
    } catch (e) {
      console.error('Error loading news:', e);
    } finally {
      setIsLoadingNews(false);
    }
  };

  useEffect(() => {
    if (activeTab !== 'news') return;

    // 1. Läs in från lokalt arkiv omedelbart så att användaren ser sparade och tidigare artiklar direkt
    if (typeof window !== 'undefined') {
      try {
        const cached = localStorage.getItem('gameshelf_news_archive');
        if (cached) {
          const parsed = JSON.parse(cached);
          if (Array.isArray(parsed) && parsed.length > 0) {
            setNewsItems(parsed);
          }
        }
      } catch (e) {}
    }

    handleFetchNews(false);
  }, [activeTab]);

  // Kör spelsnurran
  const handleSpinRoulette = () => {
    setIsSpinning(true);
    setWinnerGame(null);

    let candidates: Game[] = [];
    if (rouletteMode === 'library') {
      if (rouletteFilter === 'backlog') {
        candidates = games.filter((g) => g.is_backlog && g.is_owned);
      } else if (rouletteFilter === 'playing') {
        candidates = games.filter(
          (g) =>
            (g.status === 'playing' || (g.status as string) === 'Spelar nu') &&
            g.is_owned
        );
      } else {
        candidates = games.length > 0 ? games.filter((g) => g.is_owned) : [];
      }
    } else {
      candidates = trendingGames;
    }

    if (candidates.length === 0) {
      setIsSpinning(false);
      return;
    }

    let speed = 70;
    let iterations = 0;
    const maxIterations = 24;

    const interval = setInterval(() => {
      const randomIdx = Math.floor(Math.random() * candidates.length);
      setWinnerGame(candidates[randomIdx]);
      iterations++;

      if (iterations >= maxIterations) {
        clearInterval(interval);
        setIsSpinning(false);
      }
    }, speed);
  };

  const findMatchingLibraryGame = (title: string): Game | undefined => {
    const cleanTitle = title.toLowerCase();
    return games.find((g) => {
      const t = g.title.toLowerCase();
      return t.length >= 4 && cleanTitle.includes(t);
    });
  };

  const newsSources = useMemo(() => {
    const sources = Array.from(new Set(newsItems.map((n) => n.source))).filter(Boolean);
    return ['Alla källor', ...sources];
  }, [newsItems]);

  const filteredNews = useMemo(() => {
    let result = newsItems;

    if (newsSearch.trim()) {
      const q = newsSearch.toLowerCase();
      result = result.filter(
        (n) =>
          n.title.toLowerCase().includes(q) ||
          n.source.toLowerCase().includes(q) ||
          (n.summary && n.summary.toLowerCase().includes(q))
      );
    }

    if (selectedNewsCategory === 'my_games') {
      result = result.filter((n) => findMatchingLibraryGame(n.title) !== undefined);
    } else if (selectedNewsCategory === 'reviews') {
      result = result.filter((n) => {
        const lower = n.title.toLowerCase();
        const isPreview =
          n.category === 'Förhandstitt' ||
          lower.includes('preview') ||
          lower.includes('förhandstitt') ||
          lower.includes('hands-on') ||
          lower.includes('handson') ||
          lower.includes('first look') ||
          lower.includes('sneak peek') ||
          lower.includes('impressions');
        if (isPreview) return false;
        return (
          n.category === 'Recension' ||
          lower.startsWith('review:') ||
          lower.startsWith('recension:') ||
          lower.includes(' review') ||
          lower.includes('recension') ||
          lower.includes('verdict')
        );
      });
    } else if (selectedNewsCategory === 'updates') {
      result = result.filter(
        (n) =>
          n.category === 'Uppdatering' ||
          n.title.toLowerCase().includes('patch') ||
          n.title.toLowerCase().includes('update') ||
          n.title.toLowerCase().includes('uppdatering') ||
          n.title.toLowerCase().includes('hotfix')
      );
    } else if (selectedNewsCategory === 'trailers') {
      result = result.filter(
        (n) =>
          n.category === 'Trailer' ||
          n.title.toLowerCase().includes('trailer') ||
          n.title.toLowerCase().includes('gameplay')
      );
    } else if (selectedNewsCategory === 'previews') {
      result = result.filter((n) => {
        const lower = n.title.toLowerCase();
        return (
          n.category === 'Förhandstitt' ||
          lower.includes('preview') ||
          lower.includes('förhandstitt') ||
          lower.includes('hands-on') ||
          lower.includes('handson') ||
          lower.includes('first look') ||
          lower.includes('sneak peek') ||
          lower.includes('impressions')
        );
      });
    } else if (selectedNewsCategory === 'saved') {
      result = result.filter((n) => savedNewsIds.includes(n.id));
    }

    if (selectedNewsPlatform !== 'Alla plattformar') {
      result = result.filter((n) => {
        const lower = n.title.toLowerCase();
        if (selectedNewsPlatform === 'PlayStation') {
          return n.platform === 'PlayStation' || lower.includes('ps5') || lower.includes('playstation');
        }
        if (selectedNewsPlatform === 'Xbox') {
          return n.platform === 'Xbox' || lower.includes('xbox') || lower.includes('series');
        }
        if (selectedNewsPlatform === 'Nintendo') {
          return n.platform === 'Nintendo' || lower.includes('switch') || lower.includes('nintendo');
        }
        if (selectedNewsPlatform === 'PC') {
          return n.platform === 'PC' || lower.includes('pc') || lower.includes('steam');
        }
        return true;
      });
    }

    if (selectedNewsSource !== 'Alla källor') {
      result = result.filter((n) => n.source === selectedNewsSource);
    }

    if (selectedNewsTimeRange !== 'all') {
      const now = Date.now();
      const h24 = 24 * 60 * 60 * 1000;
      const d7 = 7 * 24 * 60 * 60 * 1000;
      const d30 = 30 * 24 * 60 * 60 * 1000;

      result = result.filter((n) => {
        const timestamp = n.publishedTimestamp || (n.published ? new Date(n.published).getTime() : 0);
        if (!timestamp) return false;
        const age = now - timestamp;
        if (selectedNewsTimeRange === '24h') return age <= h24;
        if (selectedNewsTimeRange === '7d') return age <= d7;
        if (selectedNewsTimeRange === '30d') return age <= d30;
        if (selectedNewsTimeRange === 'older') return age > d30;
        return true;
      });
    }

    return result;
  }, [
    newsItems,
    newsSearch,
    selectedNewsCategory,
    selectedNewsPlatform,
    selectedNewsSource,
    selectedNewsTimeRange,
    savedNewsIds,
    games,
  ]);

  const isGameInLibrary = (igdbId?: number | string | null, title?: string) => {
    return games.some(
      (g) =>
        (igdbId && g.igdb_id === Number(igdbId)) ||
        (title && g.title.toLowerCase() === title.toLowerCase())
    );
  };

  const getMatchingGame = (igdbId?: number | string | null, title?: string) => {
    return games.find(
      (g) =>
        (igdbId && g.igdb_id === Number(igdbId)) ||
        (title && g.title.toLowerCase() === title.toLowerCase())
    );
  };

  const cleanArticleTitle = (title: string) => {
    return title.replace(/^Review:\s*/i, '').trim();
  };

  const currentGenreLabel = GENRE_LIST.find((g) => g.id === selectedGenre)?.label || selectedGenre;

  return (
    <div className="space-y-8 pb-12 animate-in fade-in duration-200">
      {/* 1. Ren Tab Switcher: Upptäck vs Releasekalender vs Nyheter */}
      <div className="flex items-center justify-between border-b border-zinc-800/80 pb-3">
        <div className="flex items-center bg-zinc-900 border border-zinc-800 p-1 rounded-2xl overflow-x-auto scrollbar-none max-w-full">
          <button
            onClick={() => setActiveTab('discover')}
            className={`flex items-center gap-2 px-3.5 py-1.5 rounded-xl text-xs sm:text-sm font-bold transition whitespace-nowrap cursor-pointer ${
              activeTab === 'discover'
                ? 'bg-brand-red text-white shadow-sm'
                : 'text-zinc-400 hover:text-zinc-200'
            }`}
          >
            <Sparkles className="w-4 h-4" />
            <span>För dig & Upptäck</span>
          </button>

          <button
            onClick={() => setActiveTab('calendar')}
            className={`flex items-center gap-2 px-3.5 py-1.5 rounded-xl text-xs sm:text-sm font-bold transition whitespace-nowrap cursor-pointer ${
              activeTab === 'calendar'
                ? 'bg-brand-red text-white shadow-sm'
                : 'text-zinc-400 hover:text-zinc-200'
            }`}
          >
            <Calendar className="w-4 h-4" />
            <span>Releasekalender</span>
          </button>

          <button
            onClick={() => setActiveTab('news')}
            className={`flex items-center gap-2 px-3.5 py-1.5 rounded-xl text-xs sm:text-sm font-bold transition whitespace-nowrap cursor-pointer ${
              activeTab === 'news'
                ? 'bg-brand-red text-white shadow-sm'
                : 'text-zinc-400 hover:text-zinc-200'
            }`}
          >
            <Newspaper className="w-4 h-4" />
            <span>Spelnyheter & Recensioner</span>
          </button>
        </div>
      </div>

      {activeTab === 'discover' ? (
        <div className="space-y-8">
          {/* 1. Välkomsthälsning & Spelmål 2026 */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            {/* Välkomstkort */}
            <div className="md:col-span-2 bg-gradient-to-r from-zinc-900/90 via-zinc-900/60 to-zinc-950 border border-zinc-800/80 rounded-3xl p-5 sm:p-6 flex items-center gap-4 sm:gap-5 shadow-lg">
              <div className="w-14 h-14 sm:w-16 sm:h-16 rounded-2xl flex items-center justify-center flex-shrink-0 text-2xl sm:text-3xl shadow-xl overflow-hidden border border-white/10 bg-zinc-800">
                {userProfile?.avatarCustomImage ? (
                  <img src={userProfile.avatarCustomImage} alt="Avatar" className="w-full h-full object-cover" />
                ) : avatarPreset ? (
                  <div
                    className="w-full h-full flex items-center justify-center text-2xl sm:text-3xl"
                    style={{
                      background: `linear-gradient(135deg, ${avatarPreset.gradientColors[0]}, ${avatarPreset.gradientColors[1]})`,
                    }}
                  >
                    <span>{avatarPreset.icon}</span>
                  </div>
                ) : (
                  <div className="w-full h-full flex items-center justify-center bg-gradient-to-br from-brand-red to-rose-700 text-white font-black text-xl">
                    {userProfile?.username ? userProfile.username.charAt(0).toUpperCase() : 'G'}
                  </div>
                )}
              </div>
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-2 flex-wrap">
                  <h2 className="text-lg sm:text-2xl font-black text-white tracking-tight">
                    Hej {userProfile?.username || 'Gamer'}!
                  </h2>
                  <span className="text-xl">👋</span>
                </div>
                <p className="text-xs sm:text-sm text-zinc-400 mt-1 leading-relaxed">
                  Håll koll på dina spel, kommande släpp och utforska nya världar.
                </p>
              </div>
            </div>

            {/* Spelmål 2026 kort */}
            <div className="bg-zinc-900/90 border border-zinc-800/80 rounded-3xl p-5 flex flex-col justify-between shadow-lg">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-1.5 text-xs font-black uppercase tracking-wider text-amber-400">
                  <Trophy className="w-4 h-4 text-amber-400" />
                  <span>Spelmål 2026</span>
                </div>
                <button
                  type="button"
                  onClick={() => setIsGoalModalOpen(true)}
                  className="text-[11px] font-semibold text-zinc-400 hover:text-white transition cursor-pointer"
                >
                  Ändra mål →
                </button>
              </div>

              <div className="my-2">
                <div className="flex items-baseline justify-between mb-1.5">
                  <div className="flex items-baseline gap-2">
                    <span className="text-xl font-black text-white font-mono">
                      {completedGamesCount >= annualGoal
                        ? `${completedGamesCount} klara`
                        : `${completedGamesCount} / ${annualGoal}`}
                    </span>
                    {completedGamesCount >= annualGoal && (
                      <span className="text-[11px] font-bold text-emerald-400 font-mono">
                        (Mål: {annualGoal})
                      </span>
                    )}
                  </div>
                  <span
                    className={`text-xs font-bold font-mono ${
                      completedGamesCount >= annualGoal ? 'text-emerald-400' : 'text-zinc-400'
                    }`}
                  >
                    {completedGamesCount >= annualGoal ? '100% 🏆' : `${goalProgressPct}%`}
                  </span>
                </div>
                <div className="w-full h-2.5 rounded-full bg-zinc-950 border border-zinc-800 overflow-hidden">
                  <div
                    className={`h-full rounded-full transition-all duration-500 ${
                      completedGamesCount >= annualGoal
                        ? 'bg-gradient-to-r from-emerald-500 to-teal-400'
                        : 'bg-gradient-to-r from-amber-500 to-emerald-400'
                    }`}
                    style={{ width: `${goalProgressPct}%` }}
                  />
                </div>
              </div>

              <div className="flex items-center justify-between text-[11px] text-zinc-400 font-medium">
                <span>
                  {completedGamesCount >= annualGoal
                    ? 'Målet uppnått! Fantastiskt spelår! 🎉'
                    : `${Math.max(0, annualGoal - completedGamesCount)} spel kvar till målet`}
                </span>
                {targetGames.length > 0 && (
                  <span className="text-amber-400 font-semibold">
                    🎯 {targetGames.length} fokusmål ({completedTargetCount} {completedTargetCount === 1 ? 'klart' : 'klara'})
                  </span>
                )}
              </div>
            </div>
          </div>

          {/* Fokusmål Spotlight */}
          {targetGames.length > 0 && (
            <div className="space-y-3.5">
              <div className="flex items-center justify-between gap-3">
                <div className="flex items-center gap-2 text-xs sm:text-sm font-bold text-amber-400 uppercase tracking-wider">
                  <Target className="w-4 h-4 text-amber-400" />
                  <span>Aktiva Fokusmål ({targetGames.length}/3)</span>
                </div>
                <button
                  type="button"
                  onClick={() => setIsGoalModalOpen(true)}
                  className="text-xs font-semibold text-zinc-400 hover:text-amber-400 transition cursor-pointer"
                >
                  Hantera mål →
                </button>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-4">
                {targetGames.map((game) => {
                  const isDone = game.status === 'completed' || (game.status as string) === 'Klar';
                  const totalTodos = game.todos?.length || 0;
                  const doneTodos = game.todos?.filter((t) => t.isDone).length || 0;

                  return (
                    <div
                      key={game.id}
                      onClick={() => onSelectGame(game)}
                      className={`group relative rounded-2xl p-4 flex gap-3.5 items-center cursor-pointer transition-all border shadow-lg ${
                        isDone
                          ? 'bg-emerald-950/20 border-emerald-500/40 hover:border-emerald-500/70'
                          : 'bg-zinc-900/90 border-zinc-800 hover:border-amber-500/50 hover:bg-zinc-850'
                      }`}
                    >
                      <div className="w-14 h-20 rounded-xl overflow-hidden bg-zinc-800 flex-shrink-0 relative shadow">
                        {game.cover_url ? (
                          <img
                            src={game.cover_url}
                            alt={game.title}
                            className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                          />
                        ) : (
                          <div className="w-full h-full flex items-center justify-center text-zinc-600">
                            <Gamepad className="w-6 h-6" />
                          </div>
                        )}
                        {isDone && (
                          <div className="absolute inset-0 bg-emerald-950/70 flex items-center justify-center">
                            <Trophy className="w-5 h-5 text-yellow-400 animate-bounce" />
                          </div>
                        )}
                      </div>

                      <div className="min-w-0 flex-1 space-y-1.5">
                        <div className="flex items-center gap-1.5">
                          <span className="text-[10px] font-bold px-1.5 py-0.5 rounded bg-amber-500/15 text-amber-400 border border-amber-500/30 uppercase tracking-wider">
                            🎯 Mål
                          </span>
                          {isDone ? (
                            <span className="text-[10px] font-bold px-1.5 py-0.5 rounded bg-emerald-500/20 text-emerald-400 border border-emerald-500/30">
                              Klarat! 🏆
                            </span>
                          ) : (
                            <StatusBadge game={game} />
                          )}
                        </div>

                        <h3 className="text-sm font-bold text-white line-clamp-2 leading-snug group-hover:text-amber-400 transition-colors">
                          {game.title}
                        </h3>

                        {totalTodos > 0 ? (
                          <div className="space-y-1">
                            <div className="flex items-center justify-between text-[11px] text-zinc-400">
                              <span>Delmål:</span>
                              <span className="font-semibold text-zinc-200">
                                {doneTodos}/{totalTodos} klara
                              </span>
                            </div>
                            <div className="w-full h-1.5 rounded-full bg-zinc-950 border border-zinc-800 overflow-hidden">
                              <div
                                className="h-full bg-amber-500 rounded-full transition-all duration-300"
                                style={{ width: `${Math.round((doneTodos / totalTodos) * 100)}%` }}
                              />
                            </div>
                          </div>
                        ) : (
                          <p className="text-[11px] text-zinc-400 truncate">
                            {game.platforms?.join(', ') || 'Inget format angivet'}
                          </p>
                        )}
                      </div>
                    </div>
                  );
                })}

                {/* Lägg till fokusmål kort om < 3 */}
                {targetGames.length < 3 && (
                  <div
                    onClick={() => setIsGoalModalOpen(true)}
                    className="group relative rounded-2xl p-4 flex gap-3.5 items-center justify-center cursor-pointer transition-all border border-dashed border-zinc-800 hover:border-amber-500/50 hover:bg-zinc-900/60 min-h-[110px]"
                  >
                    <div className="w-11 h-11 rounded-xl bg-amber-500/10 border border-amber-500/20 flex items-center justify-center text-amber-400 group-hover:scale-110 transition-transform flex-shrink-0">
                      <Plus className="w-5 h-5" />
                    </div>
                    <div className="min-w-0">
                      <span className="text-xs font-bold text-white group-hover:text-amber-400 transition-colors block">
                        Lägg till fokusmål
                      </span>
                      <span className="text-[11px] text-zinc-500 block">
                        Välj ur biblioteket ({3 - targetGames.length} kvar)
                      </span>
                    </div>
                  </div>
                )}
              </div>
            </div>
          )}

          {/* 2. Zon 1: Ditt Spelande (Fortsätt spela) - Ligger alltid överst när man har aktiva spel */}
          {currentlyPlaying.length > 0 && (
            <div className="space-y-3.5">
              <div className="flex items-center justify-between gap-3">
                <div className="flex items-center gap-2 text-xs sm:text-sm font-bold text-zinc-200 uppercase tracking-wider">
                  <Play className="w-3.5 h-3.5 text-emerald-400 fill-current" />
                  <span>Ditt spelande just nu ({currentlyPlaying.length})</span>
                </div>
                {onOpenRouletteModal ? (
                  <button
                    onClick={onOpenRouletteModal}
                    className="flex items-center gap-1.5 px-3 py-1 rounded-xl bg-zinc-900 border border-zinc-800 hover:border-zinc-700 text-xs font-semibold text-zinc-300 hover:text-white transition cursor-pointer"
                  >
                    <Dices className="w-3.5 h-3.5 text-brand-red" />
                    <span>Snurra fram ett spel</span>
                  </button>
                ) : (
                  <a
                    href="#roulette-section"
                    className="flex items-center gap-1.5 px-3 py-1 rounded-xl bg-zinc-900 border border-zinc-800 hover:border-zinc-700 text-xs font-semibold text-zinc-300 hover:text-white transition"
                  >
                    <Dices className="w-3.5 h-3.5 text-brand-red" />
                    <span>Snurra fram ett spel</span>
                  </a>
                )}
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3 sm:gap-4">
                {currentlyPlaying.map((game) => (
                  <div
                    key={game.id}
                    onClick={() => onSelectGame(game)}
                    className="flex items-center gap-3.5 p-3 rounded-2xl bg-zinc-900/60 hover:bg-zinc-900 border border-zinc-800 hover:border-zinc-700 cursor-pointer group transition shadow-sm"
                  >
                    <div className="w-12 h-16 rounded-xl overflow-hidden bg-zinc-950 flex-shrink-0 border border-zinc-800 shadow-md">
                      {game.cover_url ? (
                        <img
                          src={game.cover_url}
                          alt={game.title}
                          className="w-full h-full object-cover group-hover:scale-105 transition duration-300"
                        />
                      ) : (
                        <div className="w-full h-full flex items-center justify-center">
                          <Gamepad className="w-6 h-6 text-zinc-600" />
                        </div>
                      )}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-1.5 mb-0.5">
                        <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
                        <span className="text-[10px] font-bold text-emerald-400 uppercase tracking-wider">
                          Spelar nu
                        </span>
                      </div>
                      <h4 className="text-xs sm:text-sm font-bold text-white line-clamp-2 leading-snug group-hover:text-red-400 transition">
                        {game.title}
                      </h4>
                      <p className="text-[11px] text-zinc-400 mt-0.5 truncate">
                        {game.platforms?.[0] || 'Aktivt spel'}
                      </p>
                      {game.rating && (
                        <span className="text-[10px] text-amber-400 font-semibold mt-0.5 block">
                          ⭐ {game.rating}/10
                        </span>
                      )}
                    </div>
                    <div className="p-2 rounded-xl bg-zinc-800/60 group-hover:bg-brand-red group-hover:text-white text-zinc-400 transition flex-shrink-0">
                      <ArrowRight className="w-4 h-4 group-hover:translate-x-0.5 transition" />
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* 3. Nästa släpp i din önskelista (om sådant finns) */}
          {nextWishlistRelease && (
            <div
              onClick={() => onSelectGame(nextWishlistRelease)}
              className="group relative overflow-hidden rounded-3xl bg-gradient-to-r from-red-950/40 via-zinc-900/90 to-zinc-950 border border-red-900/40 hover:border-brand-red/60 p-5 sm:p-6 shadow-xl cursor-pointer transition duration-300"
            >
              <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 sm:gap-6">
                {/* Vänster: Spelinfo & Omslag */}
                <div className="flex items-center gap-4 sm:gap-5 min-w-0 flex-1">
                  {/* Omslagsbild */}
                  <div className="w-16 h-22 sm:w-20 sm:h-28 rounded-2xl overflow-hidden bg-zinc-950 flex-shrink-0 border border-zinc-800 shadow-2xl group-hover:scale-105 transition duration-300">
                    {nextWishlistRelease.cover_url ? (
                      <img
                        src={nextWishlistRelease.cover_url}
                        alt={nextWishlistRelease.title}
                        className="w-full h-full object-cover"
                      />
                    ) : (
                      <div className="w-full h-full flex items-center justify-center">
                        <Gamepad className="w-8 h-8 text-zinc-600" />
                      </div>
                    )}
                  </div>

                  <div className="min-w-0">
                    <div className="flex items-center gap-2 mb-1.5">
                      <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-brand-red/20 border border-brand-red/50 text-[10px] sm:text-[11px] font-black text-rose-300 uppercase tracking-wider">
                        <Hourglass className="w-3 h-3 text-brand-red animate-pulse" />
                        <span>Nästa släpp i din önskelista</span>
                      </span>
                    </div>

                    <h3 className="text-base sm:text-xl font-black text-white group-hover:text-red-400 transition line-clamp-2 leading-tight">
                      {nextWishlistRelease.title}
                    </h3>

                    <div className="flex flex-wrap items-center gap-2 mt-1 text-xs text-zinc-400">
                      {nextWishlistRelease.first_release_date ? (
                        <span className="flex items-center gap-1 font-semibold text-zinc-300">
                          <Calendar className="w-3.5 h-3.5 text-brand-red" />
                          {new Date(
                            Number(nextWishlistRelease.first_release_date) *
                              (Number(nextWishlistRelease.first_release_date) < 10000000000 ? 1000 : 1)
                          ).toLocaleDateString('sv-SE', {
                            weekday: 'short',
                            year: 'numeric',
                            month: 'short',
                            day: 'numeric',
                          })}
                        </span>
                      ) : (
                        <span>{nextWishlistRelease.release_year}</span>
                      )}
                      {nextWishlistRelease.platforms?.[0] && (
                        <>
                          <span>•</span>
                          <span>{nextWishlistRelease.platforms[0]}</span>
                        </>
                      )}
                    </div>
                  </div>
                </div>

                {/* Mitten: Rymlig nedräkning (ersätter den lilla rutan) */}
                {nextWishlistDays !== null ? (
                  <div className="flex items-center gap-4 sm:gap-5 py-2 px-4 sm:px-5 rounded-2xl bg-zinc-950/70 border border-zinc-800/80 shrink-0 shadow-inner">
                    <div className="flex items-baseline gap-2">
                      <span className="text-3xl sm:text-4xl font-black text-rose-400 font-mono tracking-tight">
                        {nextWishlistDays}
                      </span>
                      <div className="flex flex-col">
                        <span className="text-xs sm:text-sm font-bold text-white leading-none">
                          {nextWishlistDays === 1 ? 'dag' : 'dagar'}
                        </span>
                        <span className="text-[10px] text-zinc-400 font-semibold uppercase tracking-wider mt-0.5">
                          kvar till release
                        </span>
                      </div>
                    </div>

                    {nextWishlistDays > 30 && (
                      <div className="hidden lg:flex flex-col pl-4 border-l border-zinc-800 text-left">
                        <span className="text-xs font-bold text-zinc-300">
                          Ca {Math.round((nextWishlistDays / 30.4) * 10) / 10} månader
                        </span>
                        <span className="text-[10px] text-zinc-500 font-medium">
                          Spikat släppdatum
                        </span>
                      </div>
                    )}
                  </div>
                ) : nextWishlistRelease.release_year ? (
                  <div className="flex items-center gap-3 py-2.5 px-4 sm:px-5 rounded-2xl bg-zinc-950/70 border border-zinc-800/80 shrink-0 shadow-inner">
                    <span className="text-xs text-zinc-400 font-medium">Planerat släpp:</span>
                    <span className="text-xl sm:text-2xl font-black text-amber-400 font-mono">
                      {nextWishlistRelease.release_year}
                    </span>
                  </div>
                ) : null}

                {/* Höger: Tydlig knapp */}
                <div className="flex items-center justify-end shrink-0">
                  <div className="flex items-center gap-2 px-4 py-3 rounded-2xl bg-zinc-800/80 group-hover:bg-brand-red group-hover:text-white text-zinc-300 transition shadow-md font-semibold text-xs">
                    <span className="hidden sm:inline">Visa spel</span>
                    <ArrowRight className="w-4 h-4 group-hover:translate-x-1 transition" />
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* Om användaren INTE har några spel i Spelar nu: visa Spelsnurran här */}
          {currentlyPlaying.length === 0 && (
            <div className="relative overflow-hidden rounded-3xl bg-gradient-to-br from-zinc-900/90 via-zinc-950/95 to-black border border-zinc-800/80 p-5 sm:p-7 shadow-xl">
              <div className="relative z-10 flex flex-col md:flex-row items-center justify-between gap-6">
                <div className="max-w-md text-center md:text-left">
                  <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-brand-red/10 border border-brand-red/30 text-rose-300 text-xs font-bold uppercase tracking-wider mb-2.5">
                    <Dices className="w-3.5 h-3.5 text-brand-red" />
                    <span>Smart Spelsnurra</span>
                  </div>
                  <h3 className="text-xl sm:text-2xl font-extrabold text-white tracking-tight">
                    Vad ska du spela ikväll?
                  </h3>
                  <p className="text-xs sm:text-sm text-zinc-400 mt-1 leading-relaxed">
                    Låt slumpen välja bland dina ospelade spel i backloggen eller upptäck nya rekommendationer.
                  </p>

                  <div className="flex flex-wrap items-center justify-center md:justify-start gap-2 mt-3.5">
                    <button
                      onClick={() => setRouletteMode('library')}
                      className={`px-3 py-1.5 rounded-xl text-xs font-semibold border transition ${
                        rouletteMode === 'library'
                          ? 'bg-white text-zinc-950 border-white'
                          : 'bg-zinc-900 border-zinc-800 text-zinc-400 hover:text-zinc-200'
                      }`}
                    >
                      Mina spel ({games.length})
                    </button>
                    <button
                      onClick={() => setRouletteMode('igdb')}
                      className={`px-3 py-1.5 rounded-xl text-xs font-semibold border transition ${
                        rouletteMode === 'igdb'
                          ? 'bg-white text-zinc-950 border-white'
                          : 'bg-zinc-900 border-zinc-800 text-zinc-400 hover:text-zinc-200'
                      }`}
                    >
                      Upptäck från IGDB
                    </button>
                  </div>
                </div>

                <div className="flex flex-col items-center gap-3.5 w-full sm:w-auto">
                  {winnerGame ? (
                    <div
                      onClick={() => onSelectGame(winnerGame)}
                      className="flex items-center gap-3.5 p-2.5 bg-zinc-900/90 border border-zinc-700/80 rounded-2xl cursor-pointer hover:border-zinc-500 transition shadow-lg w-full max-w-sm group"
                    >
                      <div className="w-14 h-18 rounded-xl overflow-hidden bg-zinc-950 flex-shrink-0 relative border border-zinc-800">
                        {winnerGame.cover_url ? (
                          <img
                            src={winnerGame.cover_url}
                            alt={winnerGame.title}
                            className="w-full h-full object-cover group-hover:scale-105 transition"
                          />
                        ) : (
                          <div className="w-full h-full flex items-center justify-center">
                            <Gamepad className="w-6 h-6 text-zinc-600" />
                          </div>
                        )}
                      </div>
                      <div className="flex-1 min-w-0">
                        <span className="text-[10px] uppercase font-bold text-amber-400 tracking-wider block">
                          Utvalt spel!
                        </span>
                        <h4 className="text-sm font-bold text-white truncate group-hover:text-red-400 transition">
                          {winnerGame.title}
                        </h4>
                        <p className="text-[11px] text-zinc-400 mt-0.5">
                          {winnerGame.release_year ? `${winnerGame.release_year} • ` : ''}
                          {winnerGame.genres?.[0] || 'Spel'}
                        </p>
                      </div>
                      <ArrowRight className="w-4 h-4 text-zinc-400 group-hover:text-white transition mr-1" />
                    </div>
                  ) : (
                    <div className="w-full max-w-sm h-20 border border-dashed border-zinc-800 rounded-2xl flex items-center justify-center text-zinc-500 text-xs px-4 text-center">
                      Klicka nedan för att slumpa fram ett spel
                    </div>
                  )}

                  <button
                    onClick={handleSpinRoulette}
                    disabled={isSpinning || (rouletteMode === 'library' && games.length === 0)}
                    className="w-full sm:w-auto px-7 py-2.5 bg-gradient-to-r from-brand-red to-rose-600 hover:from-brand-redPressed hover:to-rose-700 disabled:opacity-50 text-white font-bold text-xs sm:text-sm rounded-xl shadow-lg transition flex items-center justify-center gap-2"
                  >
                    <Dices className={`w-4 h-4 ${isSpinning ? 'animate-spin' : ''}`} />
                    <span>{isSpinning ? 'Snurrar hjulet...' : '🎲 Snurra fram ett spel!'}</span>
                  </button>
                </div>
              </div>
            </div>
          )}

          {/* 4. 📅 Kommande spelsläpp (Releasekalender från IGDB) */}
          <div className="space-y-3.5">
            <div className="flex items-center justify-between gap-3">
              <div className="flex items-center gap-2">
                <Calendar className="w-4 h-4 text-brand-red" />
                <h3 className="text-sm sm:text-base font-bold text-white tracking-tight">
                  Kommande spelsläpp
                </h3>
              </div>
              <button
                onClick={() => setActiveTab('calendar')}
                className="flex items-center gap-1.5 text-xs font-semibold text-brand-red hover:text-red-400 transition cursor-pointer"
              >
                <span>Öppna hela releasekalendern</span>
                <ArrowRight className="w-3.5 h-3.5" />
              </button>
            </div>

            {isLoadingDiscover && upcomingGames.length === 0 ? (
              <div className="flex gap-3.5 overflow-x-auto pb-2.5 scrollbar-none">
                {[1, 2, 3, 4, 5, 6].map((i) => (
                  <div
                    key={i}
                    className="flex-shrink-0 w-36 sm:w-44 h-56 rounded-2xl bg-zinc-900/60 border border-zinc-800/80 animate-pulse flex flex-col p-2.5"
                  >
                    <div className="w-full aspect-[3/4] rounded-xl bg-zinc-800/60 mb-2.5" />
                    <div className="w-3/4 h-3 bg-zinc-800 rounded mb-1.5" />
                    <div className="w-1/2 h-2.5 bg-zinc-800/60 rounded" />
                  </div>
                ))}
              </div>
            ) : upcomingGames.length > 0 ? (
              <div className="flex gap-3.5 overflow-x-auto pb-2.5 scrollbar-thin scrollbar-thumb-zinc-800">
                {upcomingGames.map((game) => {
                  const matching = getMatchingGame(game.igdb_id, game.title);
                  const inLibrary = Boolean(matching);
                  const inWishlist = Boolean(matching && matching.is_owned === false);
                  const isToday = game.first_release_date
                    ? (() => {
                        const ms =
                          Number(game.first_release_date) *
                          (Number(game.first_release_date) < 10000000000 ? 1000 : 1);
                        const d = new Date(ms);
                        const today = new Date();
                        return (
                          d.getFullYear() === today.getFullYear() &&
                          d.getMonth() === today.getMonth() &&
                          d.getDate() === today.getDate()
                        );
                      })()
                    : false;
                  const relDate = game.first_release_date
                    ? new Date(
                        Number(game.first_release_date) *
                          (Number(game.first_release_date) < 10000000000 ? 1000 : 1)
                      ).toLocaleDateString('sv-SE', {
                        month: 'short',
                        day: 'numeric',
                      })
                    : (game.release_year ? String(game.release_year) : null);

                  return (
                    <div
                      key={game.id}
                      className="flex-shrink-0 w-36 sm:w-44 flex flex-col group bg-zinc-900/60 border border-zinc-800/80 rounded-2xl overflow-hidden p-2.5 transition hover:border-zinc-700 relative"
                    >
                      {/* Datum-badge */}
                      {(isToday || relDate) && (
                        <div
                          className={`absolute top-4 left-4 z-10 px-2 py-0.5 rounded-md text-[10px] font-black shadow-md backdrop-blur-md capitalize ${
                            isToday
                              ? 'bg-emerald-600 text-white border border-emerald-400 animate-pulse'
                              : 'bg-red-600/90 text-white border border-red-400/40'
                          }`}
                        >
                          {isToday ? 'Idag' : relDate}
                        </div>
                      )}

                      <div
                        onClick={() => onSelectGame(game)}
                        className="w-full aspect-[3/4] rounded-xl overflow-hidden bg-zinc-950 mb-2 relative cursor-pointer"
                      >
                        {game.cover_url ? (
                          <img
                            src={game.cover_url}
                            alt={game.title}
                            className="w-full h-full object-cover group-hover:scale-105 transition duration-300"
                            loading="lazy"
                          />
                        ) : (
                          <div className="w-full h-full flex items-center justify-center">
                            <Gamepad className="w-6 h-6 text-zinc-600" />
                          </div>
                        )}
                      </div>

                      <h4
                        onClick={() => onSelectGame(game)}
                        className="text-xs font-bold text-zinc-100 line-clamp-2 leading-snug min-h-[2rem] cursor-pointer hover:text-red-400 transition"
                      >
                        {game.title}
                      </h4>

                      <span className="text-[10px] text-zinc-400 mt-0.5 truncate">
                        {getPrimaryGenre(game.genres)} • {game.platforms?.[0] || 'Kommande'}
                      </span>

                      <button
                        onClick={() =>
                          onAddGame({ ...game, status: 'notStarted', is_owned: false, is_backlog: false })
                        }
                        disabled={inLibrary}
                        className={`mt-2.5 w-full py-1.5 rounded-xl text-[11px] font-semibold flex items-center justify-center gap-1 transition ${
                          inLibrary
                            ? 'bg-zinc-800/60 text-zinc-400 border border-zinc-700/50 cursor-default'
                            : 'bg-zinc-800 hover:bg-brand-red text-zinc-200 hover:text-white border border-zinc-700 hover:border-brand-red cursor-pointer'
                        }`}
                      >
                        {inLibrary ? (
                          <>
                            {inWishlist ? (
                              <Heart className="w-3 h-3 fill-current text-brand-red" />
                            ) : (
                              <Check className="w-3 h-3 text-emerald-400" />
                            )}
                            <span>{inWishlist ? 'På önskelistan' : 'I samlingen'}</span>
                          </>
                        ) : (
                          <>
                            <Bookmark className="w-3 h-3 text-amber-400" />
                            <span>Önskelista</span>
                          </>
                        )}
                      </button>
                    </div>
                  );
                })}
              </div>
            ) : (
              <div className="py-6 px-4 rounded-2xl bg-zinc-900/40 border border-dashed border-zinc-800 text-center flex flex-col items-center justify-center gap-2">
                <p className="text-xs text-zinc-400">Inga kommande spelsläpp kunde hämtas just nu.</p>
                <button
                  onClick={() => {
                    setIsLoadingDiscover(true);
                    fetch('/api/games/discover?category=upcoming&limit=20')
                      .then((r) => r.json())
                      .then((d) => {
                        if (Array.isArray(d.results)) setUpcomingGames(d.results);
                      })
                      .finally(() => setIsLoadingDiscover(false));
                  }}
                  className="px-3 py-1.5 rounded-xl bg-zinc-800 text-xs font-semibold text-white hover:bg-zinc-700 transition"
                >
                  Försök igen
                </button>
              </div>
            )}
          </div>

          {/* 5. 🔥 Trendar just nu */}
          <div className="space-y-3">
            <div className="flex items-center justify-between gap-3">
              <div className="flex items-center gap-2">
                <Flame className="w-4 h-4 text-brand-red" />
                <h3 className="text-sm sm:text-base font-bold text-white tracking-tight">Trendar just nu</h3>
              </div>

              <select
                value={trendingSort}
                onChange={(e) => setTrendingSort(e.target.value as any)}
                className="bg-zinc-900 border border-zinc-800 text-zinc-300 text-[11px] sm:text-xs rounded-xl px-2.5 py-1 focus:outline-none focus:border-brand-red cursor-pointer"
              >
                <option value="popularity">Mest omtalade</option>
                <option value="rating">Högst betyg</option>
                <option value="newest">Senast släppta</option>
              </select>
            </div>

            {isLoadingDiscover && trendingGames.length === 0 ? (
              <div className="flex gap-3.5 overflow-x-auto pb-2.5 scrollbar-none">
                {[1, 2, 3, 4, 5, 6].map((i) => (
                  <div
                    key={i}
                    className="flex-shrink-0 w-32 sm:w-40 h-52 rounded-2xl bg-zinc-900/60 border border-zinc-800/80 animate-pulse flex flex-col p-2"
                  >
                    <div className="w-full aspect-[3/4] rounded-xl bg-zinc-800/60 mb-2" />
                    <div className="w-3/4 h-3 bg-zinc-800 rounded mb-1.5" />
                    <div className="w-1/2 h-2.5 bg-zinc-800/60 rounded" />
                  </div>
                ))}
              </div>
            ) : trendingGames.length > 0 ? (
              <div className="flex gap-3.5 overflow-x-auto pb-2.5 scrollbar-thin scrollbar-thumb-zinc-800">
              {trendingGames.map((game, idx) => {
                const inLibrary = isGameInLibrary(game.igdb_id, game.title);
                return (
                  <div
                    key={game.id}
                    className="flex-shrink-0 w-32 sm:w-40 flex flex-col group bg-zinc-900/60 border border-zinc-800/80 rounded-2xl overflow-hidden p-2 transition hover:border-zinc-700 relative"
                  >
                    {/* Rank Badge */}
                    <div
                      className={`absolute top-3.5 left-3.5 z-10 px-1.5 py-0.5 rounded-md text-[9px] font-black shadow-md backdrop-blur-md border ${
                        idx === 0
                          ? 'bg-amber-400/90 text-zinc-950 border-amber-300'
                          : idx === 1
                          ? 'bg-zinc-300/90 text-zinc-950 border-white'
                          : idx === 2
                          ? 'bg-amber-700/90 text-white border-amber-500'
                          : 'bg-black/80 text-zinc-300 border-zinc-700'
                      }`}
                    >
                      #{idx + 1}
                    </div>

                    <div
                      onClick={() => onSelectGame(game)}
                      className="w-full aspect-[3/4] rounded-xl overflow-hidden bg-zinc-950 mb-2 relative cursor-pointer"
                    >
                      {game.cover_url ? (
                        <img
                          src={game.cover_url}
                          alt={game.title}
                          className="w-full h-full object-cover group-hover:scale-105 transition duration-300"
                          loading="lazy"
                        />
                      ) : (
                        <div className="w-full h-full flex items-center justify-center">
                          <Gamepad className="w-6 h-6 text-zinc-600" />
                        </div>
                      )}
                      {(() => {
                        const r = normalizeIgdbRating(game.igdb_rating);
                        return r ? (
                          <div className="absolute top-1.5 right-1.5 px-1.5 py-0.5 rounded bg-black/80 backdrop-blur-md text-[10px] font-bold text-amber-300 border border-amber-500/30">
                            ⭐ {r}
                          </div>
                        ) : null;
                      })()}
                    </div>

                    <h4
                      onClick={() => onSelectGame(game)}
                      className="text-xs font-bold text-zinc-100 line-clamp-2 leading-snug min-h-[2rem] cursor-pointer hover:text-red-400 transition"
                    >
                      {game.title}
                    </h4>

                    {game.badge_text && (
                      <div className={`my-1 px-1.5 py-0.5 rounded text-[9px] sm:text-[10px] font-extrabold border truncate text-center shadow-sm ${getBadgeStyle(game.badge_text)}`}>
                        {game.badge_text}
                      </div>
                    )}

                    <span className="text-[10px] text-zinc-400 mt-0.5 truncate block">
                      {game.release_year ? `${game.release_year} • ` : ''}
                      {getPrimaryGenre(game.genres)}
                    </span>

                    <button
                      onClick={() =>
                        onAddGame({ ...game, is_owned: true, is_backlog: true, status: 'notStarted' })
                      }
                      disabled={inLibrary}
                      className={`mt-2 w-full py-1 rounded-xl text-[11px] font-semibold flex items-center justify-center gap-1 transition ${
                        inLibrary
                          ? 'bg-zinc-800/60 text-zinc-400 border border-zinc-700/50 cursor-default'
                          : 'bg-zinc-800 hover:bg-brand-red text-zinc-200 hover:text-white border border-zinc-700 hover:border-brand-red'
                      }`}
                    >
                      {inLibrary ? (
                        <>
                          <Check className="w-3 h-3 text-emerald-400" />
                          <span>Sparat</span>
                        </>
                      ) : (
                        <>
                          <Plus className="w-3 h-3" />
                          <span>Lägg till</span>
                        </>
                      )}
                    </button>
                  </div>
                );
              })}
            </div>
          ) : (
            <div className="py-6 px-4 rounded-2xl bg-zinc-900/40 border border-dashed border-zinc-800 text-center flex flex-col items-center justify-center gap-2">
              <p className="text-xs text-zinc-400">Inga trendande spel kunde hämtas just nu.</p>
              <button
                onClick={() => {
                  setIsLoadingDiscover(true);
                  fetch(`/api/games/discover?category=trending&sort=${trendingSort}&era=recent&limit=25`)
                    .then((r) => r.json())
                    .then((d) => {
                      if (Array.isArray(d.results)) setTrendingGames(d.results);
                    })
                    .finally(() => setIsLoadingDiscover(false));
                }}
                className="px-3 py-1.5 rounded-xl bg-zinc-800 text-xs font-semibold text-white hover:bg-zinc-700 transition"
              >
                Försök igen
              </button>
            </div>
          )}
        </div>

          {/* 5. 🎮 Utforska per genre */}
          <div className="space-y-3.5 pt-2">
            <div className="flex items-center justify-between gap-3">
              <div className="flex items-center gap-2">
                <Layers className="w-4 h-4 text-brand-red" />
                <h3 className="text-sm sm:text-base font-bold text-white tracking-tight">Utforska per genre</h3>
              </div>

              <select
                value={genreSort}
                onChange={(e) => setGenreSort(e.target.value as any)}
                className="bg-zinc-900 border border-zinc-800 text-zinc-300 text-[11px] sm:text-xs rounded-xl px-2.5 py-1 focus:outline-none focus:border-brand-red cursor-pointer"
              >
                <option value="popularity">Mest populära</option>
                <option value="rating">Högst betyg</option>
                <option value="newest">Nyast först</option>
              </select>
            </div>

            {/* Enkel horisontell rad med Genrer */}
            <div className="flex gap-2 overflow-x-auto pb-1.5 scrollbar-none">
              {GENRE_LIST.map((g) => (
                <button
                  key={g.id}
                  onClick={() => setSelectedGenre(g.id)}
                  className={`px-3.5 py-1.5 rounded-xl text-xs font-semibold whitespace-nowrap transition ${
                    selectedGenre === g.id
                      ? 'bg-brand-red text-white shadow-sm'
                      : 'bg-zinc-900 text-zinc-400 hover:text-zinc-200 border border-zinc-800'
                  }`}
                >
                  {g.label}
                </button>
              ))}
            </div>

            {/* Spelrutnät för vald genre */}
            {isLoadingGenre && genreGames.length === 0 ? (
              <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-3 sm:gap-4">
                {[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12].map((i) => (
                  <div
                    key={i}
                    className="h-56 rounded-2xl bg-zinc-900/60 border border-zinc-800/80 animate-pulse flex flex-col p-2.5"
                  >
                    <div className="w-full aspect-[3/4] rounded-xl bg-zinc-800/60 mb-2" />
                    <div className="w-3/4 h-3 bg-zinc-800 rounded mb-1.5" />
                    <div className="w-1/2 h-2.5 bg-zinc-800/60 rounded" />
                  </div>
                ))}
              </div>
            ) : genreGames.length === 0 ? (
              <div className="text-center py-10 text-zinc-500 border border-dashed border-zinc-800 rounded-2xl space-y-2">
                <p className="text-xs">Inga spel hittades inom {currentGenreLabel}.</p>
                <button
                  onClick={() => {
                    setIsLoadingGenre(true);
                    fetch(
                      `/api/games/discover?genre=${encodeURIComponent(selectedGenre)}&sort=${genreSort}&era=recent&limit=12`
                    )
                      .then((r) => r.json())
                      .then((d) => {
                        if (d.results) setGenreGames(d.results);
                      })
                      .finally(() => setIsLoadingGenre(false));
                  }}
                  className="px-3 py-1.5 rounded-xl bg-zinc-800 text-xs text-white font-semibold hover:bg-zinc-700 transition cursor-pointer"
                >
                  Försök igen
                </button>
              </div>
            ) : (
              <div className="space-y-4">
                <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-3 sm:gap-4">
                  {genreGames.map((game) => {
                    const inLibrary = isGameInLibrary(game.igdb_id, game.title);
                    return (
                      <div
                        key={game.id}
                        className="flex flex-col group bg-zinc-900/60 border border-zinc-800/80 rounded-2xl overflow-hidden p-2.5 transition hover:border-zinc-700 shadow-sm"
                      >
                        <div
                          onClick={() => onSelectGame(game)}
                          className="w-full aspect-[3/4] rounded-xl overflow-hidden bg-zinc-950 mb-2 relative cursor-pointer"
                        >
                          {game.cover_url ? (
                            <img
                              src={game.cover_url}
                              alt={game.title}
                              className="w-full h-full object-cover group-hover:scale-105 transition duration-300"
                              loading="lazy"
                            />
                          ) : (
                            <div className="w-full h-full flex items-center justify-center">
                              <Gamepad className="w-6 h-6 text-zinc-600" />
                            </div>
                          )}
                          {(() => {
                            const r = normalizeIgdbRating(game.igdb_rating);
                            return r ? (
                              <div className="absolute top-1.5 right-1.5 px-1.5 py-0.5 rounded bg-black/80 backdrop-blur-md text-[10px] font-bold text-amber-300 border border-amber-500/30">
                                ⭐ {r}
                              </div>
                            ) : null;
                          })()}
                        </div>

                        <h4
                          onClick={() => onSelectGame(game)}
                          className="text-xs sm:text-sm font-bold text-zinc-100 line-clamp-2 leading-snug min-h-[2.25rem] cursor-pointer hover:text-red-400 transition"
                        >
                          {game.title}
                        </h4>

                        <span className="text-[10px] text-zinc-400 mt-0.5 truncate">
                          {game.release_year ? `${game.release_year} • ` : ''}
                          {getPrimaryGenre(game.genres, selectedGenre)}
                        </span>

                        <button
                          onClick={() =>
                            onAddGame({ ...game, is_owned: true, is_backlog: true, status: 'notStarted' })
                          }
                          disabled={inLibrary}
                          className={`mt-2 w-full py-1.5 rounded-xl text-[11px] font-semibold flex items-center justify-center gap-1 transition ${
                            inLibrary
                              ? 'bg-zinc-800/60 text-zinc-400 border border-zinc-700/50 cursor-default'
                              : 'bg-zinc-800 hover:bg-brand-red text-zinc-200 hover:text-white border border-zinc-700 hover:border-brand-red'
                          }`}
                        >
                          {inLibrary ? (
                            <>
                              <Check className="w-3 h-3 text-emerald-400" />
                              <span>Sparat</span>
                            </>
                          ) : (
                            <>
                              <Plus className="w-3 h-3" />
                              <span>Lägg till</span>
                            </>
                          )}
                        </button>
                      </div>
                    );
                  })}
                </div>

                {/* Sömlös "Visa fler"-knapp med egen laddningsindikator */}
                {genreLimit < 48 && (
                  <div className="flex justify-center pt-2">
                    <button
                      onClick={handleLoadMoreGenre}
                      disabled={isLoadingMoreGenre}
                      className="px-5 py-2 rounded-xl bg-zinc-900 hover:bg-zinc-800 border border-zinc-800 text-xs font-semibold text-zinc-300 hover:text-white transition shadow-sm flex items-center gap-1.5 disabled:opacity-50"
                    >
                      {isLoadingMoreGenre ? (
                        <>
                          <RefreshCw className="w-3.5 h-3.5 animate-spin text-brand-red" />
                          <span>Laddar fler {currentGenreLabel}-spel...</span>
                        </>
                      ) : (
                        <>
                          <span>Visa fler {currentGenreLabel}-spel</span>
                          <ChevronDown className="w-3.5 h-3.5 text-zinc-500" />
                        </>
                      )}
                    </button>
                  </div>
                )}
              </div>
            )}
          </div>

          {/* 6. 🎲 Smart Spelsnurra (Inspiration & Slumpare när man har aktiva spel) */}
          {currentlyPlaying.length > 0 && (
            <div
              id="roulette-section"
              className="relative overflow-hidden rounded-3xl bg-gradient-to-br from-zinc-900/90 via-zinc-950/95 to-black border border-zinc-800/80 p-5 sm:p-7 shadow-xl"
            >
              <div className="relative z-10 flex flex-col md:flex-row items-center justify-between gap-6">
                <div className="max-w-md text-center md:text-left">
                  <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-brand-red/10 border border-brand-red/30 text-rose-300 text-xs font-bold uppercase tracking-wider mb-2.5">
                    <Dices className="w-3.5 h-3.5 text-brand-red" />
                    <span>Smart Spelsnurra</span>
                  </div>
                  <h3 className="text-xl sm:text-2xl font-extrabold text-white tracking-tight">
                    Behöver du inspiration?
                  </h3>
                  <p className="text-xs sm:text-sm text-zinc-400 mt-1 leading-relaxed">
                    Låt slumpen välja vad du ska spela härnäst bland dina ospelade spel i backloggen eller upptäck nya rekommendationer.
                  </p>

                  <div className="flex flex-wrap items-center justify-center md:justify-start gap-2 mt-3.5">
                    <button
                      onClick={() => setRouletteMode('library')}
                      className={`px-3 py-1.5 rounded-xl text-xs font-semibold border transition cursor-pointer ${
                        rouletteMode === 'library'
                          ? 'bg-white text-zinc-950 border-white font-bold'
                          : 'bg-zinc-900 border-zinc-800 text-zinc-400 hover:text-zinc-200'
                      }`}
                    >
                      Mina spel ({games.length})
                    </button>
                    <button
                      onClick={() => setRouletteMode('igdb')}
                      className={`px-3 py-1.5 rounded-xl text-xs font-semibold border transition cursor-pointer ${
                        rouletteMode === 'igdb'
                          ? 'bg-white text-zinc-950 border-white font-bold'
                          : 'bg-zinc-900 border-zinc-800 text-zinc-400 hover:text-zinc-200'
                      }`}
                    >
                      Upptäck från IGDB
                    </button>
                  </div>
                </div>

                <div className="flex flex-col items-center gap-3.5 w-full sm:w-auto">
                  {winnerGame ? (
                    <div
                      onClick={() => onSelectGame(winnerGame)}
                      className="flex items-center gap-3.5 p-2.5 bg-zinc-900/90 border border-zinc-700/80 rounded-2xl cursor-pointer hover:border-zinc-500 transition shadow-lg w-full max-w-sm group"
                    >
                      <div className="w-14 h-18 rounded-xl overflow-hidden bg-zinc-950 flex-shrink-0 relative border border-zinc-800">
                        {winnerGame.cover_url ? (
                          <img
                            src={winnerGame.cover_url}
                            alt={winnerGame.title}
                            className="w-full h-full object-cover group-hover:scale-105 transition"
                          />
                        ) : (
                          <div className="w-full h-full flex items-center justify-center">
                            <Gamepad className="w-6 h-6 text-zinc-600" />
                          </div>
                        )}
                      </div>
                      <div className="flex-1 min-w-0">
                        <span className="text-[10px] uppercase font-bold text-amber-400 tracking-wider block">
                          Utvalt spel!
                        </span>
                        <h4 className="text-sm font-bold text-white truncate group-hover:text-red-400 transition">
                          {winnerGame.title}
                        </h4>
                        <p className="text-[11px] text-zinc-400 mt-0.5">
                          {winnerGame.release_year ? `${winnerGame.release_year} • ` : ''}
                          {winnerGame.genres?.[0] || 'Spel'}
                        </p>
                      </div>
                      <ArrowRight className="w-4 h-4 text-zinc-400 group-hover:text-white transition mr-1" />
                    </div>
                  ) : (
                    <div className="w-full max-w-sm h-20 border border-dashed border-zinc-800 rounded-2xl flex items-center justify-center text-zinc-500 text-xs px-4 text-center">
                      Klicka nedan för att slumpa fram ett spel
                    </div>
                  )}

                  <button
                    onClick={handleSpinRoulette}
                    disabled={isSpinning || (rouletteMode === 'library' && games.length === 0)}
                    className="w-full sm:w-auto px-7 py-2.5 bg-gradient-to-r from-brand-red to-rose-600 hover:from-brand-redPressed hover:to-rose-700 disabled:opacity-50 text-white font-bold text-xs sm:text-sm rounded-xl shadow-lg transition flex items-center justify-center gap-2 cursor-pointer"
                  >
                    <Dices className={`w-4 h-4 ${isSpinning ? 'animate-spin' : ''}`} />
                    <span>{isSpinning ? 'Snurrar hjulet...' : '🎲 Snurra fram ett spel!'}</span>
                  </button>
                </div>
              </div>
            </div>
          )}
        </div>
      ) : activeTab === 'calendar' ? (
        /* --- DEDIKERAD RELEASEKALENDER (Motsvarande iOS UpcomingReleasesView.swift) --- */
        <div className="space-y-6 animate-in fade-in duration-200">
          {/* Kalender Header */}
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-gradient-to-r from-zinc-900/90 via-zinc-900/60 to-zinc-950 border border-zinc-800/80 rounded-3xl p-5 sm:p-6 shadow-lg">
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 rounded-2xl bg-brand-red/10 border border-brand-red/20 flex items-center justify-center text-brand-red flex-shrink-0 shadow-inner">
                <Calendar className="w-6 h-6" />
              </div>
              <div>
                <h2 className="text-lg sm:text-2xl font-black text-white tracking-tight">
                  Releasekalender
                </h2>
                <p className="text-xs sm:text-sm text-zinc-400 mt-0.5">
                  {currentMonthOption.isMostHyped
                    ? 'De mest efterlängtade och hypade kommande spelsläppen'
                    : `Spelsläpp under ${currentMonthOption.title}`}
                </p>
              </div>
            </div>

            <div className="flex items-center gap-2">
              <button
                onClick={() => loadCalendarGames()}
                disabled={isLoadingCalendar}
                className="flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-zinc-800 hover:bg-zinc-700 text-xs font-semibold text-zinc-200 transition disabled:opacity-50 cursor-pointer shadow-sm"
              >
                <RefreshCw className={`w-3.5 h-3.5 ${isLoadingCalendar ? 'animate-spin text-brand-red' : ''}`} />
                <span>Uppdatera</span>
              </button>
            </div>
          </div>

          {/* Horisontell Månadsväljare (med "🔥 Mest hypade" först) */}
          <div className="flex items-center gap-2 overflow-x-auto pb-1 scrollbar-none">
            {monthOptions.map((opt) => (
              <button
                key={opt.id}
                onClick={() => setSelectedMonthID(opt.id)}
                className={`px-4 py-2 rounded-2xl text-xs sm:text-sm font-bold whitespace-nowrap transition cursor-pointer flex items-center gap-1.5 ${
                  selectedMonthID === opt.id
                    ? 'bg-brand-red text-white shadow-md shadow-brand-red/25'
                    : 'bg-zinc-900 border border-zinc-800 text-zinc-400 hover:text-zinc-200 hover:border-zinc-700'
                }`}
              >
                <span>{opt.title}</span>
              </button>
            ))}
          </div>

          {/* Plattformsväljare + Filter Toggle */}
          <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-3 pt-1">
            <div className="flex items-center gap-1.5 overflow-x-auto pb-1 scrollbar-none">
              {CALENDAR_PLATFORMS.map((p) => (
                <button
                  key={p.id}
                  onClick={() => setSelectedCalendarPlatform(p.id)}
                  className={`px-3 py-1.5 rounded-xl text-xs font-semibold whitespace-nowrap transition cursor-pointer ${
                    selectedCalendarPlatform === p.id
                      ? 'bg-white text-zinc-950 font-bold shadow-sm'
                      : 'bg-zinc-900 border border-zinc-800 text-zinc-400 hover:text-zinc-200'
                  }`}
                >
                  {p.label}
                </button>
              ))}
            </div>

            {!currentMonthOption.isMostHyped && (
              <div className="flex items-center gap-2 self-end sm:self-auto">
                <button
                  onClick={() => setShowAllInMonth(!showAllInMonth)}
                  className={`px-3 py-1.5 rounded-xl text-xs font-semibold border transition cursor-pointer ${
                    showAllInMonth
                      ? 'bg-zinc-900 border-zinc-800 text-zinc-300'
                      : 'bg-amber-500/10 border-amber-500/30 text-amber-300 font-bold'
                  }`}
                >
                  {showAllInMonth ? 'Visar alla släpp i månaden' : 'Endast större släpp'}
                </button>
              </div>
            )}
          </div>

          {/* Kalender Innehåll */}
          {isLoadingCalendar && calendarGames.length === 0 ? (
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4 pt-2">
              {[1, 2, 3, 4, 5, 6, 7, 8].map((i) => (
                <div
                  key={i}
                  className="h-36 rounded-2xl bg-zinc-900/60 border border-zinc-800 animate-pulse flex p-3 gap-3"
                >
                  <div className="w-20 h-full rounded-xl bg-zinc-800 flex-shrink-0" />
                  <div className="flex-1 space-y-2 py-1">
                    <div className="w-3/4 h-4 bg-zinc-800 rounded" />
                    <div className="w-1/2 h-3 bg-zinc-800/60 rounded" />
                    <div className="w-1/3 h-3 bg-zinc-800/40 rounded" />
                  </div>
                </div>
              ))}
            </div>
          ) : displayedCalendarGames.length === 0 ? (
            <div className="text-center py-20 text-zinc-500 border border-dashed border-zinc-800 rounded-3xl p-8 space-y-3">
              <Calendar className="w-10 h-10 mx-auto opacity-40 text-brand-red" />
              <p className="text-sm font-semibold text-zinc-300">
                Inga kommande spelsläpp hittades för det valda filtret.
              </p>
              <p className="text-xs text-zinc-500">
                Prova att byta plattform eller välja en annan månad.
              </p>
            </div>
          ) : currentMonthOption.isMostHyped ? (
            /* --- Mest Hypade Spel Rutnät --- */
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4 pt-1">
              {displayedCalendarGames.map((game, idx) => {
                const matching = getMatchingGame(game.igdb_id, game.title);
                const inLibrary = Boolean(matching);
                const inWishlist = Boolean(matching && matching.is_owned === false);
                const isToday = game.first_release_date
                  ? (() => {
                      const ms =
                        Number(game.first_release_date) *
                        (Number(game.first_release_date) < 10000000000 ? 1000 : 1);
                      const d = new Date(ms);
                      const today = new Date();
                      return (
                        d.getFullYear() === today.getFullYear() &&
                        d.getMonth() === today.getMonth() &&
                        d.getDate() === today.getDate()
                      );
                    })()
                  : false;
                const relDate = game.first_release_date
                  ? new Date(
                      Number(game.first_release_date) *
                        (Number(game.first_release_date) < 10000000000 ? 1000 : 1)
                    ).toLocaleDateString('sv-SE', {
                      year: 'numeric',
                      month: 'short',
                      day: 'numeric',
                    })
                  : game.release_year
                  ? String(game.release_year)
                  : 'Kommande';

                return (
                  <div
                    key={game.id}
                    className="flex flex-col justify-between bg-zinc-900/60 border border-zinc-800/80 hover:border-zinc-700 rounded-2xl p-3 group transition shadow-md relative"
                  >
                    <div className="flex gap-3">
                      {/* Omslag */}
                      <div
                        onClick={() => onSelectGame(game)}
                        className="w-20 sm:w-24 aspect-[3/4] rounded-xl overflow-hidden bg-zinc-950 flex-shrink-0 relative cursor-pointer border border-zinc-800 shadow"
                      >
                        {game.cover_url ? (
                          <img
                            src={game.cover_url}
                            alt={game.title}
                            className="w-full h-full object-cover group-hover:scale-105 transition duration-300"
                            loading="lazy"
                          />
                        ) : (
                          <div className="w-full h-full flex items-center justify-center">
                            <Gamepad className="w-6 h-6 text-zinc-600" />
                          </div>
                        )}
                        <div className="absolute top-1.5 left-1.5 px-1.5 py-0.5 rounded text-[9px] font-black bg-black/80 text-amber-400 border border-amber-500/30">
                          #{idx + 1}
                        </div>
                      </div>

                      {/* Info */}
                      <div className="flex-1 min-w-0 flex flex-col justify-between">
                        <div>
                          {/* Hype badge */}
                          {game.hypes ? (
                            <div className="inline-flex items-center gap-1 text-[10px] font-black text-rose-400 mb-1">
                              <Flame className="w-3 h-3 text-brand-red fill-current" />
                              <span>{game.hypes} hypes</span>
                            </div>
                          ) : null}

                          <h4
                            onClick={() => onSelectGame(game)}
                            className="text-sm font-bold text-white group-hover:text-red-400 transition cursor-pointer line-clamp-2 leading-snug"
                          >
                            {game.title}
                          </h4>

                          <p className="text-[11px] text-zinc-400 mt-1 truncate">
                            {game.developers?.[0] || getPrimaryGenre(game.genres)}
                          </p>
                        </div>

                        <div className="mt-2">
                          <span
                            className={`text-[11px] font-bold flex items-center gap-1 ${
                              isToday ? 'text-emerald-400 font-extrabold' : 'text-zinc-300'
                            }`}
                          >
                            {isToday ? (
                              <>
                                <Sparkles className="w-3 h-3 text-emerald-400 animate-pulse" />
                                <span>Släpps idag!</span>
                              </>
                            ) : (
                              <>
                                <Calendar className="w-3 h-3 text-brand-red" />
                                <span>{relDate}</span>
                              </>
                            )}
                          </span>
                          <span className="text-[10px] text-zinc-500 truncate block mt-0.5">
                            {game.platforms?.slice(0, 3).join(', ') || 'Okänd plattform'}
                          </span>
                        </div>
                      </div>
                    </div>

                    <button
                      onClick={() =>
                        onAddGame({ ...game, status: 'notStarted', is_owned: false, is_backlog: false })
                      }
                      disabled={inLibrary}
                      className={`mt-3 w-full py-1.5 rounded-xl text-xs font-semibold flex items-center justify-center gap-1.5 transition cursor-pointer ${
                        inLibrary
                          ? 'bg-zinc-800/60 text-zinc-400 border border-zinc-700/50 cursor-default'
                          : 'bg-zinc-800 hover:bg-brand-red text-zinc-200 hover:text-white border border-zinc-700 hover:border-brand-red'
                      }`}
                    >
                      {inLibrary ? (
                        <>
                          {inWishlist ? (
                            <Heart className="w-3.5 h-3.5 fill-current text-brand-red" />
                          ) : (
                            <Check className="w-3.5 h-3.5 text-emerald-400" />
                          )}
                          <span>{inWishlist ? 'På önskelistan' : 'I biblioteket'}</span>
                        </>
                      ) : (
                        <>
                          <Bookmark className="w-3.5 h-3.5 text-amber-400" />
                          <span>Lägg till i önskelista</span>
                        </>
                      )}
                    </button>
                  </div>
                );
              })}
            </div>
          ) : (
            /* --- Månadsvy Grupperad per Datum (Tidslinje med nedräkningar) --- */
            <div className="space-y-6 pt-1">
              {groupedCalendarReleases.map((group) => (
                <div key={group.dateKey} className="space-y-3">
                  {/* Datumrubrik med Countdown-badge */}
                  <div className="flex items-center justify-between border-b border-zinc-800/80 pb-2">
                    <div className="flex items-center gap-2">
                      <Calendar className="w-4 h-4 text-brand-red" />
                      <h3 className="text-sm sm:text-base font-bold text-white">
                        {group.displayDate}
                      </h3>
                    </div>

                    {group.countdown && (
                      <span
                        className={`px-2.5 py-0.5 rounded-full text-xs font-bold border ${
                          group.countdown === 'Idag'
                            ? 'bg-emerald-500/20 text-emerald-300 border-emerald-500/40 animate-pulse'
                            : group.countdown === 'Imorgon'
                            ? 'bg-amber-500/20 text-amber-300 border-amber-500/40'
                            : 'bg-zinc-800/80 text-zinc-300 border-zinc-700'
                        }`}
                      >
                        {group.countdown}
                      </span>
                    )}
                  </div>

                  {/* Spelkort för detta datum */}
                  <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3.5">
                    {group.games.map((game) => {
                      const matching = getMatchingGame(game.igdb_id, game.title);
                      const inLibrary = Boolean(matching);
                      const inWishlist = Boolean(matching && matching.is_owned === false);

                      return (
                        <div
                          key={game.id}
                          className="flex items-center gap-3.5 p-3 rounded-2xl bg-zinc-900/60 border border-zinc-800/80 hover:border-zinc-700 group transition shadow-sm"
                        >
                          {/* Omslagsbild */}
                          <div
                            onClick={() => onSelectGame(game)}
                            className="w-14 h-20 rounded-xl overflow-hidden bg-zinc-950 flex-shrink-0 cursor-pointer border border-zinc-800 shadow relative"
                          >
                            {game.cover_url ? (
                              <img
                                src={game.cover_url}
                                alt={game.title}
                                className="w-full h-full object-cover group-hover:scale-105 transition duration-300"
                                loading="lazy"
                              />
                            ) : (
                              <div className="w-full h-full flex items-center justify-center">
                                <Gamepad className="w-6 h-6 text-zinc-600" />
                              </div>
                            )}
                          </div>

                          {/* Spelinfo */}
                          <div className="flex-1 min-w-0">
                            <h4
                              onClick={() => onSelectGame(game)}
                              className="text-xs sm:text-sm font-bold text-white line-clamp-2 leading-snug group-hover:text-red-400 transition cursor-pointer"
                            >
                              {game.title}
                            </h4>

                            <p className="text-[11px] text-zinc-400 mt-0.5 truncate">
                              {game.developers?.[0] || getPrimaryGenre(game.genres)}
                            </p>

                            <div className="flex items-center gap-1.5 mt-1 text-[10px] text-zinc-400">
                              <span className="font-semibold text-zinc-300 truncate">
                                {game.platforms?.slice(0, 2).join(', ') || 'Multi'}
                              </span>
                              {game.hypes && game.hypes > 0 ? (
                                <>
                                  <span>•</span>
                                  <span className="text-amber-400 font-bold">
                                    🔥 {game.hypes}
                                  </span>
                                </>
                              ) : null}
                            </div>
                          </div>

                          {/* Snabbknapp för önskelista */}
                          <button
                            onClick={() =>
                              onAddGame({ ...game, status: 'notStarted', is_owned: false, is_backlog: false })
                            }
                            disabled={inLibrary}
                            title={inLibrary ? (inWishlist ? 'På önskelistan' : 'I biblioteket') : 'Lägg till i önskelista'}
                            className={`p-2.5 rounded-xl border transition cursor-pointer flex-shrink-0 ${
                              inLibrary
                                ? 'bg-zinc-800/40 border-zinc-700/50 cursor-default'
                                : 'bg-zinc-800 hover:bg-brand-red text-zinc-300 hover:text-white border-zinc-700'
                            }`}
                          >
                            {inLibrary ? (
                              inWishlist ? (
                                <Heart className="w-4 h-4 fill-current text-brand-red" />
                              ) : (
                                <Check className="w-4 h-4 text-emerald-400" />
                              )
                            ) : (
                              <Bookmark className="w-4 h-4 text-amber-400" />
                            )}
                          </button>
                        </div>
                      );
                    })}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      ) : (
        /* --- Avancerad Spelnyhets- & Recensionshub --- */
        <div className="space-y-6 animate-in fade-in duration-200">
          {/* Top Controls: Search, Category Tabs, Platform & Source Selectors */}
          <div className="space-y-3">
            <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-3">
              {/* Sökfält */}
              <div className="relative flex-1 max-w-md">
                <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-500" />
                <input
                  type="text"
                  value={newsSearch}
                  onChange={(e) => setNewsSearch(e.target.value)}
                  placeholder="Sök bland recensioner, speltitlar och nyheter..."
                  className="w-full bg-zinc-900 border border-zinc-800 text-zinc-100 rounded-2xl pl-10 pr-4 py-2.5 text-xs sm:text-sm focus:outline-none focus:border-red-500 shadow-inner"
                />
              </div>

              {/* Plattformar & Källor Dropdowns */}
              <div className="flex items-center gap-2">
                <select
                  value={selectedNewsPlatform}
                  onChange={(e) => setSelectedNewsPlatform(e.target.value)}
                  className="bg-zinc-900 border border-zinc-800 text-zinc-300 text-xs rounded-xl px-3 py-2 focus:outline-none focus:border-brand-red cursor-pointer"
                >
                  {PLATFORMS.map((p) => (
                    <option key={p} value={p}>
                      {p}
                    </option>
                  ))}
                </select>

                <select
                  value={selectedNewsSource}
                  onChange={(e) => setSelectedNewsSource(e.target.value)}
                  className="bg-zinc-900 border border-zinc-800 text-zinc-300 text-xs rounded-xl px-3 py-2 focus:outline-none focus:border-brand-red cursor-pointer"
                >
                  {newsSources.map((s) => (
                    <option key={s} value={s}>
                      {s}
                    </option>
                  ))}
                </select>

                {/* Tidsfilter Dropdown */}
                <select
                  value={selectedNewsTimeRange}
                  onChange={(e) => setSelectedNewsTimeRange(e.target.value as any)}
                  className="bg-zinc-900 border border-zinc-800 text-zinc-300 text-xs rounded-xl px-3 py-2 focus:outline-none focus:border-brand-red cursor-pointer"
                  title="Välj tidsintervall"
                >
                  <option value="all">Alla tider</option>
                  <option value="24h">Senaste 24h</option>
                  <option value="7d">Senaste veckan</option>
                  <option value="30d">Senaste månaden</option>
                  <option value="older">Äldre än 30d</option>
                </select>

                {/* Uppdatera nyheter */}
                <button
                  type="button"
                  onClick={() => handleFetchNews(true)}
                  disabled={isLoadingNews}
                  className="flex items-center gap-1.5 px-3 py-2 bg-zinc-900 hover:bg-zinc-800 text-zinc-300 hover:text-white border border-zinc-800 rounded-xl text-xs font-medium transition-colors disabled:opacity-50 cursor-pointer"
                  title="Hämta senaste nyheterna nu"
                >
                  <RefreshCw className={`w-3.5 h-3.5 ${isLoadingNews ? 'animate-spin text-red-500' : ''}`} />
                  <span className="hidden sm:inline">{isLoadingNews ? 'Hämtar...' : 'Uppdatera'}</span>
                </button>
              </div>
            </div>

            {/* Kategori-flikar (med Uppdateringar och Förhandstittar) */}
            <div className="flex items-center gap-1.5 overflow-x-auto pb-1 scrollbar-none">
              {[
                { id: 'all', label: 'Alla artiklar' },
                { id: 'reviews', label: '⭐ Recensioner' },
                { id: 'my_games', label: '🎮 Från mina spel' },
                { id: 'updates', label: '🔄 Uppdateringar' },
                { id: 'trailers', label: '🎬 Trailers & Videor' },
                { id: 'previews', label: '👁️ Förhandstittar' },
                { id: 'saved', label: `🔖 Sparade (${savedNewsIds.length})` },
              ].map((f) => (
                <button
                  key={f.id}
                  onClick={() => setSelectedNewsCategory(f.id as any)}
                  className={`px-3.5 py-1.5 sm:px-4 sm:py-2 rounded-xl text-xs font-semibold whitespace-nowrap transition cursor-pointer ${
                    selectedNewsCategory === f.id
                      ? 'bg-brand-red text-white shadow-md shadow-brand-red/20'
                      : 'bg-zinc-900 text-zinc-400 hover:text-zinc-200 border border-zinc-800'
                  }`}
                >
                  {f.label}
                </button>
              ))}
            </div>
          </div>

          {/* Trendar just nu mini-karusell i nyhetsflödet (identiskt med iOS NewsFeedView) */}
          {trendingGames.length > 0 && !newsSearch.trim() && selectedNewsCategory === 'all' && (
            <div className="p-4 rounded-3xl bg-zinc-900/40 border border-zinc-800/70 space-y-2.5 shadow-sm">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Flame className="w-4 h-4 text-brand-red" />
                  <span className="text-xs sm:text-sm font-bold text-white">Trendar just nu</span>
                </div>
                <button
                  onClick={() => setActiveTab('discover')}
                  className="text-xs text-brand-red hover:text-red-400 font-semibold transition cursor-pointer"
                >
                  Visa alla →
                </button>
              </div>

              <div className="flex gap-3 overflow-x-auto pb-1 scrollbar-thin scrollbar-thumb-zinc-800">
                {trendingGames.slice(0, 10).map((game) => (
                  <div
                    key={game.id}
                    onClick={() => onSelectGame(game)}
                    className="flex-shrink-0 w-24 sm:w-28 cursor-pointer group space-y-1.5"
                  >
                    <div className="w-full aspect-[3/4] rounded-xl overflow-hidden bg-zinc-950 border border-zinc-800 relative">
                      {game.cover_url ? (
                        <img
                          src={game.cover_url}
                          alt={game.title}
                          className="w-full h-full object-cover group-hover:scale-105 transition duration-300"
                          loading="lazy"
                        />
                      ) : (
                        <div className="w-full h-full flex items-center justify-center">
                          <Gamepad className="w-5 h-5 text-zinc-600" />
                        </div>
                      )}
                      {game.badge_text && (
                        <div className="absolute bottom-1 left-1 right-1 px-1 py-0.5 rounded text-[8px] font-black bg-black/80 text-white border border-white/20 truncate text-center">
                          {game.badge_text}
                        </div>
                      )}
                    </div>
                    <p className="text-[11px] font-bold text-zinc-200 line-clamp-2 leading-snug min-h-[2rem] group-hover:text-red-400 transition">
                      {game.title}
                    </p>
                  </div>
                ))}
              </div>
            </div>
          )}

          {isLoadingNews ? (
            <div className="flex flex-col items-center justify-center py-24 text-zinc-400 gap-3">
              <RefreshCw className="w-6 h-6 animate-spin text-brand-red" />
              <span className="text-sm font-medium">Hämtar och matchar spelnyheter & recensioner...</span>
            </div>
          ) : filteredNews.length === 0 ? (
            <div className="text-center py-20 text-zinc-500 border border-dashed border-zinc-800 rounded-3xl p-8">
              <Newspaper className="w-10 h-10 mx-auto mb-3 opacity-40 text-brand-red" />
              <p className="text-sm font-semibold text-zinc-300">Inga nyheter matchar din sökning eller filter.</p>
              <p className="text-xs text-zinc-500 mt-1">Prova att välja en annan kategori, plattform eller rensa sökningen.</p>
            </div>
          ) : (
            <div className="space-y-6">
              {/* 1. Hero / Featured Top Story */}
              {!newsSearch.trim() && filteredNews[0] && (
                <div className="relative overflow-hidden rounded-3xl bg-gradient-to-tr from-zinc-950 via-zinc-900 to-zinc-900 border border-zinc-800 group hover:border-zinc-700 transition shadow-2xl">
                  <div className="grid grid-cols-1 lg:grid-cols-12 gap-0">
                    {filteredNews[0].image && (
                      <a
                        href={filteredNews[0].link}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="lg:col-span-7 aspect-video sm:aspect-[16/9] lg:aspect-auto h-64 sm:h-80 lg:h-full relative overflow-hidden bg-black block"
                      >
                        <img
                          src={filteredNews[0].image}
                          alt={filteredNews[0].title}
                          className="w-full h-full object-cover group-hover:scale-105 transition duration-500"
                        />
                        <div className="absolute inset-0 bg-gradient-to-t from-zinc-950 via-transparent to-transparent lg:hidden" />
                      </a>
                    )}

                    <div className="lg:col-span-5 p-6 sm:p-8 flex flex-col justify-between">
                      <div>
                        <div className="flex items-center justify-between gap-2 mb-3">
                          <div className="flex items-center gap-2">
                            <span className="px-2.5 py-0.5 rounded-full text-xs font-bold bg-brand-red text-white">
                              {filteredNews[0].source}
                            </span>
                            {filteredNews[0].category && (
                              <span
                                className={`px-2.5 py-0.5 rounded-full text-xs font-semibold ${
                                  filteredNews[0].category === 'Recension'
                                    ? 'bg-amber-500/20 text-amber-300 border border-amber-500/40'
                                    : 'bg-zinc-800 text-zinc-300 border border-zinc-700'
                                }`}
                              >
                                {filteredNews[0].category}
                              </span>
                            )}
                          </div>

                          <button
                            onClick={(e) => toggleSaveArticle(e, filteredNews[0].id)}
                            className="p-1.5 rounded-xl bg-zinc-800 hover:bg-zinc-700 text-zinc-400 hover:text-white transition"
                            title="Spara artikel"
                          >
                            {savedNewsIds.includes(filteredNews[0].id) ? (
                              <BookmarkCheck className="w-4 h-4 text-emerald-400" />
                            ) : (
                              <Bookmark className="w-4 h-4" />
                            )}
                          </button>
                        </div>

                        {/* Matchat biblioteksspel badge */}
                        {(() => {
                          const matched = findMatchingLibraryGame(filteredNews[0].title);
                          if (!matched) return null;
                          return (
                            <div
                              onClick={() => onSelectGame(matched)}
                              className="inline-flex items-center gap-1.5 px-3 py-1 rounded-xl bg-emerald-500/10 border border-emerald-500/30 text-emerald-300 text-xs font-semibold mb-3 cursor-pointer hover:bg-emerald-500/20 transition"
                            >
                              <Gamepad className="w-3.5 h-3.5" />
                              <span>
                                Finns i ditt bibliotek (
                                {getStatusDisplayTitle(
                                  matched.status,
                                  isMultiplayerOrOngoing(matched)
                                )}
                                )
                              </span>
                            </div>
                          );
                        })()}

                        <a
                          href={filteredNews[0].link}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="block"
                        >
                          <h3 className="text-xl sm:text-2xl font-bold text-white leading-tight hover:text-red-400 transition">
                            {cleanArticleTitle(filteredNews[0].title)}
                          </h3>
                        </a>

                        {filteredNews[0].summary && (
                          <p className="text-xs sm:text-sm text-zinc-400 mt-3 line-clamp-3 leading-relaxed">
                            {filteredNews[0].summary}
                          </p>
                        )}
                      </div>

                      <div className="flex items-center justify-between pt-6 mt-4 border-t border-zinc-800/80">
                        <span className="text-xs text-zinc-500">
                          {new Date(filteredNews[0].published).toLocaleDateString('sv-SE', {
                            month: 'short',
                            day: 'numeric',
                            hour: '2-digit',
                            minute: '2-digit',
                          })}
                        </span>

                        <a
                          href={filteredNews[0].link}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="flex items-center gap-1.5 text-xs font-bold text-red-400 hover:text-red-300 transition"
                        >
                          <span>Läs hela artikeln</span>
                          <ExternalLink className="w-3.5 h-3.5" />
                        </a>
                      </div>
                    </div>
                  </div>
                </div>
              )}

              {/* 2. Grid of other articles */}
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-5">
                {(newsSearch.trim() ? filteredNews : filteredNews.slice(1)).map((item) => {
                  const matchedLibraryGame = findMatchingLibraryGame(item.title);
                  const isSaved = savedNewsIds.includes(item.id);

                  return (
                    <div
                      key={item.id}
                      className="flex flex-col bg-zinc-900/60 border border-zinc-800/80 rounded-2xl overflow-hidden hover:border-zinc-700 group transition shadow-md"
                    >
                      {item.image && (
                        <a
                          href={item.link}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="aspect-video w-full overflow-hidden bg-black relative block"
                        >
                          <img
                            src={item.image}
                            alt={item.title}
                            className="w-full h-full object-cover group-hover:scale-105 transition duration-300"
                            loading="lazy"
                          />
                          <span className="absolute top-2 left-2 px-2 py-0.5 rounded-md bg-black/80 backdrop-blur-md text-[10px] font-bold text-zinc-200 border border-zinc-700/60">
                            {item.source}
                          </span>

                          {item.category === 'Recension' && (
                            <span className="absolute top-2 right-2 px-2 py-0.5 rounded-md bg-amber-500/90 text-zinc-950 font-bold text-[10px] shadow-sm">
                              ⭐ Recension
                            </span>
                          )}
                        </a>
                      )}

                      <div className="p-4 flex-1 flex flex-col justify-between">
                        <div>
                          <div className="flex items-center justify-between gap-2 mb-2 text-[11px] text-zinc-500">
                            <div className="flex items-center gap-1.5">
                              {!item.image && (
                                <span className="font-bold text-zinc-300">{item.source} •</span>
                              )}
                              <span>
                                {new Date(item.published).toLocaleDateString('sv-SE', {
                                  month: 'short',
                                  day: 'numeric',
                                })}
                              </span>
                              {item.category && (
                                <span
                                  className={`px-1.5 py-0.5 rounded text-[10px] font-semibold ${
                                    item.category === 'Recension'
                                      ? 'bg-amber-500/20 text-amber-300'
                                      : 'bg-zinc-800 text-zinc-400'
                                  }`}
                                >
                                  {item.category}
                                </span>
                              )}
                            </div>

                            <button
                              onClick={(e) => toggleSaveArticle(e, item.id)}
                              className="p-1 rounded-lg text-zinc-500 hover:text-white transition"
                              title={isSaved ? 'Ta bort bokmärke' : 'Spara artikel'}
                            >
                              {isSaved ? (
                                <BookmarkCheck className="w-3.5 h-3.5 text-emerald-400" />
                              ) : (
                                <Bookmark className="w-3.5 h-3.5" />
                              )}
                            </button>
                          </div>

                          {/* Matchat biblioteksspel pill */}
                          {matchedLibraryGame && (
                            <div
                              onClick={() => onSelectGame(matchedLibraryGame)}
                              className="inline-flex items-center gap-1 px-2 py-0.5 rounded-md bg-emerald-500/10 border border-emerald-500/30 text-emerald-300 text-[11px] font-semibold mb-2 cursor-pointer hover:bg-emerald-500/20 transition"
                            >
                              <Gamepad className="w-3 h-3" />
                              <span className="truncate">
                                I ditt bibliotek (
                                {getStatusDisplayTitle(
                                  matchedLibraryGame.status,
                                  isMultiplayerOrOngoing(matchedLibraryGame)
                                )}
                                )
                              </span>
                            </div>
                          )}

                          <a
                            href={item.link}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="block"
                          >
                            <h4 className="text-sm font-bold text-zinc-100 group-hover:text-red-400 transition leading-snug line-clamp-2">
                              {cleanArticleTitle(item.title)}
                            </h4>
                          </a>

                          {item.summary && (
                            <p className="text-xs text-zinc-400 mt-2 line-clamp-2 leading-relaxed">
                              {item.summary}
                            </p>
                          )}
                        </div>

                        <div className="flex items-center justify-between pt-3 mt-3 border-t border-zinc-800/60 text-[11px]">
                          <a
                            href={item.link}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="flex items-center gap-1 text-zinc-500 group-hover:text-red-400 font-semibold transition"
                          >
                            <span>Läs artikel</span>
                            <ExternalLink className="w-3 h-3" />
                          </a>

                          {item.platform && item.platform !== 'Multi' && (
                            <span className="text-[10px] text-zinc-500 font-medium">
                              {item.platform}
                            </span>
                          )}
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          )}
        </div>
      )}
      <GamingGoalModal
        isOpen={isGoalModalOpen}
        onClose={() => setIsGoalModalOpen(false)}
        annualGoal={userProfile?.annualGamingGoal || 12}
        onUpdateAnnualGoal={(newGoal) => {
          if (userProfile && onUpdateProfile) {
            onUpdateProfile({ ...userProfile, annualGamingGoal: newGoal });
          }
        }}
        targetGameIds={userProfile?.targetGameIDs || []}
        onToggleTargetGoal={(id) => {
          if (onToggleTargetGoal) {
            onToggleTargetGoal(id);
          }
        }}
        libraryGames={games}
        completedGamesCount={completedGamesCount}
      />
    </div>
  );
}
