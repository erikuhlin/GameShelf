'use client';

import React, { useState, useEffect, useCallback } from 'react';
import { Game } from '@/types/game';
import {
  Trophy,
  Star,
  Calendar,
  AlertTriangle,
  Loader2,
  Plus,
  Check,
  Gamepad2,
  Sparkles,
  ChevronDown,
  RotateCcw,
} from 'lucide-react';

interface TopGameItem {
  id: number;
  title: string;
  slug?: string;
  cover_url?: string | null;
  release_year?: number | null;
  genres: string[];
  platforms: string[];
  total_rating: number;
  total_rating_count: number;
  weighted_score: number;
  rank: number;
  overall_rank?: number | null;
  genre_ranks?: Record<string, number>;
  is_low_votes: boolean;
}

interface ToplistViewProps {
  onSelectGame: (game: Game) => void;
  onAddGame?: (game: Game) => void;
  libraryGames?: Game[];
}

const PLATFORMS_FILTER = [
  'Alla',
  'PC (Microsoft Windows)',
  'PlayStation 5',
  'PlayStation 4',
  'Nintendo Switch',
  'Xbox Series X|S',
  'Xbox One',
  'PlayStation 2',
  'Super Nintendo Entertainment System',
];

const GENRES_FILTER = [
  'Alla',
  'Role-playing (RPG)',
  'Action',
  'Adventure',
  'Shooter',
  'Platform',
  'Strategy',
  'Puzzle',
  'Racing',
  'Fighting',
  'Indie',
  'Simulator',
  'Sport',
];

