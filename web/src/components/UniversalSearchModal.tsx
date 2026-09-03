'use client';

import React, { useState, useEffect, useRef, useMemo, useCallback } from 'react';
import { Game, IGDBSearchResult, PlayStatus } from '@/types/game';
import { UserProfile } from '@/types/profile';
import { resolveGameAlias } from '@/lib/aliasResolver';
import { StatusBadge } from './StatusBadge';
import { inferPlayTypes } from '@/lib/statusHelper';
import {
  Search,
  X,
  Library,
  Globe,
  Plus,
  Check,
  Gamepad,
  ArrowRight,
  Clock,
  Flame,
  Loader2,
  Building2,
  SlidersHorizontal,
  ChevronDown,
  Trophy,
  Star,
  Hourglass,
  Sparkles,
  Calendar,
  Newspaper,
  ExternalLink,
} from 'lucide-react';

interface UniversalSearchModalProps {
  isOpen: boolean;
  onClose: () => void;
  games: Game[];
  onSelectGame: (game: Game) => void;
  onAddGame: (game: Game, status?: PlayStatus, completedYear?: number | null) => void;
  onOpenCompany?: (companyId: number, companyName: string, role: 'developer' | 'publisher') => void;
  userProfile?: UserProfile;
}

interface NewsItem {
  id: string;
  title: string;
  source: string;
  link: string;
  published: string;
  image?: string | null;
  summary?: string;
  category?: string;
}

interface AdvancedFilters {
  genres: string[];
  platforms: string[];
  yearFrom: string;
  yearTo: string;
  minRating: number;
  developer: string;
  sort: 'popularity' | 'rating' | 'newest' | 'oldest';
  hideOwned: boolean;
}

interface SmartSuggestion {
  label: string;
  icon: string;
  description: string;
  query?: string;
  filters?: Partial<AdvancedFilters> & { preset?: string; genre?: string; platform?: string };
}

const EMPTY_FILTERS: AdvancedFilters = {
  genres: [],
  platforms: [],
  yearFrom: '',
  yearTo: '',
  minRating: 0,
  developer: '',
  sort: 'popularity',
  hideOwned: false,
};

const GENRES = [
  'Action', 'Role-playing (RPG)', 'Adventure', 'Shooter', 'Strategy',
  'Platform', 'Racing', 'Fighting', 'Horror', 'Indie',
  'Simulator', 'Puzzle', 'Sport', 'Arcade',
];

const PLATFORM_GROUPS = [
  { label: 'PS5', value: 'ps5' },
  { label: 'PS4', value: 'ps4' },
  { label: 'PS3', value: 'ps3' },
  { label: 'PS2', value: 'ps2' },
  { label: 'PS1', value: 'ps1' },
  { label: 'Xbox Series', value: 'xbox_series' },
  { label: 'Xbox One', value: 'xbox_one' },
  { label: 'Xbox 360', value: 'xbox_360' },
  { label: 'Switch', value: 'switch' },
  { label: 'Wii', value: 'wii' },
  { label: 'Gamecube', value: 'gamecube' },
  { label: 'N64', value: 'n64' },
  { label: 'PC', value: 'pc' },
];

const ERA_PRESETS = [
  { label: '80-talets Klassiker', yearFrom: '1980', yearTo: '1989' },
  { label: '90-talets Pärlor', yearFrom: '1990', yearTo: '1999' },
  { label: '2000-talets Guldålder', yearFrom: '2000', yearTo: '2006' },
  { label: 'HD-eran', yearFrom: '2007', yearTo: '2013' },
  { label: 'Moderna Mästerverk', yearFrom: '2014', yearTo: '2020' },
  { label: 'Senaste åren', yearFrom: '2021', yearTo: String(new Date().getFullYear()) },
];

const RATING_OPTIONS = [
  { label: 'Alla betyg', value: 0 },
  { label: '70+ ⭐', value: 70 },
  { label: '80+ ⭐', value: 80 },
  { label: '85+ ⭐', value: 85 },
  { label: '90+ 🏆', value: 90 },
];

const KNOWN_DEVELOPERS = [
  'FromSoftware', 'Rockstar Games', 'Nintendo', 'Naughty Dog',
  'Capcom', 'Square Enix', 'CD Projekt Red', 'Ubisoft',
  'Bethesda', 'BioWare', 'Valve', 'Obsidian',
];

const ADD_STATUSES: { label: string; value: PlayStatus; icon: string }[] = [
  { label: 'Backlog', value: 'notStarted', icon: '📋' },
  { label: 'Spelar nu', value: 'playing', icon: '▶️' },
  { label: 'Genomspelat', value: 'completed', icon: '🏆' },
  { label: 'Önskelista', value: 'notStarted', icon: '🎁' },
];

const CURRENT_YEAR = new Date().getFullYear();
const YEAR_OPTIONS = Array.from({ length: CURRENT_YEAR - 1979 }, (_, i) => CURRENT_YEAR - i);

function buildPersonalizedSuggestions(profile?: UserProfile): SmartSuggestion[] {
  const suggestions: SmartSuggestion[] = [];

  // Alltid: Hetaste just nu
  suggestions.push({
    label: 'Hetaste spelen just nu 🔥',
    icon: '🔥',
    description: 'Nyutgivna titlar med högst hype',
    filters: { preset: 'trending', sort: 'popularity' },
  });

  // Baserat på favoritgenrer
  const topGenres = profile?.favoriteGenres?.slice(0, 2) || [];
  if (topGenres.length > 0) {
    topGenres.forEach((genre) => {
      suggestions.push({
        label: `Tidernas bästa ${genre} 🏆`,
        icon: '🏆',
        description: `Topprankade ${genre}-spel genom alla tider`,
        filters: { genre, sort: 'rating', minRating: 80 },
      });
    });
  } else {
    suggestions.push({
      label: 'Tidernas bästa RPG 🏆',
      icon: '🏆',
      description: 'Topprankade RPG-spel genom alla tider',
      filters: { genre: 'Role-playing (RPG)', sort: 'rating', minRating: 80 },
    });
  }

  // Baserat på favoritplattformar
  const platformMap: Record<string, string> = {
    'PlayStation 5': 'ps5', 'PlayStation 4': 'ps4', 'PlayStation 3': 'ps3',
    'PlayStation 2': 'ps2', 'PlayStation': 'ps4', 'Xbox Series X': 'xbox_series',
    'Xbox One': 'xbox_one', 'Nintendo Switch': 'switch', 'PC': 'pc',
  };
  const topPlatform = profile?.platforms?.find((p) => platformMap[p]);
  if (topPlatform && platformMap[topPlatform]) {
    suggestions.push({
      label: `Bästa spelen till ${topPlatform} 🎮`,
      icon: '🎮',
      description: `Toppbetyg på ${topPlatform}`,
      filters: { platform: platformMap[topPlatform], sort: 'rating', minRating: 80 },
    });
  }

  // Mästerverk (90+)
  suggestions.push({
    label: 'Kritikerfavoriter & Mästerverk ⭐',
    icon: '⭐',
    description: 'Spel med 90+ betyg – ren kvalitet',
    filters: { preset: 'masterpieces', sort: 'rating' },
  });

  // Nostalgi
  suggestions.push({
    label: '2000-talets nostalgiklassiker ⏳',
    icon: '⏳',
    description: 'Guldåldersspel från 2000–2006',
    filters: { preset: 'retro_2000s', sort: 'rating' },
  });

  // Action-spel om användaren gillar Action
  if (profile?.favoriteGenres?.includes('Action') || !profile) {
    suggestions.push({
      label: 'Bästa actionspelen genom historien',
      icon: '💥',
      description: 'Action-mästerverk med högt betyg',
      filters: { genre: 'Action', sort: 'rating', minRating: 82 },
    });
  }

  return suggestions.slice(0, 6);
}

