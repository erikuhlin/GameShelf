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
  genre: string;
  platform: string;
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
  filters?: Partial<AdvancedFilters> & { preset?: string };
}

const EMPTY_FILTERS: AdvancedFilters = {
  genre: '',
  platform: '',
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
    if (filters.genre) count++;
    if (filters.platform) count++;
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
    if (f.genre) params.set('genre', f.genre.toLowerCase());
    if (f.platform) params.set('platform', f.platform);
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
      const { preset, ...filterPart } = suggestion.filters;
      setFilters((prev) => ({ ...prev, ...filterPart }));
      setActivePreset(preset || null);
      if (Object.keys(filterPart).length > 0 || preset) {
        setShowFilters(true);
      }
    }
  };

  const resetFilters = () => {
    setFilters(EMPTY_FILTERS);
    setActivePreset(null);
  };

  if (!isOpen) return null;

  // Aktiva resultat att visa (antingen fritext-IGDB eller filter/preset-resultat)
  const displayResults = query.trim() ? igdbResults : filterResults;
  const isLoadingResults = query.trim() ? isLoadingIgdb : isLoadingFilters;

  const currentResults = displayResults.filter((r) =>
    filters.hideOwned ? !isGameInLibrary(r.id, r.title || r.name) : true
  );

  return (
    <div
      className="fixed inset-0 z-50 flex items-start justify-center p-3 sm:p-6 sm:pt-12 bg-black/85 backdrop-blur-md animate-in fade-in duration-150"
      onClick={onClose}
    >
      <div
        className={`w-full bg-[#111216] border border-zinc-800/90 rounded-3xl shadow-2xl overflow-hidden flex flex-col max-h-[94vh] animate-in zoom-in-95 duration-150 transition-all ${showFilters ? 'max-w-5xl' : 'max-w-2xl'}`}
        onClick={(e) => e.stopPropagation()}
      >
        {/* ── Search Input Row ── */}
        <div className="relative flex items-center px-4 sm:px-5 py-3.5 border-b border-zinc-800/90 bg-zinc-950/60 shrink-0">
          <Search className="w-5 h-5 text-zinc-400 shrink-0 mr-3" />
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
            className="flex-1 bg-transparent text-sm sm:text-base text-zinc-100 placeholder-zinc-500 focus:outline-none"
          />

          <div className="flex items-center gap-2">
            {/* Filter Toggle */}
            <button
              onClick={() => setShowFilters((v) => !v)}
              className={`relative flex items-center gap-1.5 px-2.5 py-1.5 rounded-xl text-xs font-semibold transition cursor-pointer ${
                showFilters || activeFilterCount > 0
                  ? 'bg-brand-red/20 text-brand-red border border-brand-red/40'
                  : 'bg-zinc-900 border border-zinc-800 text-zinc-400 hover:text-zinc-200'
              }`}
              title="Avancerade filter"
            >
              <SlidersHorizontal className="w-3.5 h-3.5" />
              <span className="hidden sm:inline">Filter</span>
              {activeFilterCount > 0 && (
                <span className="absolute -top-1 -right-1 w-4 h-4 rounded-full bg-brand-red text-white text-[9px] flex items-center justify-center font-bold">
                  {activeFilterCount}
                </span>
              )}
            </button>

            {query ? (
              <button
                onClick={() => { setQuery(''); inputRef.current?.focus(); }}
                className="p-1 text-zinc-500 hover:text-zinc-200 transition"
              >
                <X className="w-4 h-4" />
              </button>
            ) : (
              <kbd className="hidden lg:inline-flex items-center px-1.5 py-0.5 rounded bg-zinc-800 text-[10px] font-mono text-zinc-400 border border-zinc-700/60">
                ESC
              </kbd>
            )}
          </div>
        </div>

        {/* ── Source Tabs (when query active) ── */}
        {query.trim() && (
          <div className="flex items-center gap-1.5 px-4 sm:px-5 py-2 border-b border-zinc-800/60 bg-zinc-900/30 overflow-x-auto scrollbar-none shrink-0">
            {(
              [
                { id: 'all', label: 'Alla' },
                { id: 'library', label: `Mitt bibliotek (${libraryResults.length})`, icon: <Library className="w-3.5 h-3.5" /> },
                { id: 'igdb', label: `IGDB (${igdbResults.length})`, icon: <Globe className="w-3.5 h-3.5" /> },
                ...(newsResults.length > 0 ? [{ id: 'news', label: `Nyheter (${newsResults.length})`, icon: <Newspaper className="w-3.5 h-3.5" /> }] : []),
              ] as { id: string; label: string; icon?: React.ReactNode }[]
            ).map((tab) => (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id as typeof activeTab)}
                className={`flex items-center gap-1.5 px-3 py-1 rounded-xl text-xs font-semibold transition whitespace-nowrap cursor-pointer ${
                  activeTab === tab.id
                    ? 'bg-white text-zinc-950 shadow-sm'
                    : 'text-zinc-400 hover:text-zinc-200'
                }`}
              >
                {tab.icon}
                <span>{tab.label}</span>
              </button>
            ))}
          </div>
        )}

        {/* ── Main Body: sidebar + results ── */}
        <div className="flex flex-1 min-h-0">

          {/* ── LEFT: Filter Sidebar ── */}
          {showFilters && (
            <div className="w-56 sm:w-64 shrink-0 border-r border-zinc-800/80 bg-zinc-950/60 overflow-y-auto scrollbar-thin scrollbar-thumb-zinc-800 p-4 space-y-5">

              {/* Tidsmaskin */}
              <div className="space-y-2">
                <div className="flex items-center gap-1.5 text-[11px] font-bold text-zinc-400 uppercase tracking-wider">
                  <Hourglass className="w-3.5 h-3.5 text-amber-400" />
                  <span>Tidsmaskin</span>
                </div>
                <div className="flex items-center gap-1.5">
                  <input
                    type="number"
                    value={filters.yearFrom}
                    onChange={(e) => setFilters((f) => ({ ...f, yearFrom: e.target.value }))}
                    placeholder="Från"
                    min="1970"
                    max={CURRENT_YEAR}
                    className="w-full bg-zinc-900 border border-zinc-700 focus:border-amber-400 rounded-xl px-2 py-1.5 text-xs text-white focus:outline-none"
                  />
                  <span className="text-zinc-500 text-xs shrink-0">–</span>
                  <input
                    type="number"
                    value={filters.yearTo}
                    onChange={(e) => setFilters((f) => ({ ...f, yearTo: e.target.value }))}
                    placeholder="Till"
                    min="1970"
                    max={CURRENT_YEAR}
                    className="w-full bg-zinc-900 border border-zinc-700 focus:border-amber-400 rounded-xl px-2 py-1.5 text-xs text-white focus:outline-none"
                  />
                </div>
                <div className="flex flex-col gap-1">
                  {ERA_PRESETS.map((era) => {
                    const active = filters.yearFrom === era.yearFrom && filters.yearTo === era.yearTo;
                    return (
                      <button
                        key={era.label}
                        onClick={() =>
                          setFilters((f) => ({
                            ...f,
                            yearFrom: active ? '' : era.yearFrom,
                            yearTo: active ? '' : era.yearTo,
                          }))
                        }
                        className={`px-2.5 py-1.5 rounded-xl text-[11px] font-semibold transition cursor-pointer text-left ${
                          active
                            ? 'bg-amber-500 text-zinc-950'
                            : 'bg-zinc-900 border border-zinc-800 text-zinc-400 hover:text-zinc-200 hover:border-zinc-700'
                        }`}
                      >
                        {era.label}
                      </button>
                    );
                  })}
                </div>
              </div>

              {/* Genre */}
              <div className="space-y-1.5">
                <span className="text-[11px] font-bold text-zinc-400 uppercase tracking-wider">Genre</span>
                <div className="flex flex-col gap-1">
                  {GENRES.map((g) => {
                    const active = filters.genre === g;
                    return (
                      <button
                        key={g}
                        onClick={() => setFilters((f) => ({ ...f, genre: active ? '' : g }))}
                        className={`px-2.5 py-1.5 rounded-xl text-[11px] font-semibold transition cursor-pointer text-left ${
                          active
                            ? 'bg-brand-red text-white'
                            : 'bg-zinc-900 border border-zinc-800 text-zinc-400 hover:text-zinc-200'
                        }`}
                      >
                        {g === 'Role-playing (RPG)' ? 'RPG' : g}
                      </button>
                    );
                  })}
                </div>
              </div>

              {/* Plattform */}
              <div className="space-y-1.5">
                <span className="text-[11px] font-bold text-zinc-400 uppercase tracking-wider">Plattform</span>
                <div className="flex flex-col gap-1">
                  {PLATFORM_GROUPS.map((p) => {
                    const active = filters.platform === p.value;
                    return (
                      <button
                        key={p.value}
                        onClick={() => setFilters((f) => ({ ...f, platform: active ? '' : p.value }))}
                        className={`px-2.5 py-1.5 rounded-xl text-[11px] font-semibold transition cursor-pointer text-left ${
                          active
                            ? 'bg-blue-600 text-white'
                            : 'bg-zinc-900 border border-zinc-800 text-zinc-400 hover:text-zinc-200'
                        }`}
                      >
                        {p.label}
                      </button>
                    );
                  })}
                </div>
              </div>

              {/* Betyg */}
              <div className="space-y-1.5">
                <span className="text-[11px] font-bold text-zinc-400 uppercase tracking-wider">Minst betyg</span>
                <div className="flex flex-col gap-1">
                  {RATING_OPTIONS.map((r) => {
                    const active = filters.minRating === r.value;
                    return (
                      <button
                        key={r.value}
                        onClick={() => setFilters((f) => ({ ...f, minRating: active ? 0 : r.value }))}
                        className={`px-2.5 py-1.5 rounded-xl text-[11px] font-semibold transition cursor-pointer text-left ${
                          active
                            ? 'bg-amber-500 text-zinc-950'
                            : 'bg-zinc-900 border border-zinc-800 text-zinc-400 hover:text-zinc-200'
                        }`}
                      >
                        {r.label}
                      </button>
                    );
                  })}
                </div>
              </div>

              {/* Utvecklare */}
              <div className="space-y-1.5">
                <span className="text-[11px] font-bold text-zinc-400 uppercase tracking-wider">Studio</span>
                <input
                  type="text"
                  value={filters.developer}
                  onChange={(e) => setFilters((f) => ({ ...f, developer: e.target.value }))}
                  placeholder="T.ex. FromSoftware..."
                  className="w-full bg-zinc-900 border border-zinc-700 focus:border-brand-red rounded-xl px-2.5 py-1.5 text-xs text-white focus:outline-none placeholder-zinc-600"
                />
                <div className="flex flex-col gap-1">
                  {KNOWN_DEVELOPERS.map((dev) => (
                    <button
                      key={dev}
                      onClick={() => setFilters((f) => ({ ...f, developer: f.developer === dev ? '' : dev }))}
                      className={`px-2.5 py-1.5 rounded-xl text-[11px] font-semibold transition cursor-pointer text-left ${
                        filters.developer === dev
                          ? 'bg-brand-red text-white'
                          : 'bg-zinc-900 border border-zinc-800 text-zinc-500 hover:text-zinc-300'
                      }`}
                    >
                      {dev}
                    </button>
                  ))}
                </div>
              </div>

              {/* Sortering */}
              <div className="space-y-1.5">
                <span className="text-[11px] font-bold text-zinc-400 uppercase tracking-wider">Sortera</span>
                <select
                  value={filters.sort}
                  onChange={(e) => setFilters((f) => ({ ...f, sort: e.target.value as AdvancedFilters['sort'] }))}
                  className="w-full bg-zinc-900 border border-zinc-700 text-zinc-200 text-xs rounded-xl px-2.5 py-1.5 focus:outline-none cursor-pointer"
                >
                  <option value="popularity">Popularitet</option>
                  <option value="rating">Betyg</option>
                  <option value="newest">Nyast</option>
                  <option value="oldest">Äldst</option>
                </select>
              </div>

              {/* Dölj ägda */}
              <label className="flex items-center gap-2 text-[11px] text-zinc-400 cursor-pointer select-none">
                <input
                  type="checkbox"
                  checked={filters.hideOwned}
                  onChange={(e) => setFilters((f) => ({ ...f, hideOwned: e.target.checked }))}
                  className="accent-brand-red rounded"
                />
                Dölj spel jag äger
              </label>

              {/* Rensa */}
              {(activeFilterCount > 0 || activePreset) && (
                <button
                  onClick={resetFilters}
                  className="w-full text-[11px] text-zinc-500 hover:text-brand-red transition cursor-pointer flex items-center justify-center gap-1 py-1.5 rounded-xl border border-zinc-800 hover:border-brand-red/30"
                >
                  <X className="w-3 h-3" />
                  Rensa alla filter
                </button>
              )}
            </div>
          )}

          {/* ── RIGHT: Results ── */}
          <div className="flex-1 overflow-y-auto p-4 sm:p-5 space-y-6 scrollbar-thin scrollbar-thumb-zinc-800">

            {/* Empty state: Smart suggestions */}
            {!query.trim() && !hasAnyFilter && (
              <div className="space-y-5">
                {recentSearches.length > 0 && (
                  <div>
                    <div className="flex items-center gap-1.5 text-[11px] font-bold text-zinc-400 uppercase tracking-wider mb-2.5">
                      <Clock className="w-3.5 h-3.5" />
                      <span>Senaste sökningar</span>
                    </div>
                    <div className="flex flex-wrap gap-2">
                      {recentSearches.map((term) => (
                        <button
                          key={term}
                          onClick={() => { setQuery(term); saveSearchTerm(term); }}
                          className="group flex items-center gap-2 px-3 py-1.5 rounded-xl bg-zinc-900/90 border border-zinc-800 text-xs text-zinc-300 hover:text-white hover:border-zinc-700 transition cursor-pointer"
                        >
                          <span>{term}</span>
                          <X
                            className="w-3 h-3 text-zinc-500 group-hover:text-zinc-300 transition"
                            onClick={(e) => removeRecentSearch(e, term)}
                          />
                        </button>
                      ))}
                    </div>
                  </div>
                )}

                <div>
                  <div className="flex items-center gap-1.5 text-[11px] font-bold text-zinc-400 uppercase tracking-wider mb-3">
                    <Sparkles className="w-3.5 h-3.5 text-amber-400" />
                    <span>
                      {userProfile?.username ? `Förslag för ${userProfile.username}` : 'Smarta sökförslag'}
                    </span>
                  </div>
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                    {personalSuggestions.map((s) => (
                      <button
                        key={s.label}
                        onClick={() => applySuggestion(s)}
                        className="flex items-center gap-3 p-3 rounded-2xl bg-zinc-900/60 border border-zinc-800/80 hover:border-brand-red/40 hover:bg-zinc-900 transition cursor-pointer text-left group"
                      >
                        <div className="w-9 h-9 rounded-xl bg-zinc-800 flex items-center justify-center text-lg shrink-0 group-hover:scale-110 transition-transform">
                          {s.icon}
                        </div>
                        <div className="min-w-0">
                          <div className="text-xs font-bold text-white group-hover:text-brand-red transition truncate">
                            {s.label}
                          </div>
                          <div className="text-[11px] text-zinc-500 truncate">{s.description}</div>
                        </div>
                      </button>
                    ))}
                  </div>
                </div>
              </div>
            )}

            {/* Filter/preset results (no query) */}
            {!query.trim() && hasAnyFilter && (
              <div>
                <div className="flex items-center justify-between text-[11px] font-bold text-zinc-400 uppercase tracking-wider mb-3">
                  <div className="flex items-center gap-2">
                    <Globe className="w-3.5 h-3.5 text-brand-red" />
                    <span>{isLoadingFilters ? 'Söker...' : `Resultat (${currentResults.length}${hasMore ? '+' : ''})`}</span>
                  </div>
                  {isLoadingFilters && <Loader2 className="w-4 h-4 animate-spin text-brand-red" />}
                </div>

                {isLoadingFilters && currentResults.length === 0 && (
                  <div className="flex items-center justify-center py-12 text-zinc-500">
                    <Loader2 className="w-6 h-6 animate-spin" />
                  </div>
                )}

                <div className="space-y-2">
                  {currentResults.map((result) => {
                    const inLibrary = isGameInLibrary(result.id, result.title);
                    const inLib = games.find((g) => g.igdb_id === result.id);
                    const isAdding = addingGameId === result.id;
                    const showDrop = showAddDropdown === result.id;
                    return (
                      <GameResultCard
                        key={result.id}
                        result={result}
                        inLibrary={inLibrary}
                        inLibGame={inLib}
                        isAdding={isAdding}
                        showDrop={showDrop}
                        addStatus={addStatus}
                        addCompletedYear={addCompletedYear}
                        onSelectGame={() => { if (inLib) { onSelectGame(inLib); onClose(); } }}
                        onToggleDrop={() => setShowAddDropdown(showDrop ? null : result.id)}
                        onSetStatus={setAddStatus}
                        onSetYear={setAddCompletedYear}
                        onConfirmAdd={() => handleAddGame(result, addStatus, addCompletedYear)}
                      />
                    );
                  })}

                  {!isLoadingFilters && currentResults.length === 0 && (
                    <p className="text-center py-8 text-xs text-zinc-500">
                      Inga spel matchade dina filter. Prova att justera inställningarna.
                    </p>
                  )}

                  {/* Ladda fler */}
                  {hasMore && !isLoadingFilters && (
                    <button
                      onClick={handleLoadMore}
                      disabled={isLoadingMore}
                      className="w-full py-2.5 rounded-2xl border border-zinc-700 text-xs font-semibold text-zinc-400 hover:text-white hover:border-zinc-600 hover:bg-zinc-900 transition cursor-pointer flex items-center justify-center gap-2 mt-2"
                    >
                      {isLoadingMore ? (
                        <><Loader2 className="w-3.5 h-3.5 animate-spin" />Laddar fler...</>
                      ) : (
                        <>Ladda fler resultat<ChevronDown className="w-3.5 h-3.5" /></>
                      )}
                    </button>
                  )}
                </div>
              </div>
            )}

            {/* Query-based results */}
            {query.trim() && (
              <div className="space-y-5">
                {/* Library matches */}
                {(activeTab === 'all' || activeTab === 'library') && libraryResults.length > 0 && (
                  <div>
                    <div className="flex items-center gap-2 text-[11px] font-bold text-zinc-400 uppercase tracking-wider mb-3">
                      <Library className="w-3.5 h-3.5 text-emerald-400" />
                      <span>I ditt bibliotek ({libraryResults.length})</span>
                    </div>
                    <div className="space-y-2">
                      {libraryResults.map((game) => (
                        <div
                          key={game.id}
                          onClick={() => { saveSearchTerm(query); onSelectGame(game); onClose(); }}
                          className="flex items-center justify-between p-2.5 sm:p-3 rounded-2xl bg-zinc-900/60 border border-zinc-800/80 hover:border-zinc-700 hover:bg-zinc-900 cursor-pointer group transition"
                        >
                          <div className="flex items-center gap-3 min-w-0">
                            <div className="w-10 h-14 rounded-xl overflow-hidden bg-zinc-950 shrink-0 border border-zinc-800">
                              {game.cover_url ? (
                                <img src={game.cover_url} alt={game.title} className="w-full h-full object-cover group-hover:scale-105 transition" />
                              ) : (
                                <div className="w-full h-full flex items-center justify-center">
                                  <Gamepad className="w-4 h-4 text-zinc-600" />
                                </div>
                              )}
                            </div>
                            <div className="min-w-0">
                              <h4 className="text-sm font-bold text-zinc-100 group-hover:text-brand-red transition truncate">{game.title}</h4>
                              <div className="flex items-center gap-2 mt-0.5">
                                <StatusBadge game={game} />
                                {game.release_year && <span className="text-[11px] text-zinc-500">{game.release_year}</span>}
                              </div>
                            </div>
                          </div>
                          <ArrowRight className="w-4 h-4 text-zinc-500 group-hover:text-white transition shrink-0 ml-2" />
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {/* Studio shortcut */}
                {query.trim().length >= 2 && onOpenCompany && (
                  <div className="bg-zinc-900/60 border border-zinc-800/80 rounded-2xl p-3 sm:p-4 hover:border-brand-red/40 transition">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-3 min-w-0">
                        <div className="w-10 h-10 rounded-xl bg-brand-red/10 border border-brand-red/20 flex items-center justify-center text-brand-red shrink-0">
                          <Building2 className="w-5 h-5" />
                        </div>
                        <div className="min-w-0">
                          <div className="text-[11px] font-bold text-zinc-400 uppercase tracking-wider">Studio & Utgivare</div>
                          <div className="text-sm font-bold text-white truncate">"{query.trim()}"</div>
                        </div>
                      </div>
                      <button
                        onClick={() => { saveSearchTerm(query.trim()); onClose(); onOpenCompany(0, query.trim(), 'developer'); }}
                        className="px-3.5 py-1.5 rounded-xl bg-brand-red hover:bg-red-700 text-white text-xs font-bold transition flex items-center gap-1.5 cursor-pointer shrink-0 ml-3"
                      >
                        Öppna studio
                        <ArrowRight className="w-3.5 h-3.5" />
                      </button>
                    </div>
                  </div>
                )}

                {/* IGDB Results */}
                {(activeTab === 'all' || activeTab === 'igdb') && (
                  <div>
                    <div className="flex items-center justify-between text-[11px] font-bold text-zinc-400 uppercase tracking-wider mb-3">
                      <div className="flex items-center gap-2">
                        <Globe className="w-3.5 h-3.5 text-brand-red" />
                        <span>Hitta på IGDB{igdbResults.length > 0 ? ` (${igdbResults.length}${hasMore ? '+' : ''})` : ''}</span>
                      </div>
                      {isLoadingIgdb && (
                        <div className="flex items-center gap-1 text-zinc-500">
                          <Loader2 className="w-3.5 h-3.5 animate-spin text-brand-red" />
                          <span>Söker...</span>
                        </div>
                      )}
                    </div>

                    {igdbResults.length > 0 ? (
                      <div className="space-y-2">
                        {igdbResults.map((result) => {
                          const inLibrary = isGameInLibrary(result.id, result.name);
                          const inLib = games.find((g) => g.igdb_id === result.id);
                          const isAdding = addingGameId === result.id;
                          const showDrop = showAddDropdown === result.id;
                          const asResult = {
                            id: result.id,
                            title: result.name,
                            cover_url: result.cover?.url,
                            platforms: (result.platforms || []).map((p: any) => p.name),
                            genres: (result.genres || []).map((g: any) => g.name),
                            developers: (result.involved_companies || []).filter((c: any) => c.developer).map((c: any) => c.company.name),
                            release_year: result.first_release_date ? new Date(result.first_release_date * 1000).getFullYear() : null,
                            first_release_date: result.first_release_date || null,
                            igdb_rating: result.total_rating ? Math.round((result.total_rating / 10) * 10) / 10 : null,
                          };
                          return (
                            <GameResultCard
                              key={result.id}
                              result={asResult}
                              inLibrary={inLibrary}
                              inLibGame={inLib}
                              isAdding={isAdding}
                              showDrop={showDrop}
                              addStatus={addStatus}
                              addCompletedYear={addCompletedYear}
                              onSelectGame={() => {
                                if (inLib) { saveSearchTerm(query); onSelectGame(inLib); onClose(); }
                                else { saveSearchTerm(query); onSelectGame(convertResultToGame(asResult)); onClose(); }
                              }}
                              onToggleDrop={() => setShowAddDropdown(showDrop ? null : result.id)}
                              onSetStatus={setAddStatus}
                              onSetYear={setAddCompletedYear}
                              onConfirmAdd={() => handleAddGame(asResult, addStatus, addCompletedYear)}
                            />
                          );
                        })}

                        {/* Ladda fler – IGDB */}
                        {hasMore && !isLoadingIgdb && (
                          <button
                            onClick={handleLoadMore}
                            disabled={isLoadingMore}
                            className="w-full py-2.5 rounded-2xl border border-zinc-700 text-xs font-semibold text-zinc-400 hover:text-white hover:border-zinc-600 hover:bg-zinc-900 transition cursor-pointer flex items-center justify-center gap-2 mt-2"
                          >
                            {isLoadingMore ? (
                              <><Loader2 className="w-3.5 h-3.5 animate-spin" />Laddar fler...</>
                            ) : (
                              <>Ladda fler resultat<ChevronDown className="w-3.5 h-3.5" /></>
                            )}
                          </button>
                        )}
                      </div>
                    ) : (
                      !isLoadingIgdb && query.trim().length > 1 && (
                        <p className="text-xs text-zinc-500 py-3 text-center">
                          Inga träffar på IGDB för &ldquo;{query}&rdquo;.
                        </p>
                      )
                    )}
                  </div>
                )}

                {/* News */}
                {(activeTab === 'all' || activeTab === 'news') && newsResults.length > 0 && (
                  <div>
                    <div className="flex items-center gap-2 text-[11px] font-bold text-zinc-400 uppercase tracking-wider mb-3">
                      <Newspaper className="w-3.5 h-3.5 text-rose-400" />
                      <span>Nyheter ({newsResults.length})</span>
                    </div>
                    <div className="space-y-2">
                      {newsResults.map((item) => (
                        <a
                          key={item.id}
                          href={item.link}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="flex items-center justify-between p-3 rounded-2xl bg-zinc-900/60 border border-zinc-800/80 hover:border-zinc-700 hover:bg-zinc-900 transition group"
                        >
                          <div className="min-w-0 pr-3">
                            <div className="flex items-center gap-2 text-[10px] text-zinc-500 mb-1">
                              <span className="font-bold text-zinc-300">{item.source}</span>
                              <span>•</span>
                              <span>{new Date(item.published).toLocaleDateString('sv-SE')}</span>
                            </div>
                            <h5 className="text-xs sm:text-sm font-semibold text-zinc-100 group-hover:text-brand-red transition line-clamp-1">
                              {item.title}
                            </h5>
                          </div>
                          <ExternalLink className="w-4 h-4 text-zinc-500 group-hover:text-white transition shrink-0" />
                        </a>
                      ))}
                    </div>
                  </div>
                )}

                {/* No results */}
                {!isLoadingIgdb && !isLoadingFilters && libraryResults.length === 0 && igdbResults.length === 0 && newsResults.length === 0 && (
                  <div className="text-center py-12 text-zinc-500">
                    <Search className="w-8 h-8 mx-auto mb-2 opacity-50" />
                    <p className="text-sm font-medium">Inga träffar för &ldquo;{query}&rdquo;</p>
                    <p className="text-xs text-zinc-600 mt-1">Prova en annan titel, utvecklare eller konsol.</p>
                  </div>
                )}
              </div>
            )}
          </div>
        </div>

        {/* ── Footer ── */}
        <div className="px-5 py-3 border-t border-zinc-800/80 bg-zinc-950/60 flex items-center justify-between text-[11px] text-zinc-500 shrink-0">
          <div className="flex items-center gap-3">
            <span className="flex items-center gap-1">
              <kbd className="px-1.5 py-0.5 rounded bg-zinc-900 border border-zinc-800 text-zinc-300 font-mono text-[10px]">ESC</kbd>{' '}Stäng
            </span>
            <span className="hidden sm:flex items-center gap-1">
              <kbd className="px-1.5 py-0.5 rounded bg-zinc-900 border border-zinc-800 text-zinc-300 font-mono text-[10px]">⌘K</kbd>{' '}Öppna
            </span>
          </div>
          <span>Gameshelf Sök & Lägg till</span>
        </div>
      </div>
    </div>
  );
}
// ── GameResultCard sub-component ──
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

const STATUS_OPTIONS: { label: string; value: PlayStatus; icon: string; isWishlist?: boolean }[] = [
  { label: 'Backlog', value: 'notStarted', icon: '📋' },
  { label: 'Spelar nu', value: 'playing', icon: '▶️' },
  { label: 'Genomspelat', value: 'completed', icon: '🏆' },
  { label: 'Önskelista', value: 'notStarted', icon: '🎁', isWishlist: true },
];

const CURRENT_YEAR2 = new Date().getFullYear();

function GameResultCard({
  result,
  inLibrary,
  inLibGame,
  isAdding,
  showDrop,
  addStatus,
  addCompletedYear,
  onSelectGame,
  onToggleDrop,
  onSetStatus,
  onSetYear,
  onConfirmAdd,
}: GameResultCardProps) {
  return (
    <div className="rounded-2xl bg-zinc-900/60 border border-zinc-800/80 hover:border-zinc-700 transition overflow-hidden">
      <div className="flex items-center p-2.5 sm:p-3 gap-3">
        {/* Cover */}
        <div
          onClick={onSelectGame}
          className="w-10 h-14 rounded-xl overflow-hidden bg-zinc-950 shrink-0 border border-zinc-800 cursor-pointer"
        >
          {result.cover_url ? (
            <img src={result.cover_url} alt={result.title} className="w-full h-full object-cover" />
          ) : (
            <div className="w-full h-full flex items-center justify-center">
              <Gamepad className="w-4 h-4 text-zinc-600" />
            </div>
          )}
        </div>

        {/* Info */}
        <div onClick={onSelectGame} className="flex-1 min-w-0 cursor-pointer">
          <h4 className="text-sm font-bold text-zinc-100 hover:text-brand-red transition truncate">
            {result.title}
          </h4>
          <p className="text-[11px] text-zinc-400 mt-0.5 truncate">
            {result.release_year || 'TBA'}
            {result.genres?.[0] && ` • ${result.genres[0]}`}
            {result.igdb_rating && (
              <span className="text-amber-400 ml-1">⭐ {result.igdb_rating}</span>
            )}
          </p>
          {result.platforms && result.platforms.length > 0 && (
            <p className="text-[10px] text-zinc-600 truncate mt-0.5">
              {result.platforms.slice(0, 3).join(' • ')}
            </p>
          )}
        </div>

        {/* Action */}
        {inLibrary ? (
          <div className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-xl bg-emerald-950/40 border border-emerald-900/50 text-emerald-400 text-xs font-semibold shrink-0">
            <Check className="w-3.5 h-3.5" />
            <span className="hidden sm:inline">I samling</span>
          </div>
        ) : isAdding ? (
          <div className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-xl bg-emerald-950/40 border border-emerald-900/50 text-emerald-400 text-xs font-semibold shrink-0">
            <Check className="w-3.5 h-3.5" />
            <span className="hidden sm:inline">Tillagd!</span>
          </div>
        ) : (
          <button
            onClick={onToggleDrop}
            className={`flex items-center gap-1.5 px-2.5 py-1.5 rounded-xl text-xs font-semibold transition cursor-pointer shrink-0 ${
              showDrop
                ? 'bg-brand-red text-white'
                : 'bg-zinc-800 hover:bg-brand-red text-zinc-200 hover:text-white border border-zinc-700 hover:border-brand-red'
            }`}
          >
            <Plus className="w-3.5 h-3.5" />
            <span>Lägg till</span>
            <ChevronDown className={`w-3 h-3 transition-transform ${showDrop ? 'rotate-180' : ''}`} />
          </button>
        )}
      </div>

      {/* Add Dropdown */}
      {showDrop && !inLibrary && (
        <div className="border-t border-zinc-800/60 bg-zinc-950/80 p-3 space-y-2.5">
          {/* Status buttons */}
          <div className="grid grid-cols-4 gap-1.5">
            {STATUS_OPTIONS.map((opt) => (
              <button
                key={opt.label}
                onClick={() => onSetStatus(opt.value)}
                className={`flex flex-col items-center gap-1 py-2 rounded-xl text-[11px] font-semibold transition cursor-pointer ${
                  addStatus === opt.value
                    ? 'bg-brand-red/20 text-brand-red border border-brand-red/50'
                    : 'bg-zinc-900 border border-zinc-800 text-zinc-400 hover:text-zinc-200'
                }`}
              >
                <span className="text-sm">{opt.icon}</span>
                <span>{opt.label}</span>
              </button>
            ))}
          </div>

          {/* Klarat år (om genomspelat) */}
          {addStatus === 'completed' && (
            <div className="flex items-center gap-2">
              <Calendar className="w-3.5 h-3.5 text-zinc-400 shrink-0" />
              <span className="text-[11px] text-zinc-400">Klarat år:</span>
              <select
                value={addCompletedYear ?? ''}
                onChange={(e) => onSetYear(e.target.value ? parseInt(e.target.value) : null)}
                className="flex-1 bg-zinc-900 border border-zinc-700 text-zinc-200 text-xs rounded-xl px-3 py-1.5 focus:outline-none cursor-pointer"
              >
                <option value="">Osäker / Lämna tomt</option>
                {Array.from({ length: CURRENT_YEAR2 - 1979 }, (_, i) => CURRENT_YEAR2 - i).map((y) => (
                  <option key={y} value={y}>{y}</option>
                ))}
              </select>
            </div>
          )}

          {/* Bekräfta */}
          <button
            onClick={onConfirmAdd}
            className="w-full py-2 rounded-xl bg-brand-red hover:bg-red-700 text-white text-xs font-bold transition cursor-pointer flex items-center justify-center gap-2"
          >
            <Plus className="w-3.5 h-3.5" />
            Lägg till i biblioteket
          </button>
        </div>
      )}
    </div>
  );
}
