'use client';

import React, { useState, useEffect, useMemo } from 'react';
import { Game, PlayStatus } from '@/types/game';
import { StatusBadge } from './StatusBadge';
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
} from 'lucide-react';
import { UserProfile } from '@/types/profile';
import { AVATAR_PRESETS } from '@/lib/profileStore';

interface DiscoverViewProps {
  games: Game[];
  onSelectGame: (game: Game) => void;
  onAddGame: (game: Game) => void;
  onOpenRouletteModal?: () => void;
  onOpenSearchWithQuery?: (query: string) => void;
  userProfile?: UserProfile;
  onOpenProfileModal?: () => void;
  onUpdateProfile?: (updated: UserProfile) => void;
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
}: DiscoverViewProps) {
  const [activeTab, setActiveTab] = useState<'discover' | 'news'>('discover');

  // Spelmål editing state
  const [isEditingGoal, setIsEditingGoal] = useState(false);
  const [goalInput, setGoalInput] = useState<number>(userProfile?.annualGamingGoal || 12);

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

  // --- News State ---
  const [newsItems, setNewsItems] = useState<NewsItem[]>([]);
  const [isLoadingNews, setIsLoadingNews] = useState(false);
  const [newsSearch, setNewsSearch] = useState('');
  const [selectedNewsCategory, setSelectedNewsCategory] = useState<
    'all' | 'my_games' | 'reviews' | 'trailers' | 'saved'
  >('all');
  const [selectedNewsPlatform, setSelectedNewsPlatform] = useState<string>('Alla plattformar');
  const [selectedNewsSource, setSelectedNewsSource] = useState<string>('Alla källor');
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
    return games.filter((g) => g.status === 'Spelar nu');
  }, [games]);

  // Nästa släpp i din önskelista (identiskt med regeln i iOS-appen)
  const nextWishlistRelease = useMemo(() => {
    const now = Date.now();
    const currentYear = new Date().getFullYear();

    const candidates = games.filter((g) => {
      if (g.status !== 'Önskelista') return false;
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

  // Spelmål 2026 beräkning (räknar endast aktiva ägda spel, exkluderar gamla spelminnen)
  const completedGamesCount = useMemo(() => {
    return games.filter((g) => g.status === 'Klar' && g.is_owned).length;
  }, [games]);

  const annualGoal = userProfile?.annualGamingGoal || 12;
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

  // Hämta nyheter vid flikbyte
  useEffect(() => {
    if (activeTab !== 'news') return;
    async function loadNews() {
      setIsLoadingNews(true);
      try {
        const res = await fetch('/api/news');
        const data = await res.json();
        if (data.news) {
          setNewsItems(data.news);
        }
      } catch (e) {
        console.error('Error loading news:', e);
      } finally {
        setIsLoadingNews(false);
      }
    }
    loadNews();
  }, [activeTab]);

  // Kör spelsnurran
  const handleSpinRoulette = () => {
    setIsSpinning(true);
    setWinnerGame(null);

    let candidates: Game[] = [];
    if (rouletteMode === 'library') {
      if (rouletteFilter === 'backlog') {
        candidates = games.filter((g) => g.status === 'Backlog');
      } else if (rouletteFilter === 'playing') {
        candidates = games.filter((g) => g.status === 'Spelar nu');
      } else {
        candidates = games.length > 0 ? games : [];
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
      result = result.filter(
        (n) =>
          n.category === 'Recension' ||
          n.title.toLowerCase().startsWith('review:') ||
          n.title.toLowerCase().includes(' review') ||
          n.title.toLowerCase().includes('recension')
      );
    } else if (selectedNewsCategory === 'trailers') {
      result = result.filter(
        (n) =>
          n.category === 'Trailer' ||
          n.title.toLowerCase().includes('trailer') ||
          n.title.toLowerCase().includes('gameplay')
      );
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

    return result;
  }, [
    newsItems,
    newsSearch,
    selectedNewsCategory,
    selectedNewsPlatform,
    selectedNewsSource,
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

  const cleanArticleTitle = (title: string) => {
    return title.replace(/^Review:\s*/i, '').trim();
  };

  const currentGenreLabel = GENRE_LIST.find((g) => g.id === selectedGenre)?.label || selectedGenre;

  return (
    <div className="space-y-8 pb-12 animate-in fade-in duration-200">
      {/* 1. Ren Tab Switcher: Upptäck vs Nyheter */}
      <div className="flex items-center justify-between border-b border-zinc-800/80 pb-3">
        <div className="flex items-center bg-zinc-900 border border-zinc-800 p-1 rounded-2xl">
          <button
            onClick={() => setActiveTab('discover')}
            className={`flex items-center gap-2 px-4 py-1.5 rounded-xl text-xs sm:text-sm font-bold transition ${
              activeTab === 'discover'
                ? 'bg-brand-red text-white shadow-sm'
                : 'text-zinc-400 hover:text-zinc-200'
            }`}
          >
            <Sparkles className="w-4 h-4" />
            <span>För dig & Upptäck</span>
          </button>

          <button
            onClick={() => setActiveTab('news')}
            className={`flex items-center gap-2 px-4 py-1.5 rounded-xl text-xs sm:text-sm font-bold transition ${
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
                  onClick={() => {
                    setGoalInput(userProfile?.annualGamingGoal || 12);
                    setIsEditingGoal(!isEditingGoal);
                  }}
                  className="text-[11px] font-semibold text-zinc-400 hover:text-white transition cursor-pointer"
                >
                  {isEditingGoal ? 'Stäng ✕' : 'Ändra mål →'}
                </button>
              </div>

              {isEditingGoal ? (
                <div className="my-2.5 space-y-2.5 p-3 bg-zinc-950/80 rounded-2xl border border-zinc-800">
                  <div className="flex items-center justify-between text-[11px] text-zinc-400 font-medium">
                    <span>Välj mål för 2026:</span>
                    <span className="font-bold text-amber-400">{goalInput} spel</span>
                  </div>
                  <div className="flex items-center gap-1.5 flex-wrap">
                    {[12, 25, 50, 75, 100].map((preset) => (
                      <button
                        key={preset}
                        type="button"
                        onClick={() => {
                          setGoalInput(preset);
                          if (userProfile && onUpdateProfile) {
                            onUpdateProfile({ ...userProfile, annualGamingGoal: preset });
                          }
                          setIsEditingGoal(false);
                        }}
                        className={`px-2.5 py-1 rounded-lg text-xs font-bold transition cursor-pointer ${
                          annualGoal === preset
                            ? 'bg-amber-500 text-zinc-950 shadow-sm'
                            : 'bg-zinc-900 text-zinc-300 hover:bg-zinc-800 border border-zinc-800'
                        }`}
                      >
                        {preset}
                      </button>
                    ))}
                  </div>
                </div>
              ) : (
                <>
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

                  <span className="text-[11px] text-zinc-400 font-medium">
                    {completedGamesCount >= annualGoal
                      ? 'Målet uppnått! Fantastiskt spelår! 🎉'
                      : `${Math.max(0, annualGoal - completedGamesCount)} spel kvar till målet`}
                  </span>
                </>
              )}
            </div>
          </div>

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
                      <h4 className="text-xs sm:text-sm font-bold text-white truncate group-hover:text-red-400 transition">
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

                    <h3 className="text-base sm:text-xl font-black text-white group-hover:text-red-400 transition truncate">
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
                  Kommande spelsläpp (Releasekalender)
                </h3>
              </div>
              <span className="text-xs text-zinc-400 font-medium">
                {isLoadingDiscover && upcomingGames.length === 0
                  ? 'Hämtar släpp...'
                  : `${upcomingGames.length} heta släpp`}
              </span>
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
                  const inLibrary = isGameInLibrary(game.igdb_id, game.title);
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
                      {relDate && (
                        <div className="absolute top-4 left-4 z-10 px-2 py-0.5 rounded-md text-[10px] font-black shadow-md backdrop-blur-md bg-red-600/90 text-white border border-red-400/40 capitalize">
                          {relDate}
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
                        className="text-xs font-bold text-zinc-100 truncate cursor-pointer hover:text-red-400 transition"
                      >
                        {game.title}
                      </h4>

                      <span className="text-[10px] text-zinc-400 mt-0.5 truncate">
                        {getPrimaryGenre(game.genres)} • {game.platforms?.[0] || 'Kommande'}
                      </span>

                      <button
                        onClick={() => onAddGame({ ...game, status: 'Önskelista' })}
                        disabled={inLibrary}
                        className={`mt-2.5 w-full py-1.5 rounded-xl text-[11px] font-semibold flex items-center justify-center gap-1 transition ${
                          inLibrary
                            ? 'bg-zinc-800/60 text-zinc-400 border border-zinc-700/50 cursor-default'
                            : 'bg-zinc-800 hover:bg-brand-red text-zinc-200 hover:text-white border border-zinc-700 hover:border-brand-red cursor-pointer'
                        }`}
                      >
                        {inLibrary ? (
                          <>
                            <Check className="w-3 h-3 text-emerald-400" />
                            <span>I samlingen</span>
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
                      {game.igdb_rating && (
                        <div className="absolute top-1.5 right-1.5 px-1.5 py-0.5 rounded bg-black/80 backdrop-blur-md text-[10px] font-bold text-amber-300 border border-amber-500/30">
                          ⭐ {game.igdb_rating}
                        </div>
                      )}
                    </div>

                    <h4
                      onClick={() => onSelectGame(game)}
                      className="text-xs font-bold text-zinc-100 truncate cursor-pointer hover:text-red-400 transition"
                    >
                      {game.title}
                    </h4>

                    <span className="text-[10px] text-zinc-400 mt-0.5 truncate">
                      {game.release_year ? `${game.release_year} • ` : ''}
                      {getPrimaryGenre(game.genres)}
                    </span>

                    <button
                      onClick={() => onAddGame(game)}
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
                          {game.igdb_rating && (
                            <div className="absolute top-1.5 right-1.5 px-1.5 py-0.5 rounded bg-black/80 backdrop-blur-md text-[10px] font-bold text-amber-300 border border-amber-500/30">
                              ⭐ {game.igdb_rating}
                            </div>
                          )}
                        </div>

                        <h4
                          onClick={() => onSelectGame(game)}
                          className="text-xs sm:text-sm font-bold text-zinc-100 truncate cursor-pointer hover:text-red-400 transition"
                        >
                          {game.title}
                        </h4>

                        <span className="text-[10px] text-zinc-400 mt-0.5 truncate">
                          {game.release_year ? `${game.release_year} • ` : ''}
                          {getPrimaryGenre(game.genres, selectedGenre)}
                        </span>

                        <button
                          onClick={() => onAddGame(game)}
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
      ) : (
        /* --- Avancerad Spelnyhets- & Recensionshub --- */
        <div className="space-y-6">
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
              </div>
            </div>

            {/* Kategori-flikar */}
            <div className="flex items-center gap-1.5 overflow-x-auto pb-1 scrollbar-none">
              {[
                { id: 'all', label: 'Alla artiklar' },
                { id: 'reviews', label: '⭐ Recensioner' },
                { id: 'my_games', label: '🎮 Från mina spel' },
                { id: 'trailers', label: '🎬 Trailers & Videor' },
                { id: 'saved', label: `🔖 Sparade (${savedNewsIds.length})` },
              ].map((f) => (
                <button
                  key={f.id}
                  onClick={() => setSelectedNewsCategory(f.id as any)}
                  className={`px-4 py-2 rounded-xl text-xs font-semibold whitespace-nowrap transition ${
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
                              <span>Finns i ditt bibliotek ({matched.status})</span>
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
                                  className={`px-1.5 py-0.2 rounded text-[10px] font-semibold ${
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
                              <span className="truncate">I ditt bibliotek ({matchedLibraryGame.status})</span>
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
    </div>
  );
}