export function UniversalSearchModal({
  isOpen,
  onClose,
  games,
  onSelectGame,
  onAddGame,
  onOpenCompany,
  userProfile,
}: UniversalSearchModalProps) {
  const [query, setQuery] = useState('');
  const [igdbResults, setIgdbResults] = useState<IGDBSearchResult[]>([]);
  const [filterResults, setFilterResults] = useState<any[]>([]);
  const [newsResults, setNewsResults] = useState<NewsItem[]>([]);
  const [isLoadingIgdb, setIsLoadingIgdb] = useState(false);
  const [isLoadingFilters, setIsLoadingFilters] = useState(false);
  const [isLoadingMore, setIsLoadingMore] = useState(false);
  const [hasMore, setHasMore] = useState(false);
  const [offset, setOffset] = useState(0);
  const [recentSearches, setRecentSearches] = useState<string[]>([]);
  const [activeTab, setActiveTab] = useState<'all' | 'library' | 'igdb' | 'news'>('all');
  const [showFilters, setShowFilters] = useState(false);
  const [filters, setFilters] = useState<AdvancedFilters>(EMPTY_FILTERS);
  const [addingGameId, setAddingGameId] = useState<number | null>(null);
  const [addStatus, setAddStatus] = useState<PlayStatus>('notStarted');
  const [addCompletedYear, setAddCompletedYear] = useState<number | null>(CURRENT_YEAR);
  const [showAddDropdown, setShowAddDropdown] = useState<number | null>(null);
  const [activePreset, setActivePreset] = useState<string | null>(null);


  const inputRef = useRef<HTMLInputElement>(null);

  const personalSuggestions = useMemo(() => buildPersonalizedSuggestions(userProfile), [userProfile]);

  const activeFilterCount = useMemo(() => {
    let count = 0;
    count += filters.genres.length;
    count += filters.platforms.length;
    if (filters.yearFrom || filters.yearTo) count++;
    if (filters.minRating > 0) count++;
    if (filters.developer) count++;
    if (filters.hideOwned) count++;
    return count;
  }, [filters]);

  const hasAnyFilter = activeFilterCount > 0 || Boolean(activePreset);

  // Ladda senaste sökningar
  useEffect(() => {
    if (typeof window !== 'undefined') {
      try {
        const saved = localStorage.getItem('gameshelf_recent_searches');
        if (saved) setRecentSearches(JSON.parse(saved));
      } catch (e) {}
    }
  }, [isOpen]);

  // Fokusera input när modalen öppnas
  useEffect(() => {
    if (isOpen) {
      setTimeout(() => inputRef.current?.focus(), 50);
    } else {
      setQuery('');
      setIgdbResults([]);
      setFilterResults([]);
      setNewsResults([]);
      setFilters(EMPTY_FILTERS);
      setShowFilters(false);
      setActivePreset(null);
      setShowAddDropdown(null);
      setOffset(0);
      setHasMore(false);
    }

  }, [isOpen]);

  // Spara senaste sökningar
  const saveSearchTerm = (term: string) => {
    const trimmed = term.trim();
    if (!trimmed) return;
    const updated = [trimmed, ...recentSearches.filter((s) => s.toLowerCase() !== trimmed.toLowerCase())].slice(0, 6);
    setRecentSearches(updated);
    if (typeof window !== 'undefined') {
      localStorage.setItem('gameshelf_recent_searches', JSON.stringify(updated));
    }
  };

  const removeRecentSearch = (e: React.MouseEvent, term: string) => {
    e.stopPropagation();
    const updated = recentSearches.filter((s) => s !== term);
    setRecentSearches(updated);
    if (typeof window !== 'undefined') {
      localStorage.setItem('gameshelf_recent_searches', JSON.stringify(updated));
    }
  };

  // Lokala biblioteksresultat
  const libraryResults = useMemo(() => {
    if (!query.trim()) return [];
    const q = query.toLowerCase();
    const resolvedQ = resolveGameAlias(query).toLowerCase();
    return games.filter(
      (g) =>
        g.title.toLowerCase().includes(q) ||
        g.title.toLowerCase().includes(resolvedQ) ||
        g.genres.some((genre) => genre.toLowerCase().includes(q)) ||
        g.developers.some((dev) => dev.toLowerCase().includes(q)) ||
        g.platforms.some((p) => p.toLowerCase().includes(q))
    );
  }, [games, query]);

  // Bygg API-URL från filter
  const buildFilterUrl = useCallback((q: string, f: AdvancedFilters, preset?: string | null, pageOffset = 0) => {
    const params = new URLSearchParams();
    if (q.trim()) params.set('q', q.trim());
    if (f.genres.length > 0) params.set('genres', f.genres.map((g) => g.toLowerCase()).join(','));
    if (f.platforms.length > 0) params.set('platforms', f.platforms.join(','));
    if (f.yearFrom) params.set('year_from', f.yearFrom);
    if (f.yearTo) params.set('year_to', f.yearTo);
    if (f.minRating > 0) params.set('min_rating', String(f.minRating));
    if (f.developer) params.set('developer', f.developer);
    if (f.sort) params.set('sort', f.sort);
    if (preset) params.set('preset', preset);
    if (pageOffset > 0) params.set('offset', String(pageOffset));
    params.set('limit', '20');
    return `/api/games/search?${params.toString()}`;
  }, []);

  // IGDB title-sök (debounced) – nollställer offset vid ny sökning
  useEffect(() => {
    if (!query.trim()) {
      setIgdbResults([]);
      setHasMore(false);
      return;
    }

    setOffset(0);
    const timer = setTimeout(async () => {
      setIsLoadingIgdb(true);
      try {
        const url = buildFilterUrl(query, filters, activePreset, 0);
        const res = await fetch(url);
        const data = await res.json();
        if (data.results) {
          setIgdbResults(data.results);
          setHasMore(data.hasMore ?? false);
        }
      } catch (e) {
        console.error('IGDB search error:', e);
      } finally {
        setIsLoadingIgdb(false);
      }
    }, 280);

    return () => clearTimeout(timer);
  }, [query, filters, activePreset, buildFilterUrl]);

  // Filter/preset sök utan fritext (tidsmaskin & smarta förslag) – nollställer offset
  useEffect(() => {
    if (query.trim()) {
      setFilterResults([]);
      setHasMore(false);
      return;
    }
    if (!hasAnyFilter) {
      setFilterResults([]);
      setHasMore(false);
      return;
    }

    setOffset(0);
    const timer = setTimeout(async () => {
      setIsLoadingFilters(true);
      try {
        const url = buildFilterUrl('', filters, activePreset, 0);
        const res = await fetch(url);
        const data = await res.json();
        if (data.results) {
          setFilterResults(data.results);
          setHasMore(data.hasMore ?? false);
        }
      } catch (e) {
        console.error('Filter search error:', e);
      } finally {
        setIsLoadingFilters(false);
      }
    }, 400);

    return () => clearTimeout(timer);
  }, [query, filters, activePreset, hasAnyFilter, buildFilterUrl]);

  // Ladda fler resultat (paginering)
  const handleLoadMore = useCallback(async () => {
    const newOffset = offset + 20;
    setIsLoadingMore(true);
    try {
      const url = buildFilterUrl(query, filters, activePreset, newOffset);
      const res = await fetch(url);
      const data = await res.json();
      if (data.results) {
        if (query.trim()) {
          setIgdbResults((prev) => [...prev, ...data.results]);
        } else {
          setFilterResults((prev) => [...prev, ...data.results]);
        }
        setHasMore(data.hasMore ?? false);
        setOffset(newOffset);
      }
    } catch (e) {
      console.error('Load more error:', e);
    } finally {
      setIsLoadingMore(false);
    }
  }, [offset, query, filters, activePreset, buildFilterUrl]);



  // Nyhetssökning
  useEffect(() => {
    if (!query.trim()) {
      setNewsResults([]);
      return;
    }
    const timer = setTimeout(async () => {
      try {
        const res = await fetch('/api/news');
        const data = await res.json();
        if (data.news) {
          const q = query.toLowerCase();
          const matched = (data.news as NewsItem[])
            .filter(
              (n) =>
                n.title.toLowerCase().includes(q) ||
                n.source.toLowerCase().includes(q) ||
                (n.summary && n.summary.toLowerCase().includes(q))
            )
            .slice(0, 4);
          setNewsResults(matched);
        }
      } catch (e) {}
    }, 600);
    return () => clearTimeout(timer);
  }, [query]);

  const convertResultToGame = (r: any): Game => {
    return {
      id: crypto.randomUUID(),
      title: r.title || r.name,
      cover_url: r.cover_url || r.cover?.url || null,
      platforms: r.platforms || [],
      release_year: r.release_year || null,
      first_release_date: r.first_release_date || null,
      genres: r.genres || [],
      developers: r.developers || [],
      status: 'notStarted',
      rating: null,
      igdb_rating: r.igdb_rating || null,
      igdb_id: r.id,
      estimated_hours: null,
      is_owned: false,
      is_backlog: false,
      play_types: inferPlayTypes({ title: r.title || r.name, genres: r.genres || [] }),
      notes: '',
      todos: [],
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };
  };

  const isGameInLibrary = (igdbId?: number | null, title?: string) => {
    return games.some(
      (g) => (igdbId && g.igdb_id === igdbId) || (title && g.title.toLowerCase() === title?.toLowerCase())
    );
  };

  const handleAddGame = async (result: any, status: PlayStatus, completedYear: number | null) => {
    const gameObj = convertResultToGame(result);
    if (status === 'completed') {
      gameObj.status = 'completed';
    } else if (status === 'playing') {
      gameObj.status = 'playing';
    } else {
      gameObj.status = 'notStarted';
    }
    const isWishlist = status === 'notStarted' && !gameObj.is_owned;
    gameObj.is_owned = !isWishlist;
    gameObj.is_backlog = status === 'notStarted' && !isWishlist;
    setAddingGameId(result.id);
    onAddGame(gameObj, status, status === 'completed' ? completedYear : null);
    setTimeout(() => setAddingGameId(null), 1200);
    setShowAddDropdown(null);
  };

  const applySuggestion = (suggestion: SmartSuggestion) => {
    if (suggestion.query) {
      setQuery(suggestion.query);
    }
    if (suggestion.filters) {
      const { preset, genre, platform, ...filterPart } = suggestion.filters;
      setFilters((prev) => ({
        ...prev,
        ...filterPart,
        genres: filterPart.genres ?? (genre ? [genre] : []),
        platforms: filterPart.platforms ?? (platform ? [platform] : []),
      }));
      setActivePreset(preset || null);
      if (Object.keys(filterPart).length > 0 || preset || genre || platform) {
        setShowFilters(true);
      }
    }
  };

  const resetFilters = () => {
    setFilters(EMPTY_FILTERS);
    setActivePreset(null);
  };


// JSX replacement for UniversalSearchModal – from line 526 to end of file

  if (!isOpen) return null;

  // Aktiva resultat att visa
  const displayResults = query.trim() ? igdbResults : filterResults;
  const currentResults = displayResults.filter((r) =>
    filters.hideOwned ? !isGameInLibrary(r.id, r.title || r.name) : true
  );

  // ── Återanvändbar filterpanel ──
  const FilterPanelContent = (
    <div className="space-y-4 p-4">
      {/* Tidsmaskin */}
      <section className="space-y-2">
        <header className="flex items-center gap-1.5 text-[10px] font-bold text-zinc-500 uppercase tracking-widest">
          <Hourglass className="w-3 h-3 text-amber-400" />
          Tidsmaskin
        </header>
        <div className="flex gap-1.5">
          <input
            type="number" value={filters.yearFrom}
            onChange={(e) => setFilters((f) => ({ ...f, yearFrom: e.target.value }))}
            placeholder="Från" min="1970" max={CURRENT_YEAR}
            className="w-full bg-zinc-900 border border-zinc-800 focus:border-amber-400/60 rounded-xl px-2.5 py-2 text-xs text-white focus:outline-none transition placeholder-zinc-700"
          />
          <span className="text-zinc-700 text-xs self-center shrink-0">–</span>
          <input
            type="number" value={filters.yearTo}
            onChange={(e) => setFilters((f) => ({ ...f, yearTo: e.target.value }))}
            placeholder="Till" min="1970" max={CURRENT_YEAR}
            className="w-full bg-zinc-900 border border-zinc-800 focus:border-amber-400/60 rounded-xl px-2.5 py-2 text-xs text-white focus:outline-none transition placeholder-zinc-700"
          />
        </div>
        <div className="space-y-0.5">
          {ERA_PRESETS.map((era) => {
            const active = filters.yearFrom === era.yearFrom && filters.yearTo === era.yearTo;
            return (
              <button key={era.label}
                onClick={() => setFilters((f) => ({ ...f, yearFrom: active ? '' : era.yearFrom, yearTo: active ? '' : era.yearTo }))}
                className={`w-full px-3 py-2 rounded-xl text-xs font-medium transition cursor-pointer text-left ${
                  active ? 'bg-amber-500/15 text-amber-300 border border-amber-500/30' : 'text-zinc-500 hover:text-zinc-200 hover:bg-zinc-800/50'
                }`}
              >{era.label}</button>
            );
          })}
        </div>
      </section>

      <div className="h-px bg-zinc-800/50" />

      {/* Genre */}
      <section className="space-y-1">
        <header className="flex items-center justify-between text-[10px] font-bold text-zinc-500 uppercase tracking-widest">
          <span>Genre</span>
          {filters.genres.length > 0 && (
            <span className="text-brand-red font-semibold lowercase">{filters.genres.length} valda</span>
          )}
        </header>
        <div className="space-y-0.5">
          {GENRES.map((g) => {
            const active = filters.genres.includes(g);
            return (
              <button key={g}
                onClick={() => setFilters((f) => ({
                  ...f,
                  genres: active ? f.genres.filter((x) => x !== g) : [...f.genres, g],
                }))}
                className={`w-full px-3 py-2 rounded-xl text-xs font-medium transition cursor-pointer text-left flex items-center justify-between ${
                  active ? 'bg-brand-red/15 text-red-300 border border-brand-red/30' : 'text-zinc-500 hover:text-zinc-200 hover:bg-zinc-800/50'
                }`}
              >
                <span>{g === 'Role-playing (RPG)' ? 'RPG' : g}</span>
                {active && <Check className="w-3.5 h-3.5 text-brand-red shrink-0 ml-2" />}
              </button>
            );
          })}
        </div>
      </section>

      <div className="h-px bg-zinc-800/50" />

      {/* Plattform */}
      <section className="space-y-1">
        <header className="flex items-center justify-between text-[10px] font-bold text-zinc-500 uppercase tracking-widest">
          <span>Plattform</span>
          {filters.platforms.length > 0 && (
            <span className="text-blue-400 font-semibold lowercase">{filters.platforms.length} valda</span>
          )}
        </header>
        <div className="space-y-0.5">
          {PLATFORM_GROUPS.map((p) => {
            const active = filters.platforms.includes(p.value);
            return (
              <button key={p.value}
                onClick={() => setFilters((f) => ({
                  ...f,
                  platforms: active ? f.platforms.filter((x) => x !== p.value) : [...f.platforms, p.value],
                }))}
                className={`w-full px-3 py-2 rounded-xl text-xs font-medium transition cursor-pointer text-left flex items-center justify-between ${
                  active ? 'bg-blue-500/15 text-blue-300 border border-blue-500/30' : 'text-zinc-500 hover:text-zinc-200 hover:bg-zinc-800/50'
                }`}
              >
                <span>{p.label}</span>
                {active && <Check className="w-3.5 h-3.5 text-blue-400 shrink-0 ml-2" />}
              </button>
            );
          })}
        </div>
      </section>

      <div className="h-px bg-zinc-800/50" />

      {/* Betyg */}
      <section className="space-y-1">
        <header className="text-[10px] font-bold text-zinc-500 uppercase tracking-widest">Minst betyg</header>
        <div className="space-y-0.5">
          {RATING_OPTIONS.map((r) => {
            const active = filters.minRating === r.value;
            return (
              <button key={r.value}
                onClick={() => setFilters((f) => ({ ...f, minRating: active ? 0 : r.value }))}
                className={`w-full px-3 py-2 rounded-xl text-xs font-medium transition cursor-pointer text-left ${
                  active ? 'bg-amber-500/15 text-amber-300 border border-amber-500/30' : 'text-zinc-500 hover:text-zinc-200 hover:bg-zinc-800/50'
                }`}
              >{r.label}</button>
            );
          })}
        </div>
      </section>

      <div className="h-px bg-zinc-800/50" />

      {/* Studio */}
      <section className="space-y-2">
        <header className="text-[10px] font-bold text-zinc-500 uppercase tracking-widest">Studio</header>
        <input
          type="text" value={filters.developer}
          onChange={(e) => setFilters((f) => ({ ...f, developer: e.target.value }))}
          placeholder="T.ex. FromSoftware..."
          className="w-full bg-zinc-900 border border-zinc-800 focus:border-brand-red/50 rounded-xl px-2.5 py-2 text-xs text-white focus:outline-none transition placeholder-zinc-700"
        />
        <div className="space-y-0.5">
          {KNOWN_DEVELOPERS.map((dev) => (
            <button key={dev}
              onClick={() => setFilters((f) => ({ ...f, developer: f.developer === dev ? '' : dev }))}
              className={`w-full px-3 py-2 rounded-xl text-xs font-medium transition cursor-pointer text-left ${
                filters.developer === dev ? 'bg-brand-red/15 text-red-300 border border-brand-red/30' : 'text-zinc-600 hover:text-zinc-300 hover:bg-zinc-800/50'
              }`}
            >{dev}</button>
          ))}
        </div>
      </section>

      <div className="h-px bg-zinc-800/50" />

      {/* Sortering + övrigt */}
      <section className="space-y-3">
        <div className="space-y-1.5">
          <header className="text-[10px] font-bold text-zinc-500 uppercase tracking-widest">Sortera</header>
          <select
            value={filters.sort}
            onChange={(e) => setFilters((f) => ({ ...f, sort: e.target.value as AdvancedFilters['sort'] }))}
            className="w-full bg-zinc-900 border border-zinc-800 text-zinc-300 text-xs rounded-xl px-2.5 py-2 focus:outline-none cursor-pointer"
          >
            <option value="popularity">Popularitet</option>
            <option value="rating">Betyg</option>
            <option value="newest">Nyast</option>
            <option value="oldest">Äldst</option>
          </select>
        </div>
        <label className="flex items-center gap-2.5 text-xs text-zinc-500 cursor-pointer select-none">
          <input type="checkbox" checked={filters.hideOwned}
            onChange={(e) => setFilters((f) => ({ ...f, hideOwned: e.target.checked }))}
            className="accent-brand-red rounded" />
          Dölj spel jag äger
        </label>
      </section>

      {(activeFilterCount > 0 || activePreset) && (
        <button onClick={resetFilters}
          className="w-full py-2 rounded-xl text-xs font-semibold text-zinc-600 hover:text-red-400 transition cursor-pointer flex items-center justify-center gap-1.5 border border-zinc-800/60 hover:border-red-400/20"
        >
          <X className="w-3 h-3" /> Rensa alla filter
        </button>
      )}
    </div>
  );

  // ── Resultatlistor (gemensam komponent) ──
  const renderResults = () => (
    <>
      {/* Tom vy med smarta förslag */}
      {!query.trim() && !hasAnyFilter && (
        <div className="space-y-5">
          {recentSearches.length > 0 && (
            <div>
              <div className="flex items-center gap-1.5 text-[10px] font-bold text-zinc-600 uppercase tracking-widest mb-2.5">
                <Clock className="w-3 h-3" /> Senaste sökningar
              </div>
              <div className="flex flex-wrap gap-1.5">
                {recentSearches.map((term) => (
                  <button key={term} onClick={() => { setQuery(term); saveSearchTerm(term); }}
                    className="group flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-zinc-900 border border-zinc-800 text-xs text-zinc-400 hover:text-white hover:border-zinc-700 transition cursor-pointer"
                  >
                    {term}
                    <X className="w-2.5 h-2.5 text-zinc-700 group-hover:text-zinc-500" onClick={(e) => removeRecentSearch(e, term)} />
                  </button>
                ))}
              </div>
            </div>
          )}

          <div>
            <div className="flex items-center gap-1.5 text-[10px] font-bold text-zinc-600 uppercase tracking-widest mb-3">
              <Sparkles className="w-3 h-3 text-amber-400" />
              {userProfile?.username ? `Förslag för ${userProfile.username}` : 'Smarta sökförslag'}
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
              {personalSuggestions.map((s) => (
                <button key={s.label} onClick={() => applySuggestion(s)}
                  className="group flex items-center gap-3 p-3 rounded-2xl bg-zinc-900/40 border border-zinc-800/50 hover:border-zinc-700 hover:bg-zinc-900 transition cursor-pointer text-left"
                >
                  <div className="w-9 h-9 rounded-xl bg-zinc-800 group-hover:bg-zinc-700 flex items-center justify-center text-lg shrink-0 transition">{s.icon}</div>
                  <div className="min-w-0">
                    <div className="text-xs font-semibold text-zinc-300 group-hover:text-white transition truncate">{s.label}</div>
                    <div className="text-[11px] text-zinc-600 truncate">{s.description}</div>
                  </div>
                </button>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* Filter/preset-resultat (utan fritext) */}
      {!query.trim() && hasAnyFilter && (
        <div className="space-y-2">
          <div className="flex items-center justify-between mb-1">
            <div className="flex items-center gap-1.5 text-[10px] font-bold text-zinc-600 uppercase tracking-widest">
              <Globe className="w-3 h-3 text-brand-red" />
              {isLoadingFilters ? 'Söker...' : `${currentResults.length}${hasMore ? '+' : ''} resultat`}
            </div>
            {isLoadingFilters && <Loader2 className="w-3.5 h-3.5 animate-spin text-brand-red" />}
          </div>

          {isLoadingFilters && currentResults.length === 0 && (
            <div className="flex items-center justify-center py-16 text-zinc-700">
              <Loader2 className="w-6 h-6 animate-spin" />
            </div>
          )}

          {currentResults.map((result) => {
            const inLibrary = isGameInLibrary(result.id, result.title);
            const inLib = games.find((g) => g.igdb_id === result.id);
            return (
              <GameResultCard key={result.id} result={result}
                inLibrary={inLibrary} inLibGame={inLib}
                isAdding={addingGameId === result.id} showDrop={showAddDropdown === result.id}
                addStatus={addStatus} addCompletedYear={addCompletedYear}
                onSelectGame={() => { if (inLib) { onSelectGame(inLib); onClose(); } }}
                onToggleDrop={() => setShowAddDropdown(showAddDropdown === result.id ? null : result.id)}
                onSetStatus={setAddStatus} onSetYear={setAddCompletedYear}
                onConfirmAdd={() => handleAddGame(result, addStatus, addCompletedYear)}
              />
            );
          })}

          {!isLoadingFilters && currentResults.length === 0 && (
            <div className="text-center py-12 text-zinc-700">
              <Search className="w-5 h-5 mx-auto mb-2 opacity-50" />
              <p className="text-xs">Inga träffar. Prova att justera filtren.</p>
            </div>
          )}

          {hasMore && !isLoadingFilters && (
            <button onClick={handleLoadMore} disabled={isLoadingMore}
              className="w-full py-3 rounded-2xl border border-zinc-800 text-xs font-semibold text-zinc-600 hover:text-zinc-300 hover:border-zinc-700 hover:bg-zinc-900/40 transition cursor-pointer flex items-center justify-center gap-2"
            >
              {isLoadingMore ? <><Loader2 className="w-3.5 h-3.5 animate-spin" />Laddar...</> : <>Ladda fler<ChevronDown className="w-3.5 h-3.5" /></>}
            </button>
          )}
        </div>
      )}

      {/* Fritextsök-resultat */}
      {query.trim() && (
        <div className="space-y-5">
          {/* Bibliotek */}
          {(activeTab === 'all' || activeTab === 'library') && libraryResults.length > 0 && (
            <div>
              <div className="flex items-center gap-1.5 text-[10px] font-bold text-zinc-600 uppercase tracking-widest mb-2.5">
                <Library className="w-3 h-3 text-emerald-400" /> I ditt bibliotek ({libraryResults.length})
              </div>
              <div className="space-y-1.5">
                {libraryResults.map((game) => (
                  <div key={game.id} onClick={() => { saveSearchTerm(query); onSelectGame(game); onClose(); }}
                    className="flex items-center gap-3 p-3 rounded-2xl bg-zinc-900/40 border border-zinc-800/50 hover:border-zinc-700 hover:bg-zinc-900 cursor-pointer group transition"
                  >
                    <div className="w-9 h-12 rounded-lg overflow-hidden bg-zinc-950 shrink-0 border border-zinc-800/60">
                      {game.cover_url
                        ? <img src={game.cover_url} alt={game.title} className="w-full h-full object-cover group-hover:scale-105 transition" />
                        : <div className="w-full h-full flex items-center justify-center"><Gamepad className="w-3.5 h-3.5 text-zinc-700" /></div>
                      }
                    </div>
                    <div className="min-w-0 flex-1">
                      <h4 className="text-sm font-semibold text-zinc-300 group-hover:text-white transition truncate">{game.title}</h4>
                      <div className="flex items-center gap-2 mt-0.5">
                        <StatusBadge game={game} />
                        {game.release_year && <span className="text-[11px] text-zinc-600">{game.release_year}</span>}
                      </div>
                    </div>
                    <ArrowRight className="w-4 h-4 text-zinc-700 group-hover:text-zinc-400 transition shrink-0" />
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Studio-genväg */}
          {query.trim().length >= 2 && onOpenCompany && (
            <div onClick={() => { saveSearchTerm(query.trim()); onClose(); onOpenCompany(0, query.trim(), 'developer'); }}
              className="flex items-center gap-3 p-3 rounded-2xl bg-zinc-900/40 border border-zinc-800/50 hover:border-brand-red/30 hover:bg-zinc-900 cursor-pointer group transition"
            >
              <div className="w-9 h-9 rounded-xl bg-brand-red/10 border border-brand-red/20 flex items-center justify-center text-brand-red shrink-0">
                <Building2 className="w-4 h-4" />
              </div>
              <div className="min-w-0 flex-1">
                <div className="text-[10px] font-bold text-zinc-600 uppercase tracking-wider">Studio & Utgivare</div>
                <div className="text-sm font-semibold text-zinc-300 group-hover:text-white truncate">"{query.trim()}"</div>
              </div>
              <ArrowRight className="w-4 h-4 text-zinc-700 group-hover:text-brand-red transition shrink-0" />
            </div>
          )}

          {/* IGDB-resultat */}
          {(activeTab === 'all' || activeTab === 'igdb') && (
            <div>
              <div className="flex items-center justify-between mb-2.5">
                <div className="flex items-center gap-1.5 text-[10px] font-bold text-zinc-600 uppercase tracking-widest">
                  <Globe className="w-3 h-3 text-brand-red" />
                  IGDB{igdbResults.length > 0 ? ` · ${igdbResults.length}${hasMore ? '+' : ''}` : ''}
                </div>
                {isLoadingIgdb && <Loader2 className="w-3.5 h-3.5 animate-spin text-brand-red" />}
              </div>

              {igdbResults.length > 0 ? (
                <div className="space-y-1.5">
                  {igdbResults.map((result) => {
                    const asResult = {
                      id: result.id, title: result.name,
                      cover_url: result.cover?.url,
                      platforms: (result.platforms || []).map((p: any) => p.name),
                      genres: (result.genres || []).map((g: any) => g.name),
                      developers: (result.involved_companies || []).filter((c: any) => c.developer).map((c: any) => c.company.name),
                      release_year: result.first_release_date ? new Date(result.first_release_date * 1000).getFullYear() : null,
                      first_release_date: result.first_release_date || null,
                      igdb_rating: result.total_rating ? Math.round((result.total_rating / 10) * 10) / 10 : null,
                    };
                    const inLibrary = isGameInLibrary(result.id, result.name);
                    const inLib = games.find((g) => g.igdb_id === result.id);
                    return (
                      <GameResultCard key={result.id} result={asResult}
                        inLibrary={inLibrary} inLibGame={inLib}
                        isAdding={addingGameId === result.id} showDrop={showAddDropdown === result.id}
                        addStatus={addStatus} addCompletedYear={addCompletedYear}
                        onSelectGame={() => {
                          if (inLib) { saveSearchTerm(query); onSelectGame(inLib); onClose(); }
                          else { saveSearchTerm(query); onSelectGame(convertResultToGame(asResult)); onClose(); }
                        }}
                        onToggleDrop={() => setShowAddDropdown(showAddDropdown === result.id ? null : result.id)}
                        onSetStatus={setAddStatus} onSetYear={setAddCompletedYear}
                        onConfirmAdd={() => handleAddGame(asResult, addStatus, addCompletedYear)}
                      />
                    );
                  })}

                  {hasMore && !isLoadingIgdb && (
                    <button onClick={handleLoadMore} disabled={isLoadingMore}
                      className="w-full py-3 rounded-2xl border border-zinc-800 text-xs font-semibold text-zinc-600 hover:text-zinc-300 hover:border-zinc-700 hover:bg-zinc-900/40 transition cursor-pointer flex items-center justify-center gap-2"
                    >
                      {isLoadingMore ? <><Loader2 className="w-3.5 h-3.5 animate-spin" />Laddar...</> : <>Ladda fler<ChevronDown className="w-3.5 h-3.5" /></>}
                    </button>
                  )}
                </div>
              ) : (
                !isLoadingIgdb && query.trim().length > 1 && (
                  <p className="text-xs text-zinc-700 py-3 text-center">Inga träffar på IGDB för &ldquo;{query}&rdquo;</p>
                )
              )}
            </div>
          )}

          {/* Nyheter */}
          {(activeTab === 'all' || activeTab === 'news') && newsResults.length > 0 && (
            <div>
              <div className="flex items-center gap-1.5 text-[10px] font-bold text-zinc-600 uppercase tracking-widest mb-2.5">
                <Newspaper className="w-3 h-3 text-rose-400" /> Nyheter ({newsResults.length})
              </div>
              <div className="space-y-1.5">
                {newsResults.map((item) => (
                  <a key={item.id} href={item.link} target="_blank" rel="noopener noreferrer"
                    className="flex items-center gap-3 p-3 rounded-2xl bg-zinc-900/40 border border-zinc-800/50 hover:border-zinc-700 hover:bg-zinc-900 transition group"
                  >
                    <div className="min-w-0 flex-1">
                      <div className="flex items-center gap-1.5 text-[10px] text-zinc-700 mb-1">
                        <span className="font-bold text-zinc-500">{item.source}</span>
                        <span>·</span>
                        <span>{new Date(item.published).toLocaleDateString('sv-SE')}</span>
                      </div>
                      <p className="text-xs font-semibold text-zinc-300 group-hover:text-white transition line-clamp-1">{item.title}</p>
                    </div>
                    <ExternalLink className="w-3.5 h-3.5 text-zinc-700 group-hover:text-zinc-400 shrink-0 transition" />
                  </a>
                ))}
              </div>
            </div>
          )}

          {/* Inga resultat alls */}
          {!isLoadingIgdb && !isLoadingFilters && libraryResults.length === 0 && igdbResults.length === 0 && newsResults.length === 0 && (
            <div className="text-center py-16 text-zinc-700">
              <Search className="w-7 h-7 mx-auto mb-2.5 opacity-40" />
              <p className="text-sm font-medium text-zinc-500">Inga träffar för &ldquo;{query}&rdquo;</p>
              <p className="text-xs mt-1">Prova en annan titel, studio eller konsol</p>
            </div>
          )}
        </div>
      )}
    </>
  );

  return (
    <>
      {/* ── BACKDROP ── */}
      <div className="fixed inset-0 z-50 bg-black/75 backdrop-blur-sm animate-in fade-in duration-200" onClick={onClose} />

      {/* ── MOBIL: FILTER BOTTOM SHEET ── */}
      <div
        className={`md:hidden fixed bottom-0 left-0 right-0 z-[70] bg-[#111216] border-t border-zinc-800 rounded-t-3xl transition-transform duration-300 ease-out max-h-[82vh] overflow-hidden flex flex-col ${
          showFilters ? 'translate-y-0' : 'translate-y-full'
        }`}
      >
        {/* Handle bar */}
        <div className="flex justify-center pt-3 pb-1 shrink-0">
          <div className="w-10 h-1 bg-zinc-700 rounded-full" />
        </div>
        <div className="flex items-center justify-between px-5 py-3 border-b border-zinc-800/60 shrink-0">
          <div className="flex items-center gap-2">
            <SlidersHorizontal className="w-4 h-4 text-brand-red" />
            <span className="text-sm font-bold text-white">Filtrera</span>
            {activeFilterCount > 0 && (
              <span className="px-1.5 py-0.5 rounded-full bg-brand-red text-white text-[10px] font-bold">{activeFilterCount}</span>
            )}
          </div>
          <button onClick={() => setShowFilters(false)} className="p-1.5 rounded-xl bg-zinc-900 border border-zinc-800 text-zinc-400 hover:text-white transition cursor-pointer">
            <X className="w-4 h-4" />
          </button>
        </div>
        <div className="overflow-y-auto scrollbar-thin scrollbar-thumb-zinc-800 flex-1">
          {FilterPanelContent}
        </div>
      </div>

      {/* ── HUVUD-MODAL ── */}
      <div className="fixed inset-0 z-[60] flex items-end sm:items-start justify-center sm:p-6 sm:pt-12 pointer-events-none">
        <div
          className={`w-full pointer-events-auto bg-[#0f1013] border border-zinc-800/70 sm:rounded-3xl shadow-2xl flex flex-col overflow-hidden animate-in zoom-in-95 fade-in duration-200
            h-[92dvh] sm:h-auto sm:max-h-[90vh]
            transition-[max-width] duration-300
            ${showFilters ? 'md:max-w-5xl' : 'max-w-2xl'}`}
          onClick={(e) => e.stopPropagation()}
        >
          {/* ── SÖKINPUT ── */}
          <div className="flex items-center gap-3 px-4 sm:px-5 py-3.5 border-b border-zinc-800/70 bg-zinc-950/50 shrink-0">
            <Search className="w-4 h-4 text-zinc-600 shrink-0" />
            <input
              ref={inputRef}
              type="text"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Escape') onClose();
                if (e.key === 'Enter' && query.trim()) saveSearchTerm(query);
              }}
              placeholder="Sök spel, lägg till i biblioteket..."
              className="flex-1 bg-transparent text-sm text-zinc-100 placeholder-zinc-600 focus:outline-none"
            />
            <div className="flex items-center gap-2 shrink-0">
              <button
                onClick={() => setShowFilters((v) => !v)}
                className={`relative flex items-center gap-1.5 px-2.5 py-1.5 rounded-xl text-xs font-semibold transition cursor-pointer ${
                  showFilters || activeFilterCount > 0
                    ? 'bg-brand-red text-white shadow-sm shadow-brand-red/30'
                    : 'bg-zinc-900 border border-zinc-800 text-zinc-500 hover:text-zinc-200 hover:border-zinc-700'
                }`}
              >
                <SlidersHorizontal className="w-3.5 h-3.5" />
                <span className="hidden sm:inline">Filter</span>
                {activeFilterCount > 0 && !showFilters && (
                  <span className="absolute -top-1.5 -right-1.5 w-4 h-4 rounded-full bg-brand-red text-white text-[9px] flex items-center justify-center font-bold shadow-md">
                    {activeFilterCount}
                  </span>
                )}
              </button>

              {query ? (
                <button onClick={() => { setQuery(''); inputRef.current?.focus(); }} className="p-1.5 text-zinc-600 hover:text-zinc-300 transition">
                  <X className="w-4 h-4" />
                </button>
              ) : (
                <kbd className="hidden sm:inline-flex items-center px-1.5 py-0.5 rounded-lg bg-zinc-900 text-[10px] font-mono text-zinc-600 border border-zinc-800">ESC</kbd>
              )}
            </div>
          </div>

          {/* ── FLIKAR (vid fritext) ── */}
          {query.trim() && (
            <div className="flex items-center gap-1 px-4 py-2 border-b border-zinc-800/60 overflow-x-auto scrollbar-none shrink-0">
              {(
                [
                  { id: 'all', label: 'Allt' },
                  { id: 'library', label: `Bibliotek (${libraryResults.length})`, icon: <Library className="w-3 h-3" /> },
                  { id: 'igdb', label: `IGDB (${igdbResults.length})`, icon: <Globe className="w-3 h-3" /> },
                  ...(newsResults.length > 0 ? [{ id: 'news', label: `Nyheter (${newsResults.length})`, icon: <Newspaper className="w-3 h-3" /> }] : []),
                ] as { id: string; label: string; icon?: React.ReactNode }[]
              ).map((tab) => (
                <button
                  key={tab.id}
                  onClick={() => setActiveTab(tab.id as typeof activeTab)}
                  className={`flex items-center gap-1.5 px-3 py-1 rounded-xl text-xs font-semibold whitespace-nowrap cursor-pointer transition ${
                    activeTab === tab.id ? 'bg-white text-zinc-950' : 'text-zinc-600 hover:text-zinc-300'
                  }`}
                >
                  {tab.icon}{tab.label}
                </button>
              ))}
            </div>
          )}

          {/* ── BODY: sidebar + resultat ── */}
          <div className="flex flex-1 min-h-0">
            {/* Desktop filter-sidebar (dolt på mobil) */}
            {showFilters && (
              <div className="hidden md:flex w-56 lg:w-64 shrink-0 flex-col border-r border-zinc-800/60 bg-zinc-950/20 overflow-y-auto scrollbar-thin scrollbar-thumb-zinc-800">
                {FilterPanelContent}
              </div>
            )}

            {/* Resultatlista */}
            <div className="flex-1 overflow-y-auto p-4 sm:p-5 scrollbar-thin scrollbar-thumb-zinc-800">
              {renderResults()}
            </div>
          </div>

          {/* ── FOOTER ── */}
          <div className="flex items-center justify-between px-4 sm:px-5 py-2.5 border-t border-zinc-800/60 bg-zinc-950/40 shrink-0">
            <div className="flex items-center gap-3 text-[11px] text-zinc-700">
              <span className="hidden sm:flex items-center gap-1">
                <kbd className="px-1.5 py-0.5 rounded-md bg-zinc-900 border border-zinc-800 text-zinc-500 font-mono text-[10px]">ESC</kbd> Stäng
              </span>
              <span className="hidden sm:flex items-center gap-1">
                <kbd className="px-1.5 py-0.5 rounded-md bg-zinc-900 border border-zinc-800 text-zinc-500 font-mono text-[10px]">⌘K</kbd> Öppna
              </span>
            </div>
            <span className="text-[11px] text-zinc-700">Gameshelf</span>
          </div>
        </div>
      </div>
    </>
  );
}

// ── GameResultCard ──
interface GameResultCardProps {
  result: {
    id: number;
    title: string;
    cover_url?: string | null;
    platforms?: string[];
    genres?: string[];
    developers?: string[];
    release_year?: number | null;
    igdb_rating?: number | null;
    first_release_date?: number | null;
  };
  inLibrary: boolean;
  inLibGame?: Game;
  isAdding: boolean;
  showDrop: boolean;
  addStatus: PlayStatus;
  addCompletedYear: number | null;
  onSelectGame: () => void;
  onToggleDrop: () => void;
  onSetStatus: (s: PlayStatus) => void;
  onSetYear: (y: number | null) => void;
  onConfirmAdd: () => void;
}

const STATUS_OPTIONS: { label: string; value: PlayStatus; icon: string }[] = [
  { label: 'Backlog', value: 'notStarted', icon: '📋' },
  { label: 'Spelar', value: 'playing', icon: '▶️' },
  { label: 'Klarat', value: 'completed', icon: '🏆' },
  { label: 'Önskelista', value: 'notStarted', icon: '🎁' },
];

const CY = new Date().getFullYear();

function GameResultCard({
  result, inLibrary, isAdding, showDrop,
  addStatus, addCompletedYear,
  onSelectGame, onToggleDrop, onSetStatus, onSetYear, onConfirmAdd,
}: GameResultCardProps) {
  return (
    <div className={`rounded-2xl border transition-all overflow-hidden ${
      showDrop ? 'border-brand-red/25 bg-zinc-900/70' : 'border-zinc-800/50 bg-zinc-900/20 hover:border-zinc-700/80 hover:bg-zinc-900/50'
    }`}>
      <div className="flex items-center gap-3 p-3">
        {/* Omslag */}
        <div onClick={onSelectGame} className="w-10 h-14 rounded-lg overflow-hidden bg-zinc-950 shrink-0 border border-zinc-800/50 cursor-pointer">
          {result.cover_url
            ? <img src={result.cover_url} alt={result.title} className="w-full h-full object-cover" loading="lazy" />
            : <div className="w-full h-full flex items-center justify-center"><Gamepad className="w-4 h-4 text-zinc-700" /></div>
          }
        </div>

        {/* Info */}
        <div onClick={onSelectGame} className="flex-1 min-w-0 cursor-pointer">
          <h4 className="text-sm font-semibold text-zinc-200 hover:text-white transition truncate leading-tight">{result.title}</h4>
          <p className="text-[11px] text-zinc-500 mt-0.5 truncate">
            {result.release_year || 'TBA'}
            {result.genres?.[0] && ` · ${result.genres[0]}`}
            {result.igdb_rating && <span className="text-amber-400/70 ml-1">★ {result.igdb_rating}</span>}
          </p>
          {result.platforms && result.platforms.length > 0 && (
            <p className="text-[10px] text-zinc-700 truncate mt-0.5">{result.platforms.slice(0, 2).join(' · ')}</p>
          )}
        </div>

        {/* Åtgärdsknapp */}
        {inLibrary || isAdding ? (
          <div className={`flex items-center gap-1 px-2.5 py-1.5 rounded-xl text-[11px] font-bold shrink-0 ${
            isAdding ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/25' : 'bg-zinc-900 text-zinc-600 border border-zinc-800'
          }`}>
            <Check className="w-3 h-3" />
            <span className="hidden sm:inline">{isAdding ? 'Tillagd!' : 'I samling'}</span>
          </div>
        ) : (
          <button
            onClick={onToggleDrop}
            className={`flex items-center gap-1 px-2.5 py-1.5 rounded-xl text-[11px] font-bold shrink-0 transition cursor-pointer ${
              showDrop
                ? 'bg-brand-red text-white shadow-sm shadow-brand-red/30'
                : 'bg-zinc-900 border border-zinc-800 text-zinc-500 hover:text-brand-red hover:border-brand-red/40'
            }`}
          >
            <Plus className="w-3.5 h-3.5" />
            <span className="hidden sm:inline">Lägg till</span>
            <ChevronDown className={`w-3 h-3 transition-transform ${showDrop ? 'rotate-180' : ''}`} />
          </button>
        )}
      </div>

      {/* Lägg-till-panel */}
      {showDrop && !inLibrary && (
        <div className="border-t border-zinc-800/60 bg-zinc-950/50 p-3 space-y-3">
          <div className="grid grid-cols-4 gap-1.5">
            {STATUS_OPTIONS.map((opt) => {
              const active = addStatus === opt.value;
              return (
                <button key={opt.label} onClick={() => onSetStatus(opt.value)}
                  className={`flex flex-col items-center gap-1 py-2.5 rounded-xl text-[10px] font-bold transition cursor-pointer ${
                    active ? 'bg-brand-red/15 text-red-300 border border-brand-red/30' : 'bg-zinc-900/80 border border-zinc-800 text-zinc-600 hover:text-zinc-300'
                  }`}
                >
                  <span className="text-sm">{opt.icon}</span>
                  <span>{opt.label}</span>
                </button>
              );
            })}
          </div>

          {addStatus === 'completed' && (
            <div className="flex items-center gap-2">
              <Calendar className="w-3.5 h-3.5 text-zinc-600 shrink-0" />
              <select
                value={addCompletedYear ?? ''}
                onChange={(e) => onSetYear(e.target.value ? parseInt(e.target.value) : null)}
                className="flex-1 bg-zinc-900 border border-zinc-800 text-zinc-300 text-xs rounded-xl px-3 py-1.5 focus:outline-none cursor-pointer"
              >
                <option value="">Klarat år okänt</option>
                {Array.from({ length: CY - 1979 }, (_, i) => CY - i).map((y) => (
                  <option key={y} value={y}>{y}</option>
                ))}
              </select>
            </div>
          )}

          <button onClick={onConfirmAdd}
            className="w-full py-2.5 rounded-xl bg-brand-red hover:bg-red-700 text-white text-xs font-bold transition cursor-pointer flex items-center justify-center gap-2 shadow-md shadow-brand-red/15"
          >
            <Plus className="w-3.5 h-3.5" /> Lägg till i biblioteket
          </button>
        </div>
      )}
    </div>
  );
}

