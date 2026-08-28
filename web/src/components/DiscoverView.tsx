'use client';

import React, { useState, useEffect, useMemo } from 'react';
import { Game, PlayStatus } from '@/types/game';
import { StatusBadge } from './StatusBadge';
import {
  Sparkles,
  Dices,
  Flame,
  Calendar,
  Clock,
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
  TrendingUp,
  Play,
  Filter,
  Bookmark,
  BookmarkCheck,
  Film,
  Monitor,
  LayoutGrid,
  Rows,
  ChevronRight,
  Sparkle,
} from 'lucide-react';

interface DiscoverViewProps {
  games: Game[];
  onSelectGame: (game: Game) => void;
  onAddGame: (game: Game) => void;
  onOpenRouletteModal?: () => void;
  onOpenSearchWithQuery?: (query: string) => void;
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

const GENRES = [
  'Role-playing (RPG)',
  'Action',
  'Adventure',
  'Shooter',
  'Indie',
  'Strategy',
  'Platform',
  'Racing',
  'Fighting',
  'Horror',
  'Simulator',
  'Puzzle',
  'Sport',
];

const PLATFORMS = ['Alla plattformar', 'PlayStation', 'Xbox', 'Nintendo', 'PC'];

export function DiscoverView({
  games,
  onSelectGame,
  onAddGame,
  onOpenSearchWithQuery,
}: DiscoverViewProps) {
  const [activeTab, setActiveTab] = useState<'discover' | 'news'>('discover');

  // --- Discover Data State ---
  const [trendingGames, setTrendingGames] = useState<Game[]>([]);
  const [isTrendingExpanded, setIsTrendingExpanded] = useState(false);
  const [trendingSort, setTrendingSort] = useState<'popularity' | 'rating' | 'newest'>('popularity');
  const [trendingEra, setTrendingEra] = useState<'recent' | 'prev_gen' | 'classics' | 'all'>('recent');

  const [upcomingGames, setUpcomingGames] = useState<Game[]>([]);
  const [topRatedGames, setTopRatedGames] = useState<Game[]>([]);

  // Genre State
  const [selectedGenre, setSelectedGenre] = useState<string>('Role-playing (RPG)');
  const [genreGames, setGenreGames] = useState<Game[]>([]);
  const [isGenreExpanded, setIsGenreExpanded] = useState(false);
  const [genreSort, setGenreSort] = useState<'popularity' | 'rating' | 'newest'>('popularity');
  const [genreEra, setGenreEra] = useState<'recent' | 'prev_gen' | 'classics' | 'all'>('recent');
  const [genreSearch, setGenreSearch] = useState('');
  const [isLoadingGenre, setIsLoadingGenre] = useState(false);

  const [isLoadingDiscover, setIsLoadingDiscover] = useState(false);

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

  // Hämta data för Utforska (Trending, Upcoming, Top Rated)
  useEffect(() => {
    async function loadDiscoverFeed() {
      setIsLoadingDiscover(true);
      try {
        const [trendRes, upRes, topRes] = await Promise.allSettled([
          fetch(`/api/games/discover?category=trending&sort=${trendingSort}&era=${trendingEra}&limit=40`).then((r) => r.json()),
          fetch('/api/games/discover?category=upcoming&limit=25').then((r) => r.json()),
          fetch('/api/games/discover?category=top_rated&limit=25').then((r) => r.json()),
        ]);

        if (trendRes.status === 'fulfilled' && trendRes.value.results) {
          setTrendingGames(trendRes.value.results);
        }
        if (upRes.status === 'fulfilled' && upRes.value.results) {
          setUpcomingGames(upRes.value.results);
        }
        if (topRes.status === 'fulfilled' && topRes.value.results) {
          setTopRatedGames(topRes.value.results);
        }
      } catch (err) {
        console.error('Error loading discover feed:', err);
      } finally {
        setIsLoadingDiscover(false);
      }
    }

    loadDiscoverFeed();
  }, [trendingSort, trendingEra]);

  // Hämta genrespel vid val eller sortering
  useEffect(() => {
    async function loadGenreGames() {
      setIsLoadingGenre(true);
      try {
        const limit = isGenreExpanded ? 50 : 18;
        const res = await fetch(
          `/api/games/discover?genre=${encodeURIComponent(selectedGenre)}&sort=${genreSort}&era=${genreEra}&limit=${limit}`
        );
        const data = await res.json();
        if (data.results) {
          setGenreGames(data.results);
        }
      } catch (e) {
      } finally {
        setIsLoadingGenre(false);
      }
    }
    loadGenreGames();
  }, [selectedGenre, genreSort, genreEra, isGenreExpanded]);

  // Filtrera genrespel lokalt vid fritextsökning
  const filteredGenreGames = useMemo(() => {
    if (!genreSearch.trim()) return genreGames;
    const q = genreSearch.toLowerCase();
    return genreGames.filter(
      (g) =>
        g.title.toLowerCase().includes(q) ||
        g.developers.some((d) => d.toLowerCase().includes(q)) ||
        g.platforms.some((p) => p.toLowerCase().includes(q))
    );
  }, [genreGames, genreSearch]);

  // Hämta nyheter
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
      candidates = [...trendingGames, ...topRatedGames];
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

  // Hitta om en artikel matchar ett spel i användarens bibliotek
  const findMatchingLibraryGame = (title: string): Game | undefined => {
    const cleanTitle = title.toLowerCase();
    return games.find((g) => {
      const t = g.title.toLowerCase();
      return t.length >= 4 && cleanTitle.includes(t);
    });
  };

  // Unika källor
  const newsSources = useMemo(() => {
    const sources = Array.from(new Set(newsItems.map((n) => n.source))).filter(Boolean);
    return ['Alla källor', ...sources];
  }, [newsItems]);

  // Filtrera nyheter
  const filteredNews = useMemo(() => {
    let result = newsItems;

    // Sökfilter
    if (newsSearch.trim()) {
      const q = newsSearch.toLowerCase();
      result = result.filter(
        (n) =>
          n.title.toLowerCase().includes(q) ||
          n.source.toLowerCase().includes(q) ||
          (n.summary && n.summary.toLowerCase().includes(q))
      );
    }

    // Kategori-filter
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

    // Plattforms-filter
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

    // Käll-filter
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

  return (
    <div className="space-y-6 pb-12 animate-in fade-in duration-200">
      {/* Tab Switcher: Upptäck vs Nyheter */}
      <div className="flex items-center justify-between gap-4 border-b border-zinc-800/80 pb-4">
        <div className="flex items-center bg-zinc-900/90 border border-zinc-800 p-1 rounded-2xl shadow-inner">
          <button
            onClick={() => setActiveTab('discover')}
            className={`flex items-center gap-2 px-5 py-2 rounded-xl text-xs sm:text-sm font-bold transition ${
              activeTab === 'discover'
                ? 'bg-brand-red text-white shadow-md shadow-brand-red/20'
                : 'text-zinc-400 hover:text-zinc-200'
            }`}
          >
            <Sparkles className="w-4 h-4" />
            <span>För dig & Upptäck</span>
          </button>

          <button
            onClick={() => setActiveTab('news')}
            className={`flex items-center gap-2 px-5 py-2 rounded-xl text-xs sm:text-sm font-bold transition ${
              activeTab === 'news'
                ? 'bg-brand-red text-white shadow-md shadow-brand-red/20'
                : 'text-zinc-400 hover:text-zinc-200'
            }`}
          >
            <Newspaper className="w-4 h-4" />
            <span>Spelnyheter & Recensioner</span>
          </button>
        </div>
      </div>

      {activeTab === 'discover' ? (
        <div className="space-y-10">
          {/* 1. Hero: Smart Spelsnurra / Roulette Card */}
          <div className="relative overflow-hidden rounded-3xl bg-gradient-to-br from-zinc-900/90 via-zinc-950/95 to-black border border-zinc-800/90 p-6 sm:p-8 shadow-2xl">
            <div className="relative z-10 flex flex-col md:flex-row items-center justify-between gap-6">
              <div className="max-w-md text-center md:text-left">
                <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-brand-red/10 border border-brand-red/30 text-rose-300 text-xs font-bold uppercase tracking-wider mb-3">
                  <Dices className="w-3.5 h-3.5 text-brand-red" />
                  <span>Smart Spelsnurra</span>
                </div>
                <h3 className="text-2xl sm:text-3xl font-extrabold text-white tracking-tight">
                  Vad ska du spela ikväll?
                </h3>
                <p className="text-xs sm:text-sm text-zinc-400 mt-2 leading-relaxed">
                  Låt slumpen välja bland dina ospelade spel i backloggen eller upptäck nya rekommendationer baserat på vad du gillar.
                </p>

                {/* Mode Selector */}
                <div className="flex flex-wrap items-center justify-center md:justify-start gap-2 mt-4">
                  <button
                    onClick={() => setRouletteMode('library')}
                    className={`px-3 py-1.5 rounded-xl text-xs font-semibold border transition ${
                      rouletteMode === 'library'
                        ? 'bg-white text-zinc-950 border-white shadow-sm'
                        : 'bg-zinc-900 border-zinc-800 text-zinc-400 hover:text-zinc-200'
                    }`}
                  >
                    Mina spel ({games.length})
                  </button>
                  <button
                    onClick={() => setRouletteMode('igdb')}
                    className={`px-3 py-1.5 rounded-xl text-xs font-semibold border transition ${
                      rouletteMode === 'igdb'
                        ? 'bg-white text-zinc-950 border-white shadow-sm'
                        : 'bg-zinc-900 border-zinc-800 text-zinc-400 hover:text-zinc-200'
                    }`}
                  >
                    Upptäck från IGDB
                  </button>
                </div>

                {/* Sub-filter if library */}
                {rouletteMode === 'library' && games.length > 0 && (
                  <div className="flex items-center justify-center md:justify-start gap-1.5 mt-2.5">
                    <button
                      onClick={() => setRouletteFilter('all')}
                      className={`text-[11px] px-2 py-0.5 rounded-lg font-medium transition ${
                        rouletteFilter === 'all'
                          ? 'bg-zinc-800 text-white font-semibold'
                          : 'text-zinc-500 hover:text-zinc-300'
                      }`}
                    >
                      Alla spel
                    </button>
                    <button
                      onClick={() => setRouletteFilter('backlog')}
                      className={`text-[11px] px-2 py-0.5 rounded-lg font-medium transition ${
                        rouletteFilter === 'backlog'
                          ? 'bg-zinc-800 text-white font-semibold'
                          : 'text-zinc-500 hover:text-zinc-300'
                      }`}
                    >
                      Bara Backlog
                    </button>
                    <button
                      onClick={() => setRouletteFilter('playing')}
                      className={`text-[11px] px-2 py-0.5 rounded-lg font-medium transition ${
                        rouletteFilter === 'playing'
                          ? 'bg-zinc-800 text-white font-semibold'
                          : 'text-zinc-500 hover:text-zinc-300'
                      }`}
                    >
                      Bara Pågående
                    </button>
                  </div>
                )}
              </div>

              {/* Roulette Action / Result Card */}
              <div className="flex flex-col items-center gap-4 w-full sm:w-auto">
                {winnerGame ? (
                  <div
                    onClick={() => onSelectGame(winnerGame)}
                    className="flex items-center gap-4 p-3 bg-zinc-900/90 border border-zinc-700/80 rounded-2xl cursor-pointer hover:border-zinc-500 transition shadow-xl w-full max-w-sm group"
                  >
                    <div className="w-16 h-20 rounded-xl overflow-hidden bg-zinc-950 flex-shrink-0 relative border border-zinc-800">
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
                      <h4 className="text-base font-bold text-white truncate group-hover:text-red-400 transition">
                        {winnerGame.title}
                      </h4>
                      <p className="text-xs text-zinc-400 mt-0.5">
                        {winnerGame.release_year ? `${winnerGame.release_year} • ` : ''}
                        {winnerGame.genres?.[0] || 'Spel'}
                      </p>
                    </div>
                    <ArrowRight className="w-5 h-5 text-zinc-400 group-hover:text-white transition" />
                  </div>
                ) : (
                  <div className="w-full max-w-sm h-24 border border-dashed border-zinc-800 rounded-2xl flex items-center justify-center text-zinc-500 text-xs px-6 text-center">
                    Klicka på knappen nedan för att snurra fram ett slumpmässigt spel
                  </div>
                )}

                <button
                  onClick={handleSpinRoulette}
                  disabled={isSpinning || (rouletteMode === 'library' && games.length === 0)}
                  className="w-full sm:w-auto px-8 py-3 bg-gradient-to-r from-brand-red to-rose-600 hover:from-brand-redPressed hover:to-rose-700 disabled:opacity-50 text-white font-bold text-sm rounded-2xl shadow-xl shadow-brand-red/25 transition transform active:scale-95 flex items-center justify-center gap-2"
                >
                  <Dices className={`w-4 h-4 ${isSpinning ? 'animate-spin' : ''}`} />
                  <span>{isSpinning ? 'Snurrar hjulet...' : '🎲 Snurra fram ett spel!'}</span>
                </button>
              </div>
            </div>
          </div>

          {/* 2. Fortsätt spela (om man har aktiva spel) */}
          {currentlyPlaying.length > 0 && (
            <div className="space-y-3">
              <div className="flex items-center gap-2 text-sm font-bold text-white uppercase tracking-wider">
                <Play className="w-4 h-4 text-emerald-400 fill-current" />
                <span>Fortsätt spela</span>
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
                {currentlyPlaying.map((game) => (
                  <div
                    key={game.id}
                    onClick={() => onSelectGame(game)}
                    className="flex items-center gap-3.5 p-3 rounded-2xl bg-zinc-900/70 border border-zinc-800/80 hover:border-zinc-700 cursor-pointer group transition shadow-sm"
                  >
                    <div className="w-12 h-16 rounded-xl overflow-hidden bg-zinc-950 flex-shrink-0 border border-zinc-800">
                      {game.cover_url ? (
                        <img
                          src={game.cover_url}
                          alt={game.title}
                          className="w-full h-full object-cover group-hover:scale-105 transition"
                        />
                      ) : (
                        <div className="w-full h-full flex items-center justify-center">
                          <Gamepad className="w-5 h-5 text-zinc-600" />
                        </div>
                      )}
                    </div>
                    <div className="flex-1 min-w-0">
                      <h4 className="text-sm font-bold text-zinc-100 truncate group-hover:text-red-400 transition">
                        {game.title}
                      </h4>
                      <p className="text-xs text-zinc-400 mt-0.5 truncate">
                        {game.platforms?.[0] || 'Spelas nu'}
                      </p>
                      {game.rating && (
                        <span className="text-[11px] text-amber-400 font-semibold mt-1 block">
                          ⭐ {game.rating}/10
                        </span>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* 3. 🔥 Trendar just nu med Era-filter (Aktuella som standard) */}
          <div className="space-y-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-zinc-800/60 pb-3">
              <div className="flex items-center gap-2.5">
                <div className="p-1.5 rounded-xl bg-brand-red/10 border border-brand-red/30">
                  <Flame className="w-4 h-4 text-brand-red" />
                </div>
                <div>
                  <h3 className="text-base font-bold text-white tracking-tight">Trendar just nu</h3>
                  <p className="text-[11px] text-zinc-400">Aktuella och mest omtalade spelen</p>
                </div>
              </div>

              {/* Tidsperiod, Sortering & Expandera */}
              <div className="flex flex-wrap items-center gap-2">
                {/* Era selector */}
                <div className="flex items-center bg-zinc-900 border border-zinc-800 p-0.5 rounded-xl text-xs">
                  <button
                    onClick={() => setTrendingEra('recent')}
                    className={`px-2.5 py-1 rounded-lg font-medium transition ${
                      trendingEra === 'recent' ? 'bg-zinc-800 text-white font-semibold shadow-sm' : 'text-zinc-400 hover:text-zinc-200'
                    }`}
                  >
                    🔥 Aktuella (2022–2026)
                  </button>
                  <button
                    onClick={() => setTrendingEra('all')}
                    className={`px-2.5 py-1 rounded-lg font-medium transition ${
                      trendingEra === 'all' ? 'bg-zinc-800 text-white font-semibold shadow-sm' : 'text-zinc-400 hover:text-zinc-200'
                    }`}
                  >
                    Klassiker
                  </button>
                </div>

                <select
                  value={trendingSort}
                  onChange={(e) => setTrendingSort(e.target.value as any)}
                  className="bg-zinc-900 border border-zinc-800 text-zinc-300 text-xs rounded-xl px-3 py-1.5 focus:outline-none focus:border-brand-red cursor-pointer"
                >
                  <option value="popularity">Mest omtalade</option>
                  <option value="rating">Högst betyg</option>
                  <option value="newest">Nyast först</option>
                </select>

                <button
                  onClick={() => setIsTrendingExpanded(!isTrendingExpanded)}
                  className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-semibold border transition ${
                    isTrendingExpanded
                      ? 'bg-zinc-800 text-white border-zinc-700'
                      : 'bg-zinc-900 text-zinc-400 hover:text-white border-zinc-800'
                  }`}
                >
                  {isTrendingExpanded ? <Rows className="w-3.5 h-3.5" /> : <LayoutGrid className="w-3.5 h-3.5" />}
                  <span>{isTrendingExpanded ? 'Kompakt' : `Se alla (${trendingGames.length})`}</span>
                </button>
              </div>
            </div>

            {/* Listvisning: Rutnät vid Se mer, eller horisontell scroll */}
            {isTrendingExpanded ? (
              <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-3 sm:gap-4 animate-in fade-in duration-200">
                {trendingGames.map((game, idx) => {
                  const inLibrary = isGameInLibrary(game.igdb_id, game.title);
                  return (
                    <div
                      key={game.id}
                      className="flex flex-col group bg-zinc-900/60 border border-zinc-800/80 rounded-2xl overflow-hidden p-2.5 transition hover:border-zinc-700 shadow-md relative"
                    >
                      {/* Rank Badge */}
                      <div
                        className={`absolute top-4 left-4 z-10 px-2 py-0.5 rounded-lg text-[10px] font-black shadow-lg backdrop-blur-md border ${
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
                        className="w-full aspect-[3/4] rounded-xl overflow-hidden bg-zinc-950 mb-2.5 relative cursor-pointer"
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
                            <Gamepad className="w-8 h-8 text-zinc-600" />
                          </div>
                        )}
                        {game.igdb_rating && (
                          <div className="absolute top-2 right-2 px-1.5 py-0.5 rounded-lg bg-black/80 backdrop-blur-md text-[11px] font-bold text-amber-300 border border-amber-500/30">
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

                      <span className="text-[11px] text-zinc-400 mt-0.5 truncate">
                        {game.release_year ? `${game.release_year} • ` : ''}
                        {game.genres?.[0] || 'Spel'}
                      </span>

                      <button
                        onClick={() => onAddGame(game)}
                        disabled={inLibrary}
                        className={`mt-2.5 w-full py-1.5 rounded-xl text-xs font-semibold flex items-center justify-center gap-1 transition ${
                          inLibrary
                            ? 'bg-zinc-800/60 text-zinc-400 border border-zinc-700/50 cursor-default'
                            : 'bg-zinc-800 hover:bg-brand-red text-zinc-200 hover:text-white border border-zinc-700 hover:border-brand-red'
                        }`}
                      >
                        {inLibrary ? (
                          <>
                            <Check className="w-3 h-3 text-emerald-400" />
                            <span>I biblioteket</span>
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
              <div className="flex gap-4 overflow-x-auto pb-3 scrollbar-thin scrollbar-thumb-zinc-800">
                {trendingGames.map((game, idx) => {
                  const inLibrary = isGameInLibrary(game.igdb_id, game.title);
                  return (
                    <div
                      key={game.id}
                      className="flex-shrink-0 w-36 sm:w-44 flex flex-col group bg-zinc-900/60 border border-zinc-800/80 rounded-2xl overflow-hidden p-2.5 transition hover:border-zinc-700 relative"
                    >
                      {/* Rank Badge */}
                      <div
                        className={`absolute top-4 left-4 z-10 px-2 py-0.5 rounded-lg text-[10px] font-black shadow-lg backdrop-blur-md border ${
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
                        className="w-full aspect-[3/4] rounded-xl overflow-hidden bg-zinc-950 mb-2.5 relative cursor-pointer"
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
                            <Gamepad className="w-8 h-8 text-zinc-600" />
                          </div>
                        )}
                        {game.igdb_rating && (
                          <div className="absolute top-2 right-2 px-1.5 py-0.5 rounded-lg bg-black/80 backdrop-blur-md text-[11px] font-bold text-amber-300 border border-amber-500/30">
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

                      <span className="text-[11px] text-zinc-400 mt-0.5 truncate">
                        {game.release_year ? `${game.release_year} • ` : ''}
                        {game.genres?.[0] || 'Spel'}
                      </span>

                      <button
                        onClick={() => onAddGame(game)}
                        disabled={inLibrary}
                        className={`mt-2.5 w-full py-1.5 rounded-xl text-xs font-semibold flex items-center justify-center gap-1 transition ${
                          inLibrary
                            ? 'bg-zinc-800/60 text-zinc-400 border border-zinc-700/50 cursor-default'
                            : 'bg-zinc-800 hover:bg-brand-red text-zinc-200 hover:text-white border border-zinc-700 hover:border-brand-red'
                        }`}
                      >
                        {inLibrary ? (
                          <>
                            <Check className="w-3 h-3 text-emerald-400" />
                            <span>I biblioteket</span>
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
            )}
          </div>

          {/* 4. Kommande storspel (Upcoming Releases) */}
          <div className="space-y-3">
            <div className="flex items-center gap-2 text-sm font-bold text-white uppercase tracking-wider">
              <Calendar className="w-4 h-4 text-brand-red" />
              <span>Kommande storspel</span>
            </div>

            <div className="flex gap-4 overflow-x-auto pb-3 scrollbar-thin scrollbar-thumb-zinc-800">
              {upcomingGames.map((game) => {
                const inLibrary = isGameInLibrary(game.igdb_id, game.title);
                return (
                  <div
                    key={game.id}
                    className="flex-shrink-0 w-36 sm:w-44 flex flex-col group bg-zinc-900/60 border border-zinc-800/80 rounded-2xl overflow-hidden p-2.5 transition hover:border-zinc-700"
                  >
                    <div
                      onClick={() => onSelectGame(game)}
                      className="w-full aspect-[3/4] rounded-xl overflow-hidden bg-zinc-950 mb-2.5 relative cursor-pointer"
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
                          <Gamepad className="w-8 h-8 text-zinc-600" />
                        </div>
                      )}
                      <div className="absolute bottom-2 left-2 right-2 px-2 py-0.5 rounded-md bg-black/85 backdrop-blur-md text-[10px] font-bold text-rose-300 border border-rose-500/30 truncate text-center">
                        ⏳ Kommande
                      </div>
                    </div>

                    <h4
                      onClick={() => onSelectGame(game)}
                      className="text-xs sm:text-sm font-bold text-zinc-100 truncate cursor-pointer hover:text-red-400 transition"
                    >
                      {game.title}
                    </h4>

                    <span className="text-[11px] text-zinc-400 mt-0.5 truncate">
                      {game.first_release_date
                        ? new Date(game.first_release_date * 1000).toLocaleDateString('sv-SE', {
                            year: 'numeric',
                            month: 'short',
                          })
                        : game.release_year || 'TBA'}
                    </span>

                    <button
                      onClick={() => onAddGame(game)}
                      disabled={inLibrary}
                      className={`mt-2.5 w-full py-1.5 rounded-xl text-xs font-semibold flex items-center justify-center gap-1 transition ${
                        inLibrary
                          ? 'bg-zinc-800/60 text-zinc-400 border border-zinc-700/50 cursor-default'
                          : 'bg-zinc-800 hover:bg-brand-red text-zinc-200 hover:text-white border border-zinc-700 hover:border-brand-red'
                      }`}
                    >
                      {inLibrary ? (
                        <>
                          <Check className="w-3 h-3 text-emerald-400" />
                          <span>I biblioteket</span>
                        </>
                      ) : (
                        <>
                          <Plus className="w-3 h-3" />
                          <span>Önskelista</span>
                        </>
                      )}
                    </button>
                  </div>
                );
              })}
            </div>
          </div>

          {/* 5. 🎮 Utforska efter Genre med Aktuella spel & Era-filter */}
          <div className="space-y-4 pt-4 border-t border-zinc-800/60">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div className="flex items-center gap-2.5">
                <div className="p-1.5 rounded-xl bg-purple-500/10 border border-purple-500/30">
                  <Layers className="w-4 h-4 text-purple-400" />
                </div>
                <div>
                  <h3 className="text-base font-bold text-white tracking-tight">Utforska per genre</h3>
                  <p className="text-[11px] text-zinc-400">Aktuella och topprankade spel efter genre</p>
                </div>
              </div>

              {/* Action Toolbar: Era-väljare, Sortering & Se mer */}
              <div className="flex flex-wrap items-center gap-2">
                {/* Era selector */}
                <div className="flex items-center bg-zinc-900 border border-zinc-800 p-0.5 rounded-xl text-xs">
                  <button
                    onClick={() => setGenreEra('recent')}
                    className={`px-2.5 py-1 rounded-lg font-medium transition ${
                      genreEra === 'recent' ? 'bg-purple-600 text-white font-semibold shadow-sm' : 'text-zinc-400 hover:text-zinc-200'
                    }`}
                  >
                    🔥 2022–2026
                  </button>
                  <button
                    onClick={() => setGenreEra('all')}
                    className={`px-2.5 py-1 rounded-lg font-medium transition ${
                      genreEra === 'all' ? 'bg-purple-600 text-white font-semibold shadow-sm' : 'text-zinc-400 hover:text-zinc-200'
                    }`}
                  >
                    Klassiker
                  </button>
                </div>

                <select
                  value={genreSort}
                  onChange={(e) => setGenreSort(e.target.value as any)}
                  className="bg-zinc-900 border border-zinc-800 text-zinc-300 text-xs rounded-xl px-3 py-1.5 focus:outline-none focus:border-purple-500 cursor-pointer"
                >
                  <option value="popularity">Mest populära</option>
                  <option value="rating">Högst betyg</option>
                  <option value="newest">Nyast först</option>
                </select>

                <button
                  onClick={() => setIsGenreExpanded(!isGenreExpanded)}
                  className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-semibold border transition ${
                    isGenreExpanded
                      ? 'bg-purple-600 text-white border-purple-500'
                      : 'bg-zinc-900 text-zinc-400 hover:text-white border-zinc-800'
                  }`}
                >
                  {isGenreExpanded ? <Rows className="w-3.5 h-3.5" /> : <LayoutGrid className="w-3.5 h-3.5" />}
                  <span>{isGenreExpanded ? 'Mindre' : `Se mer (${genreGames.length}+ spel)`}</span>
                </button>
              </div>
            </div>

            {/* Genre Chips */}
            <div className="flex gap-2 overflow-x-auto pb-2 scrollbar-none">
              {GENRES.map((g) => (
                <button
                  key={g}
                  onClick={() => setSelectedGenre(g)}
                  className={`px-3.5 py-2 rounded-xl text-xs font-semibold whitespace-nowrap transition ${
                    selectedGenre === g
                      ? 'bg-purple-600 text-white shadow-md shadow-purple-600/30 border border-purple-500'
                      : 'bg-zinc-900 text-zinc-400 hover:text-zinc-200 border border-zinc-800'
                  }`}
                >
                  {g}
                </button>
              ))}
            </div>

            {/* Expanderat läge: Fritextsökning inom genren */}
            {isGenreExpanded && (
              <div className="flex items-center justify-between gap-3 bg-zinc-900/80 border border-zinc-800 p-3 rounded-2xl">
                <div className="relative flex-1 max-w-sm">
                  <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-zinc-500" />
                  <input
                    type="text"
                    value={genreSearch}
                    onChange={(e) => setGenreSearch(e.target.value)}
                    placeholder={`Filtrera bland ${selectedGenre}-spel...`}
                    className="w-full bg-zinc-950 border border-zinc-800 text-zinc-100 rounded-xl pl-9 pr-3 py-1.5 text-xs focus:outline-none focus:border-purple-500"
                  />
                </div>

                <span className="text-xs text-zinc-500 font-medium">
                  Visar {filteredGenreGames.length} spel inom {selectedGenre}
                </span>
              </div>
            )}

            {/* Genre Game Grid */}
            {isLoadingGenre ? (
              <div className="flex items-center justify-center py-16 text-zinc-500 gap-2">
                <RefreshCw className="w-5 h-5 animate-spin text-purple-400" />
                <span className="text-xs">Hämtar aktuella spel inom {selectedGenre}...</span>
              </div>
            ) : filteredGenreGames.length === 0 ? (
              <div className="text-center py-12 text-zinc-500 border border-dashed border-zinc-800 rounded-2xl">
                <p className="text-xs">Inga spel matchar sökningen inom {selectedGenre}.</p>
              </div>
            ) : (
              <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-3 sm:gap-4">
                {filteredGenreGames.map((game) => {
                  const inLibrary = isGameInLibrary(game.igdb_id, game.title);
                  return (
                    <div
                      key={game.id}
                      className="flex flex-col group bg-zinc-900/60 border border-zinc-800/80 rounded-2xl overflow-hidden p-2.5 transition hover:border-zinc-700 shadow-md"
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
                          <div className="absolute top-1.5 right-1.5 px-1.5 py-0.5 rounded bg-black/80 text-[10px] font-bold text-amber-300 border border-amber-500/30">
                            ⭐ {game.igdb_rating}
                          </div>
                        )}
                      </div>

                      <h4
                        onClick={() => onSelectGame(game)}
                        className="text-xs font-bold text-zinc-100 truncate cursor-pointer hover:text-purple-400 transition"
                      >
                        {game.title}
                      </h4>

                      <span className="text-[10px] text-zinc-400 mt-0.5 truncate">
                        {game.release_year ? `${game.release_year} • ` : ''}
                        {game.developers?.[0] || 'IGDB'}
                      </span>

                      <button
                        onClick={() => onAddGame(game)}
                        disabled={inLibrary}
                        className={`mt-2 w-full py-1.5 rounded-xl text-[11px] font-semibold flex items-center justify-center gap-1 transition ${
                          inLibrary
                            ? 'bg-zinc-800/60 text-zinc-400 border border-zinc-700/50 cursor-default'
                            : 'bg-zinc-800 hover:bg-purple-600 text-zinc-200 hover:text-white border border-zinc-700 hover:border-purple-600'
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
            )}
          </div>
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
              {/* 1. Hero / Featured Top Story (visas när man inte har sökt specifik text) */}
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
