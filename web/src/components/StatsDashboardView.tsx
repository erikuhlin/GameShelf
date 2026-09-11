'use client';

import React, { useState, useMemo } from 'react';
import { Game, PlayStatus, PLAY_STATUSES } from '@/types/game';
import { getStatusDisplayTitle } from '@/lib/statusHelper';
import {
  BarChart3,
  Trophy,
  Clock,
  Star,
  Gamepad2,
  Sparkles,
  BookOpen,
  Calendar,
  Archive,
  ChevronDown,
  Crown,
} from 'lucide-react';

interface StatsDashboardViewProps {
  games: Game[];
  onSelectGame: (game: Game) => void;
  onOpenWrapped?: () => void;
}

export function StatsDashboardView({ games, onSelectGame, onOpenWrapped }: StatsDashboardViewProps) {
  const [activeSubTab, setActiveSubTab] = useState<'overview' | 'diary'>('overview');
  const [diaryMode, setDiaryMode] = useState<'active' | 'memories'>('active');
  const [selectedYear, setSelectedYear] = useState<number | 'all'>(new Date().getFullYear());

  // 1. Beräkningar för KPI-kort
  const totalGames = games.length;
  const ownedGames = games.filter((g) => g.is_owned).length;
  const completedGames = games.filter((g) => g.status === 'completed' && g.is_owned).length;

  const totalEstimatedHours = games.reduce((acc, g) => acc + (g.estimated_hours || 0), 0);
  const backlogHours = games
    .filter((g) => (g.is_backlog || g.status === 'playing') && g.is_owned)
    .reduce((acc, g) => acc + (g.estimated_hours || 0), 0);

  const ratedGames = games.filter((g) => g.rating !== null && g.rating !== undefined && g.rating > 0);
  const averageRating =
    ratedGames.length > 0
      ? (ratedGames.reduce((acc, g) => acc + (g.rating || 0), 0) / ratedGames.length).toFixed(1)
      : null;

  const playedCount = ownedGames;
  const completionRate =
    playedCount > 0 ? Math.round((completedGames / playedCount) * 100) : 0;

  // 2. Statusfördelning
  const statusStats = useMemo(() => {
    const items = PLAY_STATUSES.map((status) => {
      const count = games.filter((g) => g.status === status && g.is_owned).length;
      const percentage = ownedGames > 0 ? Math.round((count / ownedGames) * 100) : 0;
      return {
        status,
        label: getStatusDisplayTitle(status, false),
        count,
        percentage,
      };
    });

    const backlogCount = games.filter((g) => g.is_backlog && g.is_owned).length;
    const backlogPct = ownedGames > 0 ? Math.round((backlogCount / ownedGames) * 100) : 0;

    return {
      statuses: items,
      backlog: { count: backlogCount, percentage: backlogPct },
    };
  }, [games, ownedGames]);

  // 3. Plattformsfördelning
  const platformStats = useMemo(() => {
    const counts: { [p: string]: number } = {};
    games.forEach((g) => {
      const plats = g.platforms && g.platforms.length > 0 ? g.platforms : ['Övrigt'];
      plats.forEach((p) => {
        counts[p] = (counts[p] || 0) + 1;
      });
    });

    return Object.entries(counts)
      .map(([platform, count]) => ({
        platform,
        count,
        percentage: totalGames > 0 ? Math.round((count / totalGames) * 100) : 0,
      }))
      .sort((a, b) => b.count - a.count);
  }, [games, totalGames]);

  // 4. Genrefördelning
  const genreStats = useMemo(() => {
    const counts: { [g: string]: number } = {};
    games.forEach((g) => {
      const genres = g.genres && g.genres.length > 0 ? g.genres : ['Övrigt'];
      genres.forEach((genre) => {
        counts[genre] = (counts[genre] || 0) + 1;
      });
    });

    return Object.entries(counts)
      .map(([genre, count]) => ({
        genre,
        count,
        percentage: totalGames > 0 ? Math.round((count / totalGames) * 100) : 0,
      }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 6);
  }, [games, totalGames]);

  // 5. Topprankade spel (Betyg 8-10)
  const topRatedGames = useMemo(() => {
    return games
      .filter((g) => g.rating && g.rating >= 8)
      .sort((a, b) => (b.rating || 0) - (a.rating || 0))
      .slice(0, 6);
  }, [games]);

  // ==================== SPELDAGBOK DATA ====================
  // Aktiva genomspelningar med loggat datum
  const activeDiaryGames = useMemo(() => {
    return games
      .filter((g) => g.status === 'completed' && g.completed_date)
      .sort((a, b) => new Date(b.completed_date!).getTime() - new Date(a.completed_date!).getTime());
  }, [games]);

  // Spelminnen (completed utan klardatum)
  const memoryGames = useMemo(() => {
    return games
      .filter((g) => g.status === 'completed' && !g.completed_date)
      .sort((a, b) => (b.release_year || 0) - (a.release_year || 0));
  }, [games]);

  // Tillgängliga år för aktiv dagbok
  const availableYears = useMemo(() => {
    const currentY = new Date().getFullYear();
    const years = new Set<number>();
    years.add(currentY);
    activeDiaryGames.forEach((g) => {
      const y = new Date(g.completed_date!).getFullYear();
      if (!isNaN(y)) years.add(y);
    });
    return Array.from(years).sort((a, b) => b - a);
  }, [activeDiaryGames]);

  // Filtrerade spel för vald period
  const filteredActiveDiaryGames = useMemo(() => {
    if (selectedYear === 'all') return activeDiaryGames;
    return activeDiaryGames.filter((g) => {
      const y = new Date(g.completed_date!).getFullYear();
      return y === selectedYear;
    });
  }, [activeDiaryGames, selectedYear]);

  // Gruppering per månad
  const groupedByMonth = useMemo(() => {
    const groups: { [key: string]: { monthTitle: string; games: Game[] } } = {};
    const order: string[] = [];

    filteredActiveDiaryGames.forEach((game) => {
      const d = new Date(game.completed_date!);
      const key = `${d.getFullYear()}-${d.getMonth()}`;
      if (!groups[key]) {
        const monthTitle = d.toLocaleDateString('sv-SE', { month: 'long', year: 'numeric' });
        groups[key] = {
          monthTitle: monthTitle.charAt(0).toUpperCase() + monthTitle.slice(1),
          games: [],
        };
        order.push(key);
      }
      groups[key].games.push(game);
    });

    return order.map((key) => groups[key]);
  }, [filteredActiveDiaryGames]);

  if (games.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-24 text-center px-4 rounded-2xl border border-dashed border-zinc-800 bg-zinc-950/40">
        <div className="w-16 h-16 rounded-2xl bg-zinc-900 border border-zinc-800 flex items-center justify-center text-zinc-600 mb-4">
          <BarChart3 className="w-8 h-8 text-brand-red" />
        </div>
        <h3 className="text-lg font-semibold text-zinc-200 mb-1">Ingen statistik tillgänglig än</h3>
        <p className="text-xs text-zinc-400 max-w-sm">
          Lägg till spel eller synka med din iPhone för att se din personliga spelstatistik och sammanfattning.
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-8 pb-16 animate-in fade-in duration-200">
      {/* Tab Switcher: Statistik vs Speldagbok */}
      <div className="flex items-center justify-between border-b border-zinc-800 pb-4">
        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={() => setActiveSubTab('overview')}
            className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-bold transition cursor-pointer ${
              activeSubTab === 'overview'
                ? 'bg-zinc-800 text-white shadow-sm'
                : 'text-zinc-400 hover:text-white hover:bg-zinc-900'
            }`}
          >
            <BarChart3 className="w-3.5 h-3.5 text-brand-red" />
            <span>Statistik & Analys</span>
          </button>
          <button
            type="button"
            onClick={() => setActiveSubTab('diary')}
            className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-bold transition cursor-pointer ${
              activeSubTab === 'diary'
                ? 'bg-zinc-800 text-white shadow-sm'
                : 'text-zinc-400 hover:text-white hover:bg-zinc-900'
            }`}
          >
            <BookOpen className="w-3.5 h-3.5 text-purple-400" />
            <span>Speldagbok</span>
            {activeDiaryGames.length > 0 && (
              <span className="px-1.5 py-0.5 rounded-full bg-purple-500/20 text-purple-300 text-[10px]">
                {activeDiaryGames.length}
              </span>
            )}
          </button>
        </div>

        <div className="flex items-center gap-2.5">
          {onOpenWrapped && (
            <button
              type="button"
              onClick={onOpenWrapped}
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-amber-500/15 hover:bg-amber-500/25 text-amber-300 border border-amber-500/30 text-xs font-bold transition shadow-sm cursor-pointer"
            >
              <Crown className="w-3.5 h-3.5 text-amber-400" />
              <span>Spelåret Wrapped 👑</span>
            </button>
          )}
          <span className="hidden sm:inline-block text-xs px-2.5 py-1 rounded-full bg-zinc-900 text-zinc-400 border border-zinc-800">
            {totalGames} spel totalt
          </span>
        </div>
      </div>

      {/* ==================== SUB-TAB 1: ÖVERSIKT ==================== */}
      {activeSubTab === 'overview' && (
        <div className="space-y-8">
          {/* KPI Cards Grid */}
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4">
            {/* Total Games */}
            <div className="p-3.5 sm:p-5 rounded-2xl bg-zinc-900/60 border border-zinc-800 shadow-md flex flex-col justify-between">
              <div className="flex items-center justify-between">
                <span className="text-[10px] sm:text-xs font-semibold uppercase tracking-wider text-zinc-400">Totalt</span>
                <div className="w-7 h-7 sm:w-8 sm:h-8 rounded-xl bg-brand-red/10 border border-brand-red/30 flex items-center justify-center text-brand-red">
                  <Gamepad2 className="w-3.5 h-3.5 sm:w-4 sm:h-4" />
                </div>
              </div>
              <div className="mt-3 sm:mt-4">
                <div className="text-2xl sm:text-3xl font-extrabold text-white">{totalGames}</div>
                <div className="text-[11px] sm:text-xs text-zinc-400 mt-1">
                  {ownedGames} ägda titlar
                </div>
              </div>
            </div>

            {/* Total Playtime */}
            <div className="p-3.5 sm:p-5 rounded-2xl bg-zinc-900/60 border border-zinc-800 shadow-md flex flex-col justify-between">
              <div className="flex items-center justify-between">
                <span className="text-[10px] sm:text-xs font-semibold uppercase tracking-wider text-zinc-400">Speltid (est.)</span>
                <div className="w-7 h-7 sm:w-8 sm:h-8 rounded-xl bg-amber-500/10 border border-amber-500/30 flex items-center justify-center text-amber-400">
                  <Clock className="w-3.5 h-3.5 sm:w-4 sm:h-4" />
                </div>
              </div>
              <div className="mt-3 sm:mt-4">
                <div className="text-2xl sm:text-3xl font-extrabold text-white">
                  {totalEstimatedHours > 0 ? `${totalEstimatedHours}h` : '—'}
                </div>
                <div className="text-[11px] sm:text-xs text-zinc-400 mt-1">
                  {backlogHours > 0 ? `${backlogHours}h i backlog` : 'Beräknad HLTB-tid'}
                </div>
              </div>
            </div>

            {/* Completed */}
            <div className="p-3.5 sm:p-5 rounded-2xl bg-zinc-900/60 border border-zinc-800 shadow-md flex flex-col justify-between">
              <div className="flex items-center justify-between">
                <span className="text-[10px] sm:text-xs font-semibold uppercase tracking-wider text-zinc-400">Avklarat</span>
                <div className="w-7 h-7 sm:w-8 sm:h-8 rounded-xl bg-teal-500/10 border border-teal-500/30 flex items-center justify-center text-teal-400">
                  <Trophy className="w-3.5 h-3.5 sm:w-4 sm:h-4" />
                </div>
              </div>
              <div className="mt-3 sm:mt-4">
                <div className="text-2xl sm:text-3xl font-extrabold text-white">
                  {completedGames}
                </div>
                <div className="text-[11px] sm:text-xs text-teal-400 font-semibold mt-1">
                  {completionRate}% av samlingen
                </div>
              </div>
            </div>

            {/* Average Rating */}
            <div className="p-3.5 sm:p-5 rounded-2xl bg-zinc-900/60 border border-zinc-800 shadow-md flex flex-col justify-between">
              <div className="flex items-center justify-between">
                <span className="text-[10px] sm:text-xs font-semibold uppercase tracking-wider text-zinc-400">Snittbetyg</span>
                <div className="w-7 h-7 sm:w-8 sm:h-8 rounded-xl bg-yellow-500/10 border border-yellow-500/30 flex items-center justify-center text-yellow-400">
                  <Star className="w-3.5 h-3.5 sm:w-4 sm:h-4" />
                </div>
              </div>
              <div className="mt-3 sm:mt-4">
                <div className="text-2xl sm:text-3xl font-extrabold text-white">
                  {averageRating ? `${averageRating}/10` : '—'}
                </div>
                <div className="text-[11px] sm:text-xs text-zinc-400 mt-1">
                  {ratedGames.length} betygsatta spel
                </div>
              </div>
            </div>
          </div>

          {/* Grids: Status och Plattformar */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 sm:gap-6">
            {/* Status Distribution */}
            <div className="p-4 sm:p-6 rounded-2xl bg-zinc-900/60 border border-zinc-800 shadow-md space-y-4">
              <h3 className="text-sm font-bold text-white flex items-center gap-2">
                <Sparkles className="w-4 h-4 text-teal-400" />
                <span>Statusfördelning</span>
              </h3>

              <div className="space-y-3">
                {statusStats.statuses.map((item) => (
                  <div key={item.status} className="space-y-1.5">
                    <div className="flex items-center justify-between text-xs">
                      <span className="font-medium text-zinc-200">{item.label}</span>
                      <span className="text-zinc-400">
                        {item.count} spel ({item.percentage}%)
                      </span>
                    </div>
                    <div className="w-full h-2 rounded-full bg-zinc-950 overflow-hidden">
                      <div
                        style={{ width: `${item.percentage}%` }}
                        className="h-full bg-teal-500 rounded-full transition-all duration-500"
                      />
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* Platform Distribution */}
            <div className="p-4 sm:p-6 rounded-2xl bg-zinc-900/60 border border-zinc-800 shadow-md space-y-4">
              <h3 className="text-sm font-bold text-white flex items-center gap-2">
                <Gamepad2 className="w-4 h-4 text-purple-400" />
                <span>Topp-plattformar</span>
              </h3>

              <div className="space-y-3">
                {platformStats.slice(0, 5).map((item) => (
                  <div key={item.platform} className="space-y-1.5">
                    <div className="flex items-center justify-between text-xs">
                      <span className="font-medium text-zinc-200 truncate">{item.platform}</span>
                      <span className="text-zinc-400">
                        {item.count} spel ({item.percentage}%)
                      </span>
                    </div>
                    <div className="w-full h-2 rounded-full bg-zinc-950 overflow-hidden">
                      <div
                        style={{ width: `${item.percentage}%` }}
                        className="h-full bg-gradient-to-r from-purple-500 to-indigo-500 rounded-full transition-all duration-500"
                      />
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>

          {/* Top rated games showcase */}
          {topRatedGames.length > 0 && (
            <div className="p-4 sm:p-6 rounded-2xl bg-zinc-900/60 border border-zinc-800 shadow-md space-y-4">
              <div className="flex items-center justify-between">
                <h3 className="text-sm font-bold text-white flex items-center gap-2">
                  <Star className="w-4 h-4 text-amber-400 fill-current" />
                  <span>Dina högst betygsatta mästerverk (8–10/10)</span>
                </h3>
              </div>

              <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-6 gap-4">
                {topRatedGames.map((game) => (
                  <div
                    key={game.id}
                    onClick={() => onSelectGame(game)}
                    className="group cursor-pointer flex flex-col bg-zinc-950/60 border border-zinc-800 hover:border-zinc-700 rounded-xl overflow-hidden shadow transition"
                  >
                    <div className="relative w-full aspect-[3/4] bg-zinc-900 overflow-hidden">
                      {game.cover_url ? (
                        <img
                          src={game.cover_url}
                          alt={game.title}
                          className="w-full h-full object-cover group-hover:scale-105 transition duration-300"
                        />
                      ) : (
                        <div className="w-full h-full flex items-center justify-center p-2 text-center text-xs text-zinc-500">
                          {game.title}
                        </div>
                      )}

                      <div className="absolute top-2 right-2 flex items-center gap-0.5 px-1.5 py-0.5 rounded bg-black/80 backdrop-blur-md text-amber-400 text-[11px] font-bold border border-amber-500/30">
                        <Star className="w-2.5 h-2.5 fill-current" />
                        <span>{game.rating}</span>
                      </div>
                    </div>

                    <div className="p-2.5">
                      <h4 className="font-semibold text-xs text-zinc-200 group-hover:text-brand-red truncate">
                        {game.title}
                      </h4>
                      <p className="text-[10px] text-zinc-500 truncate mt-0.5">
                        {game.platforms?.[0] || 'Spel'}
                      </p>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      )}

      {/* ==================== SUB-TAB 2: SPELDAGBOK ==================== */}
      {activeSubTab === 'diary' && (
        <div className="space-y-6">
          {/* Sub-mode selector: Kronologisk Dagbok vs Spelminnen */}
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 bg-zinc-900/60 border border-zinc-800 rounded-2xl p-4">
            <div className="flex items-center gap-1.5 bg-zinc-950 p-1 rounded-xl border border-zinc-800">
              <button
                type="button"
                onClick={() => setDiaryMode('active')}
                className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition cursor-pointer ${
                  diaryMode === 'active'
                    ? 'bg-zinc-800 text-white shadow-sm'
                    : 'text-zinc-400 hover:text-white'
                }`}
              >
                Tidslinje ({activeDiaryGames.length})
              </button>
              <button
                type="button"
                onClick={() => setDiaryMode('memories')}
                className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition cursor-pointer ${
                  diaryMode === 'memories'
                    ? 'bg-zinc-800 text-white shadow-sm'
                    : 'text-zinc-400 hover:text-white'
                }`}
              >
                Spelminnen / Nostalgi ({memoryGames.length})
              </button>
            </div>

            {diaryMode === 'active' && (
              <div className="flex items-center gap-2">
                <span className="text-xs text-zinc-400 font-medium">Filtrera år:</span>
                <select
                  value={selectedYear}
                  onChange={(e) => setSelectedYear(e.target.value === 'all' ? 'all' : Number(e.target.value))}
                  className="bg-zinc-950 border border-zinc-800 text-white rounded-lg px-2.5 py-1.5 text-xs font-semibold focus:outline-none focus:border-purple-500 cursor-pointer"
                >
                  <option value="all">Alla år</option>
                  {availableYears.map((yr) => (
                    <option key={yr} value={yr}>
                      {yr}
                    </option>
                  ))}
                </select>
              </div>
            )}
          </div>

          {/* ACTIVE DIARY TIMELINE */}
          {diaryMode === 'active' && (
            <div className="space-y-8">
              {groupedByMonth.length === 0 ? (
                <div className="text-center py-16 bg-zinc-900/30 border border-dashed border-zinc-800 rounded-2xl p-6">
                  <BookOpen className="w-10 h-10 text-zinc-600 mx-auto mb-3" />
                  <h4 className="text-sm font-bold text-zinc-300">Inga genomspelningar med klardatum</h4>
                  <p className="text-xs text-zinc-500 mt-1 max-w-sm mx-auto">
                    När du klarar spel i Gameshelf och sparar med ett klardatum dyker de upp här i din månadsvisa speldagbok.
                  </p>
                </div>
              ) : (
                groupedByMonth.map((group) => (
                  <div key={group.monthTitle} className="space-y-3">
                    {/* Month Header */}
                    <div className="flex items-center gap-2 border-b border-zinc-800/80 pb-2">
                      <Calendar className="w-4 h-4 text-purple-400" />
                      <h3 className="text-sm font-bold text-white">{group.monthTitle}</h3>
                      <span className="text-[11px] text-zinc-500 ml-auto">
                        {group.games.length} {group.games.length === 1 ? 'spel' : 'spel'}
                      </span>
                    </div>

                    {/* Monthly Cards */}
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                      {group.games.map((game) => (
                        <div
                          key={game.id}
                          onClick={() => onSelectGame(game)}
                          className="group flex gap-3.5 p-3.5 bg-zinc-900/70 hover:bg-zinc-850/80 border border-zinc-800 hover:border-zinc-700 rounded-xl transition cursor-pointer"
                        >
                          {/* Cover */}
                          <div className="w-14 h-18 bg-zinc-800 rounded-lg overflow-hidden shrink-0 shadow-sm">
                            {game.cover_url ? (
                              <img
                                src={game.cover_url}
                                alt={game.title}
                                className="w-full h-full object-cover group-hover:scale-105 transition"
                              />
                            ) : (
                              <div className="w-full h-full flex items-center justify-center text-zinc-500 text-[10px]">
                                Cover
                              </div>
                            )}
                          </div>

                          {/* Info */}
                          <div className="flex-1 min-w-0 flex flex-col justify-between">
                            <div>
                              <div className="flex items-center justify-between gap-2">
                                <h4 className="text-xs font-bold text-white group-hover:text-purple-300 truncate">
                                  {game.title}
                                </h4>
                                {game.rating && game.rating > 0 && (
                                  <span className="shrink-0 flex items-center gap-0.5 px-1.5 py-0.5 bg-yellow-500/10 border border-yellow-500/20 text-yellow-400 text-[10px] font-bold rounded">
                                    <Star className="w-2.5 h-2.5 fill-current" />
                                    {game.rating}
                                  </span>
                                )}
                              </div>

                              <div className="flex items-center gap-2 mt-1 text-[11px] text-zinc-400">
                                {game.completed_date && (
                                  <span className="text-purple-400 font-semibold">
                                    {new Date(game.completed_date).toLocaleDateString('sv-SE', {
                                      day: 'numeric',
                                      month: 'short',
                                    })}
                                  </span>
                                )}
                                {game.platforms?.[0] && (
                                  <>
                                    <span>•</span>
                                    <span className="truncate">{game.platforms[0]}</span>
                                  </>
                                )}
                              </div>
                            </div>

                            {game.notes && (
                              <p className="text-[11px] text-zinc-400 italic line-clamp-1 mt-1.5 border-l-2 border-purple-500/40 pl-2">
                                “{game.notes}”
                              </p>
                            )}
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                ))
              )}
            </div>
          )}

          {/* SPELMINNEN / NOSTALGI */}
          {diaryMode === 'memories' && (
            <div className="space-y-4">
              <div className="p-4 rounded-xl bg-purple-950/20 border border-purple-500/20 text-xs text-purple-300 flex items-center gap-3">
                <Archive className="w-5 h-5 text-purple-400 shrink-0" />
                <span>
                  Här samlas äldre spel du redan klarat tidigare i livet (retro/barndomsspel). De räknas som avklarade i din samling men förorenar inte årets månadsvisa tidslinje.
                </span>
              </div>

              {memoryGames.length === 0 ? (
                <div className="text-center py-16 bg-zinc-900/30 border border-dashed border-zinc-800 rounded-2xl p-6">
                  <Archive className="w-10 h-10 text-zinc-600 mx-auto mb-3" />
                  <h4 className="text-sm font-bold text-zinc-300">Inga spelminnen tillagda än</h4>
                  <p className="text-xs text-zinc-500 mt-1 max-w-sm mx-auto">
                    När du söker och snabbt lägger till gamla spel du redan klarat sparas de här.
                  </p>
                </div>
              ) : (
                <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-3">
                  {memoryGames.map((game) => (
                    <div
                      key={game.id}
                      onClick={() => onSelectGame(game)}
                      className="group cursor-pointer flex flex-col bg-zinc-900/60 hover:bg-zinc-850/80 border border-zinc-800 hover:border-zinc-700 rounded-xl overflow-hidden shadow transition"
                    >
                      <div className="relative w-full aspect-[3/4] bg-zinc-900 overflow-hidden">
                        {game.cover_url ? (
                          <img
                            src={game.cover_url}
                            alt={game.title}
                            className="w-full h-full object-cover group-hover:scale-105 transition"
                          />
                        ) : (
                          <div className="w-full h-full flex items-center justify-center p-2 text-center text-xs text-zinc-500">
                            {game.title}
                          </div>
                        )}

                        {game.rating && game.rating > 0 && (
                          <div className="absolute top-2 right-2 flex items-center gap-0.5 px-1.5 py-0.5 rounded bg-black/80 backdrop-blur-md text-amber-400 text-[10px] font-bold border border-amber-500/30">
                            <Star className="w-2.5 h-2.5 fill-current" />
                            <span>{game.rating}</span>
                          </div>
                        )}
                      </div>

                      <div className="p-2.5">
                        <h4 className="font-semibold text-xs text-zinc-200 group-hover:text-purple-300 truncate">
                          {game.title}
                        </h4>
                        <div className="flex items-center justify-between text-[10px] text-zinc-500 mt-0.5">
                          <span>{game.release_year || 'Klarat'}</span>
                          <span className="truncate max-w-[70px]">{game.platforms?.[0]}</span>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
