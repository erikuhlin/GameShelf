'use client';

import React from 'react';
import { Game, PlayStatus, PLAY_STATUSES } from '@/types/game';
import { getStatusDisplayTitle } from '@/lib/statusHelper';
import {
  BarChart3,
  Trophy,
  Clock,
  Star,
  Gamepad2,
  Sparkles,
} from 'lucide-react';

interface StatsDashboardViewProps {
  games: Game[];
  onSelectGame: (game: Game) => void;
}

export function StatsDashboardView({ games, onSelectGame }: StatsDashboardViewProps) {
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
  const statusStats = React.useMemo(() => {
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
  const platformStats = React.useMemo(() => {
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
  const genreStats = React.useMemo(() => {
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
  const topRatedGames = React.useMemo(() => {
    return games
      .filter((g) => g.rating && g.rating >= 8)
      .sort((a, b) => (b.rating || 0) - (a.rating || 0))
      .slice(0, 6);
  }, [games]);

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

  const getStatusColor = (status: PlayStatus) => {
    switch (status) {
      case 'playing':
        return 'bg-emerald-500 text-emerald-400 border-emerald-500/40';
      case 'notStarted':
        return 'bg-zinc-500 text-zinc-400 border-zinc-500/40';
      case 'paused':
        return 'bg-amber-500 text-amber-400 border-amber-500/40';
      case 'completed':
        return 'bg-teal-500 text-teal-400 border-teal-500/40';
      case 'abandoned':
        return 'bg-zinc-600 text-zinc-400 border-zinc-500/40';
    }
  };

  return (
    <div className="space-y-8 pb-16 animate-in fade-in duration-200">
      {/* Header */}
      <div>
        <div className="flex items-center gap-2.5">
          <h2 className="text-2xl font-bold text-white tracking-tight">Statistik & Översikt</h2>
          <span className="text-xs px-2.5 py-0.5 rounded-full bg-zinc-800 text-zinc-400 border border-zinc-700">
            {totalGames} spel analyserade
          </span>
        </div>
        <p className="text-xs text-zinc-400 mt-1">
          En samlad överblick över din speltid, avklarade titlar och favoritplattformar
        </p>
      </div>

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
            <div className="text-2xl sm:text-3xl font-extrabold text-white">{totalEstimatedHours}h</div>
            <div className="text-[11px] sm:text-xs text-zinc-400 mt-1">
              {backlogHours}h i backloggen
            </div>
          </div>
        </div>

        {/* Completion Rate */}
        <div className="p-3.5 sm:p-5 rounded-2xl bg-zinc-900/60 border border-zinc-800 shadow-md flex flex-col justify-between">
          <div className="flex items-center justify-between">
            <span className="text-[10px] sm:text-xs font-semibold uppercase tracking-wider text-zinc-400">Avklarade</span>
            <div className="w-7 h-7 sm:w-8 sm:h-8 rounded-xl bg-emerald-500/10 border border-emerald-500/30 flex items-center justify-center text-emerald-400">
              <Trophy className="w-3.5 h-3.5 sm:w-4 sm:h-4" />
            </div>
          </div>
          <div className="mt-3 sm:mt-4">
            <div className="text-2xl sm:text-3xl font-extrabold text-white">{completionRate}%</div>
            <div className="text-[11px] sm:text-xs text-zinc-400 mt-1">
              {completedGames} av {playedCount} spel
            </div>
          </div>
        </div>

        {/* Average Rating */}
        <div className="p-3.5 sm:p-5 rounded-2xl bg-zinc-900/60 border border-zinc-800 shadow-md flex flex-col justify-between">
          <div className="flex items-center justify-between">
            <span className="text-[10px] sm:text-xs font-semibold uppercase tracking-wider text-zinc-400">Snittbetyg</span>
            <div className="w-7 h-7 sm:w-8 sm:h-8 rounded-xl bg-yellow-500/10 border border-yellow-500/30 flex items-center justify-center text-yellow-400">
              <Star className="w-3.5 h-3.5 sm:w-4 sm:h-4 fill-current" />
            </div>
          </div>
          <div className="mt-3 sm:mt-4">
            <div className="text-2xl sm:text-3xl font-extrabold text-white">
              {averageRating ? `${averageRating}/10` : '–'}
            </div>
            <div className="text-[11px] sm:text-xs text-zinc-400 mt-1">
              {ratedGames.length} betygsatta spel
            </div>
          </div>
        </div>
      </div>

      {/* Status Breakdown Section */}
      <div className="p-6 rounded-2xl bg-zinc-900/60 border border-zinc-800 shadow-md space-y-4">
        <h3 className="text-sm font-bold text-white flex items-center gap-2">
          <BarChart3 className="w-4 h-4 text-brand-red" />
          <span>Statusfördelning i biblioteket</span>
        </h3>

        {/* Visual composite progress bar */}
        <div className="w-full h-3.5 rounded-full bg-zinc-950 overflow-hidden flex border border-zinc-800">
          {statusStats.statuses.map((item) => {
            if (item.count === 0) return null;
            return (
              <div
                key={item.status}
                style={{ width: `${item.percentage}%` }}
                className={`${getStatusColor(item.status).split(' ')[0]} transition-all duration-500`}
                title={`${item.label}: ${item.count} spel (${item.percentage}%)`}
              />
            );
          })}
        </div>

        {/* Legend */}
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-6 gap-3 pt-2">
          {statusStats.statuses.map((item) => (
            <div key={item.status} className="p-3 rounded-xl bg-zinc-950/60 border border-zinc-800/80 flex items-center gap-3">
              <span className={`w-3 h-3 rounded-full ${getStatusColor(item.status).split(' ')[0]}`}></span>
              <div>
                <div className="text-xs font-semibold text-zinc-200">{item.label}</div>
                <div className="text-[11px] text-zinc-400">{item.count} st ({item.percentage}%)</div>
              </div>
            </div>
          ))}

          {/* Backlog Item */}
          <div className="p-3 rounded-xl bg-blue-950/30 border border-blue-800/40 flex items-center gap-3">
            <span className="w-3 h-3 rounded-full bg-blue-500"></span>
            <div>
              <div className="text-xs font-semibold text-blue-200">Backlog</div>
              <div className="text-[11px] text-blue-300/80">{statusStats.backlog.count} st ({statusStats.backlog.percentage}%)</div>
            </div>
          </div>
        </div>
      </div>

      {/* Two columns: Platforms & Genres */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Platforms breakdown */}
        <div className="p-6 rounded-2xl bg-zinc-900/60 border border-zinc-800 shadow-md space-y-4">
          <h3 className="text-sm font-bold text-white flex items-center gap-2">
            <Gamepad2 className="w-4 h-4 text-rose-400" />
            <span>Topp-plattformar</span>
          </h3>

          <div className="space-y-3">
            {platformStats.map((item) => (
              <div key={item.platform} className="space-y-1.5">
                <div className="flex items-center justify-between text-xs">
                  <span className="font-medium text-zinc-200 truncate">{item.platform}</span>
                  <span className="text-zinc-400">{item.count} {item.count === 1 ? 'spel' : 'spel'}</span>
                </div>
                <div className="w-full h-2 rounded-full bg-zinc-950 overflow-hidden">
                  <div
                    style={{ width: `${item.percentage}%` }}
                    className="h-full bg-gradient-to-r from-brand-red to-rose-500 rounded-full transition-all duration-500"
                  />
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Genres breakdown */}
        <div className="p-6 rounded-2xl bg-zinc-900/60 border border-zinc-800 shadow-md space-y-4">
          <h3 className="text-sm font-bold text-white flex items-center gap-2">
            <Sparkles className="w-4 h-4 text-amber-400" />
            <span>Populäraste genrer</span>
          </h3>

          <div className="space-y-3">
            {genreStats.map((item) => (
              <div key={item.genre} className="space-y-1.5">
                <div className="flex items-center justify-between text-xs">
                  <span className="font-medium text-zinc-200 truncate">{item.genre}</span>
                  <span className="text-zinc-400">{item.count} spel</span>
                </div>
                <div className="w-full h-2 rounded-full bg-zinc-950 overflow-hidden">
                  <div
                    style={{ width: `${item.percentage}%` }}
                    className="h-full bg-gradient-to-r from-amber-500 to-yellow-400 rounded-full transition-all duration-500"
                  />
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Top rated games showcase */}
      {topRatedGames.length > 0 && (
        <div className="p-6 rounded-2xl bg-zinc-900/60 border border-zinc-800 shadow-md space-y-4">
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
  );
}
