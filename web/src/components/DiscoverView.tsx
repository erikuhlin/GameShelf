'use client';

import React, { useState, useEffect, useMemo } from 'react';
import { Game, GameCollection, PlayStatus } from '@/types/game';
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
} from 'lucide-react';

interface DiscoverViewProps {
  games: Game[];
  onSelectGame: (game: Game) => void;
  onAddGame: (game: Game) => void;
  onOpenRouletteModal?: () => void;
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
  category?: string;
}

const GENRES = [
  'Alla genrer',
  'Role-playing (RPG)',
  'Action',
  'Adventure',
  'Shooter',
  'Indie',
  'Strategy',
  'Platform',
  'Racing',
  'Fighting',
];

export function DiscoverView({
  games,
  onSelectGame,
  onAddGame,
}: DiscoverViewProps) {
  const [activeTab, setActiveTab] = useState<'discover' | 'news'>('discover');

  // --- Discover Data State ---
  const [trendingGames, setTrendingGames] = useState<Game[]>([]);
  const [upcomingGames, setUpcomingGames] = useState<Game[]>([]);
  const [topRatedGames, setTopRatedGames] = useState<Game[]>([]);
  const [genreGames, setGenreGames] = useState<Game[]>([]);
  const [selectedGenre, setSelectedGenre] = useState<string>('Role-playing (RPG)');
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
  const [selectedNewsFilter, setSelectedNewsFilter] = useState<'all' | 'my_games' | 'reviews' | 'trailers' | 'playstation' | 'xbox' | 'nintendo' | 'pc'>('all');

  // Spel som användaren för tillfället spelar
  const currentlyPlaying = useMemo(() => {
    return games.filter((g) => g.status === 'Spelar nu');
  }, [games]);

  // Hämta data för Utforska
  useEffect(() => {
    async function loadDiscoverFeed() {
      setIsLoadingDiscover(true);
      try {
        const [trendRes, upRes, topRes] = await Promise.allSettled([
          fetch('/api/games/discover?category=trending').then((r) => r.json()),
          fetch('/api/games/discover?category=upcoming').then((r) => r.json()),
          fetch('/api/games/discover?category=top_rated').then((r) => r.json()),
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
  }, []);

  // Hämta genrespel vid val
  useEffect(() => {
    if (selectedGenre === 'Alla genrer') return;
    async function loadGenreGames() {
      try {
        const res = await fetch(`/api/games/discover?genre=${encodeURIComponent(selectedGenre)}`);
        const data = await res.json();
        if (data.results) {
          setGenreGames(data.results);
        }
      } catch (e) {}
    }
    loadGenreGames();
  }, [selectedGenre]);

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

    // Kategori- och källfilter
    if (selectedNewsFilter === 'my_games') {
      const titles = games.map((g) => g.title.toLowerCase());
      result = result.filter((n) =>
        titles.some((t) => n.title.toLowerCase().includes(t))
      );
    } else if (selectedNewsFilter === 'reviews') {
      result = result.filter((n) => n.category === 'Recension' || n.title.toLowerCase().includes('review'));
    } else if (selectedNewsFilter === 'trailers') {
      result = result.filter((n) => n.category === 'Trailer' || n.title.toLowerCase().includes('trailer'));
    } else if (selectedNewsFilter === 'playstation') {
      result = result.filter((n) => n.source.toLowerCase().includes('playstation') || n.title.toLowerCase().includes('ps5') || n.title.toLowerCase().includes('playstation'));
    } else if (selectedNewsFilter === 'xbox') {
      result = result.filter((n) => n.source.toLowerCase().includes('xbox') || n.title.toLowerCase().includes('xbox'));
    } else if (selectedNewsFilter === 'nintendo') {
      result = result.filter((n) => n.source.toLowerCase().includes('nintendo') || n.title.toLowerCase().includes('switch'));
    } else if (selectedNewsFilter === 'pc') {
      result = result.filter((n) => n.source.toLowerCase().includes('pc') || n.title.toLowerCase().includes('pc') || n.title.toLowerCase().includes('steam'));
    }

    return result;
  }, [newsItems, newsSearch, selectedNewsFilter, games]);

  const isGameInLibrary = (igdbId?: number | string | null, title?: string) => {
    return games.some(
      (g) =>
        (igdbId && g.igdb_id === Number(igdbId)) ||
        (title && g.title.toLowerCase() === title.toLowerCase())
    );
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
            <span>Spelnyheter</span>
          </button>
        </div>
      </div>

      {activeTab === 'discover' ? (
        <div className="space-y-8">
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

          {/* 3. Trendar just nu (Trending on IGDB) */}
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2 text-sm font-bold text-white uppercase tracking-wider">
                <Flame className="w-4 h-4 text-brand-red" />
                <span>Trendar just nu</span>
              </div>
            </div>

            <div className="flex gap-4 overflow-x-auto pb-3 scrollbar-thin scrollbar-thumb-zinc-800">
              {trendingGames.map((game) => {
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
                      {game.igdb_rating && (
                        <div className="absolute top-2 right-2 px-1.5 py-0.5 rounded-lg bg-black/80 backdrop-blur-md text-[11px] font-bold text-amber-300 border border-amber-500/30">
                          {game.igdb_rating}
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
                      {game.release_year || 'IGDB'}
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

          {/* 5. Utforska efter Genre */}
          <div className="space-y-4 pt-2">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div className="flex items-center gap-2 text-sm font-bold text-white uppercase tracking-wider">
                <Layers className="w-4 h-4 text-brand-red" />
                <span>Utforska efter genre</span>
              </div>

              {/* Genre Chips */}
              <div className="flex gap-2 overflow-x-auto pb-1 scrollbar-none">
                {GENRES.map((g) => (
                  <button
                    key={g}
                    onClick={() => setSelectedGenre(g)}
                    className={`px-3 py-1.5 rounded-xl text-xs font-semibold whitespace-nowrap transition ${
                      selectedGenre === g
                        ? 'bg-zinc-100 text-zinc-950 shadow-sm'
                        : 'bg-zinc-900 text-zinc-400 hover:text-zinc-200 border border-zinc-800'
                    }`}
                  >
                    {g}
                  </button>
                ))}
              </div>
            </div>

            {/* Genre Game Grid */}
            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-3 sm:gap-4">
              {genreGames.slice(0, 12).map((game) => {
                const inLibrary = isGameInLibrary(game.igdb_id, game.title);
                return (
                  <div
                    key={game.id}
                    className="flex flex-col group bg-zinc-900/60 border border-zinc-800/80 rounded-2xl overflow-hidden p-2.5 transition hover:border-zinc-700"
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
                          {game.igdb_rating}
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
                      {game.release_year || 'IGDB'}
                    </span>

                    <button
                      onClick={() => onAddGame(game)}
                      disabled={inLibrary}
                      className={`mt-2 w-full py-1 rounded-lg text-[11px] font-semibold flex items-center justify-center gap-1 transition ${
                        inLibrary
                          ? 'bg-zinc-800/60 text-zinc-400 border border-zinc-700/50 cursor-default'
                          : 'bg-zinc-800 hover:bg-brand-red text-zinc-200 hover:text-white border border-zinc-700 hover:border-brand-red'
                      }`}
                    >
                      {inLibrary ? <Check className="w-3 h-3 text-emerald-400" /> : <Plus className="w-3 h-3" />}
                      <span>{inLibrary ? 'Sparat' : 'Lägg till'}</span>
                    </button>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      ) : (
        /* --- News Section --- */
        <div className="space-y-6">
          {/* News Search & Filters */}
          <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-3">
            <div className="relative flex-1 max-w-md">
              <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-500" />
              <input
                type="text"
                value={newsSearch}
                onChange={(e) => setNewsSearch(e.target.value)}
                placeholder="Sök bland spelnyheter och recensioner..."
                className="w-full bg-zinc-900 border border-zinc-800 text-zinc-100 rounded-xl pl-9 pr-4 py-2 text-xs sm:text-sm focus:outline-none focus:border-red-500"
              />
            </div>

            {/* Filter Pills */}
            <div className="flex items-center gap-1.5 overflow-x-auto pb-1 scrollbar-none">
              {[
                { id: 'all', label: 'Alla' },
                { id: 'my_games', label: '🎮 Mina spel' },
                { id: 'reviews', label: '⭐ Recensioner' },
                { id: 'trailers', label: '🎬 Trailers' },
                { id: 'playstation', label: 'PlayStation' },
                { id: 'xbox', label: 'Xbox' },
                { id: 'nintendo', label: 'Nintendo' },
                { id: 'pc', label: 'PC' },
              ].map((f) => (
                <button
                  key={f.id}
                  onClick={() => setSelectedNewsFilter(f.id as any)}
                  className={`px-3 py-1.5 rounded-xl text-xs font-semibold whitespace-nowrap transition ${
                    selectedNewsFilter === f.id
                      ? 'bg-brand-red text-white shadow-sm'
                      : 'bg-zinc-900 text-zinc-400 hover:text-zinc-200 border border-zinc-800'
                  }`}
                >
                  {f.label}
                </button>
              ))}
            </div>
          </div>

          {isLoadingNews ? (
            <div className="flex items-center justify-center py-24 text-zinc-400 gap-2">
              <RefreshCw className="w-5 h-5 animate-spin text-brand-red" />
              <span className="text-sm">Hämtar senaste spelnyheterna...</span>
            </div>
          ) : filteredNews.length === 0 ? (
            <div className="text-center py-20 text-zinc-500 border border-dashed border-zinc-800 rounded-2xl">
              <Newspaper className="w-8 h-8 mx-auto mb-2 opacity-50" />
              <p className="text-sm">Inga nyheter matchar din sökning eller filter.</p>
            </div>
          ) : (
            <div className="space-y-6">
              {/* 1. Hero / Featured Top Article */}
              {filteredNews[0] && (
                <a
                  href={filteredNews[0].link}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="block relative overflow-hidden rounded-3xl bg-zinc-900 border border-zinc-800 group hover:border-zinc-700 transition shadow-xl"
                >
                  <div className="grid grid-cols-1 lg:grid-cols-12 gap-0">
                    {filteredNews[0].image && (
                      <div className="lg:col-span-7 aspect-video sm:aspect-[16/9] lg:aspect-auto h-64 sm:h-80 lg:h-full relative overflow-hidden bg-black">
                        <img
                          src={filteredNews[0].image}
                          alt={filteredNews[0].title}
                          className="w-full h-full object-cover group-hover:scale-105 transition duration-500"
                        />
                        <div className="absolute inset-0 bg-gradient-to-t from-zinc-950 via-transparent to-transparent lg:hidden" />
                      </div>
                    )}

                    <div className="lg:col-span-5 p-6 sm:p-8 flex flex-col justify-between">
                      <div>
                        <div className="flex items-center gap-2 mb-3">
                          <span className="px-2.5 py-0.5 rounded-full text-xs font-bold bg-brand-red text-white">
                            {filteredNews[0].source}
                          </span>
                          {filteredNews[0].category && (
                            <span className="px-2.5 py-0.5 rounded-full text-xs font-semibold bg-zinc-800 text-zinc-300 border border-zinc-700">
                              {filteredNews[0].category}
                            </span>
                          )}
                          <span className="text-xs text-zinc-500">
                            {new Date(filteredNews[0].published).toLocaleDateString('sv-SE', {
                              month: 'short',
                              day: 'numeric',
                            })}
                          </span>
                        </div>

                        <h3 className="text-xl sm:text-2xl font-bold text-white leading-tight group-hover:text-red-400 transition">
                          {filteredNews[0].title}
                        </h3>

                        {filteredNews[0].summary && (
                          <p className="text-xs sm:text-sm text-zinc-400 mt-3 line-clamp-3 leading-relaxed">
                            {filteredNews[0].summary}
                          </p>
                        )}
                      </div>

                      <div className="flex items-center gap-1 text-xs font-bold text-red-400 mt-6 group-hover:translate-x-1 transition">
                        <span>Läs hela artikeln</span>
                        <ExternalLink className="w-3.5 h-3.5" />
                      </div>
                    </div>
                  </div>
                </a>
              )}

              {/* 2. Grid of other articles */}
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-5">
                {filteredNews.slice(1).map((item) => (
                  <a
                    key={item.id}
                    href={item.link}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="flex flex-col bg-zinc-900/60 border border-zinc-800/80 rounded-2xl overflow-hidden hover:border-zinc-700 group transition shadow-md"
                  >
                    {item.image && (
                      <div className="aspect-video w-full overflow-hidden bg-black relative">
                        <img
                          src={item.image}
                          alt={item.title}
                          className="w-full h-full object-cover group-hover:scale-105 transition duration-300"
                          loading="lazy"
                        />
                        <span className="absolute top-2 left-2 px-2 py-0.5 rounded-md bg-black/80 backdrop-blur-md text-[10px] font-bold text-zinc-200 border border-zinc-700/60">
                          {item.source}
                        </span>
                      </div>
                    )}

                    <div className="p-4 flex-1 flex flex-col justify-between">
                      <div>
                        <div className="flex items-center gap-2 mb-1.5 text-[11px] text-zinc-500">
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
                            <span className="px-1.5 py-0.2 rounded bg-zinc-800 text-zinc-400 text-[10px]">
                              {item.category}
                            </span>
                          )}
                        </div>

                        <h4 className="text-sm font-bold text-zinc-100 group-hover:text-red-400 transition leading-snug line-clamp-2">
                          {item.title}
                        </h4>

                        {item.summary && (
                          <p className="text-xs text-zinc-400 mt-2 line-clamp-2 leading-relaxed">
                            {item.summary}
                          </p>
                        )}
                      </div>

                      <div className="flex items-center gap-1 text-[11px] font-semibold text-zinc-500 group-hover:text-red-400 mt-4 transition">
                        <span>Läs artikel</span>
                        <ExternalLink className="w-3 h-3" />
                      </div>
                    </div>
                  </a>
                ))}
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