export function ToplistView({ onSelectGame, onAddGame, libraryGames = [] }: ToplistViewProps) {
  const [games, setGames] = useState<TopGameItem[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  // Filter state
  const [selectedPlatform, setSelectedPlatform] = useState('Alla');
  const [selectedGenre, setSelectedGenre] = useState('Alla');
  const [yearFrom, setYearFrom] = useState('');
  const [yearTo, setYearTo] = useState('');

  // Snabba årtalsval
  const [quickPeriod, setQuickPeriod] = useState<string>('all');

  const libraryIgdbIds = React.useMemo(() => {
    return new Set(libraryGames.map((g) => g.igdb_id).filter(Boolean));
  }, [libraryGames]);

  const fetchTopGames = useCallback(async () => {
    setIsLoading(true);
    setErrorMessage(null);

    const params = new URLSearchParams();
    params.set('limit', '100');
    if (selectedPlatform && selectedPlatform !== 'Alla') {
      params.set('platform', selectedPlatform);
    }
    if (selectedGenre && selectedGenre !== 'Alla') {
      params.set('genre', selectedGenre);
    }
    if (yearFrom) params.set('year_from', yearFrom);
    if (yearTo) params.set('year_to', yearTo);

    try {
      const res = await fetch(`/api/games/top?${params.toString()}`);
      const data = await res.json();
      if (!res.ok) {
        throw new Error(data.error || 'Kunde inte hämta topplistan');
      }
      setGames(data.results || []);
    } catch (err: any) {
      console.error('Error fetching toplist:', err);
      setErrorMessage(err.message || 'Kunde inte ladda topplistan');
    } finally {
      setIsLoading(false);
    }
  }, [selectedPlatform, selectedGenre, yearFrom, yearTo]);

  useEffect(() => {
    fetchTopGames();
  }, [fetchTopGames]);

  const handleQuickPeriodChange = (period: string) => {
    setQuickPeriod(period);
    switch (period) {
      case 'all':
        setYearFrom('');
        setYearTo('');
        break;
      case '2020s':
        setYearFrom('2020');
        setYearTo('');
        break;
      case '2010s':
        setYearFrom('2010');
        setYearTo('2019');
        break;
      case '2000s':
        setYearFrom('2000');
        setYearTo('2009');
        break;
      case '90s':
        setYearFrom('1990');
        setYearTo('1999');
        break;
      default:
        break;
    }
  };

  const handleResetFilters = () => {
    setSelectedPlatform('Alla');
    setSelectedGenre('Alla');
    setYearFrom('');
    setYearTo('');
    setQuickPeriod('all');
  };

  const convertToGame = (topGame: TopGameItem): Game => {
    const existing = libraryGames.find((g) => g.igdb_id === topGame.id);
    if (existing) return existing;

    return {
      id: `igdb_${topGame.id}`,
      title: topGame.title,
      cover_url: topGame.cover_url || undefined,
      release_year: topGame.release_year || undefined,
      genres: topGame.genres,
      platforms: topGame.platforms,
      developers: [],
      igdb_id: topGame.id,
      igdb_rating: Math.round((topGame.weighted_score / 10) * 10) / 10,
      status: 'notStarted',
      is_owned: false,
      is_backlog: false,
      todos: [],
      notes: '',
    };
  };

  return (
    <div className="space-y-6">
      {/* Header Banner */}
      <div className="relative overflow-hidden rounded-2xl bg-gradient-to-br from-amber-500/10 via-amber-600/5 to-zinc-900 border border-amber-500/20 p-6 md:p-8">
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
          <div>
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-amber-500/20 text-amber-300 text-xs font-semibold uppercase tracking-wider mb-2">
              <Trophy className="w-3.5 h-3.5" />
              IGDB Weighted Rating
            </div>
            <h1 className="text-2xl md:text-3xl font-extrabold text-zinc-100">
              Topp 100 Spel genom tiderna
            </h1>
            <p className="text-sm text-zinc-400 mt-1 max-w-2xl">
              Räknat med Bayesiansk medelvärdesformel. Mästerverk med tusentals röster premieras,
              medan titlar med extremt snitt men få röster justeras mot det globala medelvärdet.
            </p>
          </div>

          <div className="flex items-center gap-3">
            <span className="text-xs text-zinc-400">
              Formel: <code className="bg-zinc-800 px-1.5 py-0.5 rounded text-amber-400">WR = (v/(v+100))*R + (100/(v+100))*C</code>
            </span>
          </div>
        </div>
      </div>

      {/* Filter Bar */}
      <div className="bg-zinc-900/80 border border-zinc-800 rounded-xl p-4 space-y-4">
        <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 gap-3">
          {/* Plattform */}
          <div>
            <label className="block text-xs font-medium text-zinc-400 mb-1.5">Plattform</label>
            <div className="relative">
              <select
                value={selectedPlatform}
                onChange={(e) => setSelectedPlatform(e.target.value)}
                className="w-full bg-zinc-800/90 border border-zinc-700 rounded-lg px-3 py-2 text-sm text-zinc-200 focus:outline-none focus:border-amber-500 appearance-none pr-8 cursor-pointer"
              >
                {PLATFORMS_FILTER.map((p) => (
                  <option key={p} value={p}>
                    {p === 'PC (Microsoft Windows)' ? 'PC' : p}
                  </option>
                ))}
              </select>
              <ChevronDown className="w-4 h-4 text-zinc-400 absolute right-2.5 top-1/2 -translate-y-1/2 pointer-events-none" />
            </div>
          </div>

          {/* Genre */}
          <div>
            <label className="block text-xs font-medium text-zinc-400 mb-1.5">Genre</label>
            <div className="relative">
              <select
                value={selectedGenre}
                onChange={(e) => setSelectedGenre(e.target.value)}
                className="w-full bg-zinc-800/90 border border-zinc-700 rounded-lg px-3 py-2 text-sm text-zinc-200 focus:outline-none focus:border-amber-500 appearance-none pr-8 cursor-pointer"
              >
                {GENRES_FILTER.map((g) => (
                  <option key={g} value={g}>
                    {g === 'Role-playing (RPG)' ? 'RPG' : g}
                  </option>
                ))}
              </select>
              <ChevronDown className="w-4 h-4 text-zinc-400 absolute right-2.5 top-1/2 -translate-y-1/2 pointer-events-none" />
            </div>
          </div>

          {/* Perioder */}
          <div>
            <label className="block text-xs font-medium text-zinc-400 mb-1.5">Tidsperiod</label>
            <div className="relative">
              <select
                value={quickPeriod}
                onChange={(e) => handleQuickPeriodChange(e.target.value)}
                className="w-full bg-zinc-800/90 border border-zinc-700 rounded-lg px-3 py-2 text-sm text-zinc-200 focus:outline-none focus:border-amber-500 appearance-none pr-8 cursor-pointer"
              >
                <option value="all">Alla år</option>
                <option value="2020s">2020-talet (2020–Nu)</option>
                <option value="2010s">2010-talet (2010–2019)</option>
                <option value="2000s">2000-talet (2000–2009)</option>
                <option value="90s">90-talet (1990–1999)</option>
              </select>
              <ChevronDown className="w-4 h-4 text-zinc-400 absolute right-2.5 top-1/2 -translate-y-1/2 pointer-events-none" />
            </div>
          </div>

          {/* Årsintervall / Anpassat */}
          <div className="flex items-end gap-2">
            <div className="flex-1">
              <label className="block text-xs font-medium text-zinc-400 mb-1.5">Från år</label>
              <input
                type="number"
                placeholder="1990"
                value={yearFrom}
                onChange={(e) => {
                  setYearFrom(e.target.value);
                  setQuickPeriod('custom');
                }}
                className="w-full bg-zinc-800/90 border border-zinc-700 rounded-lg px-3 py-2 text-sm text-zinc-200 focus:outline-none focus:border-amber-500"
              />
            </div>
            <div className="flex-1">
              <label className="block text-xs font-medium text-zinc-400 mb-1.5">Till år</label>
              <input
                type="number"
                placeholder="2026"
                value={yearTo}
                onChange={(e) => {
                  setYearTo(e.target.value);
                  setQuickPeriod('custom');
                }}
                className="w-full bg-zinc-800/90 border border-zinc-700 rounded-lg px-3 py-2 text-sm text-zinc-200 focus:outline-none focus:border-amber-500"
              />
            </div>
            {(selectedPlatform !== 'Alla' || selectedGenre !== 'Alla' || yearFrom || yearTo) && (
              <button
                onClick={handleResetFilters}
                title="Återställ filter"
                className="p-2 text-zinc-400 hover:text-zinc-200 hover:bg-zinc-800 rounded-lg transition-colors"
              >
                <RotateCcw className="w-4 h-4" />
              </button>
            )}
          </div>
        </div>
      </div>

      {/* Resultatlista */}
      {isLoading ? (
        <div className="flex flex-col items-center justify-center py-24 text-zinc-400 space-y-3">
          <Loader2 className="w-8 h-8 animate-spin text-amber-500" />
          <p className="text-sm font-medium">Laddar topplistan...</p>
        </div>
      ) : errorMessage ? (
        <div className="bg-red-500/10 border border-red-500/20 rounded-xl p-6 text-center text-red-400 space-y-3">
          <p>{errorMessage}</p>
          <button
            onClick={() => fetchTopGames()}
            className="px-4 py-2 bg-red-500/20 hover:bg-red-500/30 text-red-300 rounded-lg text-sm transition-colors"
          >
            Försök igen
          </button>
        </div>
      ) : games.length === 0 ? (
        <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-12 text-center text-zinc-400 space-y-3">
          <Trophy className="w-12 h-12 mx-auto text-zinc-600 mb-2" />
          <h3 className="text-lg font-semibold text-zinc-200">Inga spel matchade filtren</h3>
          <p className="text-sm text-zinc-400 max-w-md mx-auto">
            Testa att bredda ditt sökurval eller nollställ filtren för att se hela topplistan.
          </p>
          <button
            onClick={handleResetFilters}
            className="mt-2 px-4 py-2 bg-amber-500/20 hover:bg-amber-500/30 text-amber-300 rounded-lg text-sm transition-colors inline-flex items-center gap-2"
          >
            <RotateCcw className="w-4 h-4" /> Återställ filter
          </button>
        </div>
      ) : (
        <div className="space-y-2.5">
          {games.map((game) => {
            const isOwned = libraryIgdbIds.has(game.id);
            const formattedScore = (game.weighted_score / 10).toFixed(1);
            const rawScore = (game.total_rating / 10).toFixed(1);

            return (
              <div
                key={game.id}
                onClick={() => onSelectGame(convertToGame(game))}
                className="group relative flex items-center gap-3.5 sm:gap-5 p-3 sm:p-4 bg-zinc-900/90 hover:bg-zinc-800/80 border border-zinc-800/90 hover:border-zinc-700 rounded-xl transition-all duration-200 cursor-pointer shadow-sm hover:shadow-md"
              >
                {/* Ranking Nummer (Desktop) */}
                <div className="hidden sm:block flex-shrink-0 w-8 sm:w-10 text-center">
                  {game.rank === 1 ? (
                    <span className="inline-flex items-center justify-center w-8 h-8 rounded-full bg-amber-500/20 text-amber-400 font-extrabold text-base border border-amber-500/40 shadow-sm">
                      1
                    </span>
                  ) : game.rank === 2 ? (
                    <span className="inline-flex items-center justify-center w-8 h-8 rounded-full bg-slate-300/20 text-slate-200 font-extrabold text-base border border-slate-300/40">
                      2
                    </span>
                  ) : game.rank === 3 ? (
                    <span className="inline-flex items-center justify-center w-8 h-8 rounded-full bg-amber-700/20 text-amber-500 font-extrabold text-base border border-amber-700/40">
                      3
                    </span>
                  ) : (
                    <span className="font-semibold text-sm text-zinc-500 group-hover:text-zinc-400">
                      #{game.rank}
                    </span>
                  )}
                </div>

                {/* Cover Omslag (med rank overlay på mobil) */}
                <div className="relative flex-shrink-0 w-14 h-20 sm:w-16 sm:h-24 rounded-lg overflow-hidden bg-zinc-800 border border-zinc-700/60 shadow-inner">
                  {/* Mobil overlay-rank */}
                  <div className="sm:hidden absolute top-1 left-1 z-10">
                    {game.rank === 1 ? (
                      <span className="inline-flex items-center justify-center w-5 h-5 rounded bg-amber-500 text-zinc-950 font-black text-[11px] shadow-md">
                        1
                      </span>
                    ) : game.rank === 2 ? (
                      <span className="inline-flex items-center justify-center w-5 h-5 rounded bg-slate-200 text-zinc-950 font-black text-[11px] shadow-md">
                        2
                      </span>
                    ) : game.rank === 3 ? (
                      <span className="inline-flex items-center justify-center w-5 h-5 rounded bg-amber-700 text-white font-black text-[11px] shadow-md">
                        3
                      </span>
                    ) : (
                      <span className="inline-flex items-center justify-center px-1.5 h-4.5 rounded bg-black/80 backdrop-blur-sm text-zinc-200 font-bold text-[10px] shadow-sm border border-white/10">
                        #{game.rank}
                      </span>
                    )}
                  </div>

                  {game.cover_url ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      src={game.cover_url}
                      alt={game.title}
                      className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                      loading="lazy"
                    />
                  ) : (
                    <div className="w-full h-full flex items-center justify-center text-zinc-600">
                      <Gamepad2 className="w-6 h-6" />
                    </div>
                  )}
                </div>

                {/* Spelinfo */}
                <div className="flex-1 min-w-0 pr-1 sm:pr-2">
                  <h3 className="font-bold text-sm sm:text-base text-zinc-100 group-hover:text-amber-400 transition-colors line-clamp-2 leading-snug">
                    {game.title}
                  </h3>

                  {/* Kompakt metadata: Årtal • Genre • Plattform */}
                  <div className="flex items-center gap-1.5 text-xs text-zinc-400 mt-1 flex-wrap">
                    {game.release_year && (
                      <span className="font-medium text-zinc-300">{game.release_year}</span>
                    )}
                    {game.release_year && (game.genres.length > 0 || game.platforms.length > 0) && (
                      <span className="text-zinc-600">•</span>
                    )}
                    {game.genres.length > 0 && (
                      <span className="text-zinc-300">
                        {game.genres[0] === 'Role-playing (RPG)' ? 'RPG' : game.genres[0]}
                      </span>
                    )}
                    {game.platforms.length > 0 && (
                      <>
                        <span className="text-zinc-600">•</span>
                        <span className="text-zinc-400 truncate max-w-[120px] sm:max-w-[200px]">
                          {game.platforms.slice(0, 2).join(', ')}
                        </span>
                      </>
                    )}
                  </div>

                  {/* Varning om få röster */}
                  {game.is_low_votes && (
                    <div className="inline-flex items-center gap-1 mt-1.5 px-1.5 py-0.5 rounded text-[10px] bg-amber-500/10 text-amber-300 border border-amber-500/20">
                      <AlertTriangle className="w-3 h-3 flex-shrink-0" />
                      Få röster ({game.total_rating_count} st)
                    </div>
                  )}
                </div>

                {/* Poäng och röster */}
                <div className="flex flex-col items-end flex-shrink-0 pl-1.5 sm:pl-2">
                  <div className="flex items-center gap-1 sm:gap-1.5 bg-amber-500/10 border border-amber-500/30 px-2 py-0.5 sm:px-2.5 sm:py-1 rounded-lg">
                    <Star className="w-3.5 h-3.5 sm:w-4 sm:h-4 fill-amber-400 text-amber-400" />
                    <span className="font-extrabold text-sm sm:text-base text-amber-300 tracking-tight">
                      {formattedScore}
                    </span>
                  </div>

                  <span className="text-[10px] sm:text-[11px] text-zinc-400 mt-1 whitespace-nowrap">
                    {game.total_rating_count >= 1000
                      ? `${(game.total_rating_count / 1000).toFixed(1)}k röster`
                      : `${game.total_rating_count} röster`}
                  </span>
                  <span className="hidden sm:inline text-[10px] text-zinc-500" title={`Råbetyg från IGDB: ${rawScore}/10`}>
                    (rå: {rawScore})
                  </span>
                </div>

                {/* Lägg till i biblioteket knapp */}
                {onAddGame && (
                  <div className="hidden sm:block flex-shrink-0 ml-2" onClick={(e) => e.stopPropagation()}>
                    {isOwned ? (
                      <span className="inline-flex items-center gap-1 px-3 py-1.5 rounded-lg bg-emerald-500/10 text-emerald-400 border border-emerald-500/30 text-xs font-semibold">
                        <Check className="w-3.5 h-3.5" />
                        I biblioteket
                      </span>
                    ) : (
                      <button
                        onClick={() => onAddGame(convertToGame(game))}
                        className="inline-flex items-center gap-1 px-3 py-1.5 rounded-lg bg-zinc-800 hover:bg-zinc-700 text-zinc-200 hover:text-white border border-zinc-700 text-xs font-medium transition-colors"
                      >
                        <Plus className="w-3.5 h-3.5" />
                        Lägg till
                      </button>
                    )}
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
