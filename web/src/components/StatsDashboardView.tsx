'use client';

import React, { useState, useMemo } from 'react';
import { Game, PlayStatus, PLAY_STATUSES } from '@/types/game';
import { getStatusDisplayTitle } from '@/lib/statusHelper';
import { isGotySeason, loadUserProfile } from '@/lib/profileStore';
import { calculateSpelDNA } from '@/lib/spelDNA';
import { GamingGoalEngine } from '@/lib/gamingGoalEngine';
import {
  BarChart3,
  Trophy,
  Target,
  Star,
  Gamepad2,
  Sparkles,
  BookOpen,
  Calendar,
  Archive,
  Crown,
  CheckCircle2,
  Dna,
  History,
  TrendingUp,
} from 'lucide-react';

interface StatsDashboardViewProps {
  games: Game[];
  onSelectGame: (game: Game) => void;
  onOpenWrapped?: () => void;
  onOpenGamingGoal?: () => void;
  annualGoal?: number;
}

export function StatsDashboardView({
  games,
  onSelectGame,
  onOpenWrapped,
  onOpenGamingGoal,
  annualGoal,
}: StatsDashboardViewProps) {
  const [activeSubTab, setActiveSubTab] = useState<'overview' | 'diary'>('overview');
  const [diaryMode, setDiaryMode] = useState<'active' | 'memories'>('active');
  const [selectedYear, setSelectedYear] = useState<number | 'all'>(new Date().getFullYear());

  const currentYear = new Date().getFullYear();

  // 1. Beräkningar för KPI-kort
  const totalGames = games.length;
  const ownedGames = games.filter((g) => g.is_owned).length;
  const completedGames = games.filter((g) => g.status === 'completed' && g.is_owned).length;

  // Spelmål beräkningar för innevarande år
  const completedThisYearGames = useMemo(() => {
    return GamingGoalEngine.completedGames(games, currentYear);
  }, [games, currentYear]);
  const completedThisYear = completedThisYearGames.length;

  const effectiveAnnualGoal = useMemo(() => {
    if (annualGoal && annualGoal > 0) return annualGoal;
    if (typeof window !== 'undefined') {
      try {
        const stored = loadUserProfile();
        if (stored?.annualGamingGoal && stored.annualGamingGoal > 0) {
          return stored.annualGamingGoal;
        }
      } catch (e) {
        // Fallback
      }
    }
    return 12;
  }, [annualGoal]);

  const goalProgressPct = Math.min(
    100,
    Math.round((completedThisYear / (effectiveAnnualGoal || 1)) * 100)
  );

  const ratedGames = games.filter((g) => g.rating !== null && g.rating !== undefined && g.rating > 0);
  const averageRating =
    ratedGames.length > 0
      ? (ratedGames.reduce((acc, g) => acc + (g.rating || 0), 0) / ratedGames.length).toFixed(1)
      : null;

  const completionRate =
    ownedGames > 0 ? Math.round((completedGames / ownedGames) * 100) : 0;

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

  // 3. Genrefördelning (ersätter plattformar som var felaktiga)
  const genreStats = useMemo(() => {
    const counts: { [g: string]: number } = {};
    const targetGames = ownedGames > 0 ? games.filter((g) => g.is_owned) : games;
    targetGames.forEach((g) => {
      const genres = g.genres && g.genres.length > 0 ? g.genres : ['Övrigt'];
      genres.forEach((genre) => {
        const clean = genre.trim();
        if (clean) {
          counts[clean] = (counts[clean] || 0) + 1;
        }
      });
    });

    const baseCount = targetGames.length;
    return Object.entries(counts)
      .map(([genre, count]) => ({
        genre,
        count,
        percentage: baseCount > 0 ? Math.round((count / baseCount) * 100) : 0,
      }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 6);
  }, [games, ownedGames]);

  // 4. Epoker & Tidsresan (Lanseringsårtionden)
  const eraStats = useMemo(() => {
    const datedGames = games.filter((g) => g.release_year && g.release_year > 0);
    const totalDated = datedGames.length;
    if (totalDated === 0) return [];

    let c2020 = 0;
    let c2010 = 0;
    let c2000 = 0;
    let c1990 = 0;
    let cRetro = 0;

    datedGames.forEach((g) => {
      const y = g.release_year!;
      if (y >= 2020) c2020++;
      else if (y >= 2010) c2010++;
      else if (y >= 2000) c2000++;
      else if (y >= 1990) c1990++;
      else cRetro++;
    });

    const eras = [
      { label: '2020-talet', sub: '2020 – nutid', count: c2020, barColor: 'bg-gradient-to-r from-blue-500 to-indigo-500' },
      { label: '2010-talet', sub: '2010 – 2019', count: c2010, barColor: 'bg-gradient-to-r from-purple-500 to-pink-500' },
      { label: '2000-talet', sub: '2000 – 2009', count: c2000, barColor: 'bg-gradient-to-r from-amber-500 to-yellow-500' },
      { label: '90-talet', sub: '1990 – 1999', count: c1990, barColor: 'bg-gradient-to-r from-teal-500 to-emerald-500' },
      { label: 'Retro & Klassiker', sub: 'Före 1990', count: cRetro, barColor: 'bg-gradient-to-r from-rose-500 to-red-600' },
    ];

    return eras
      .filter((e) => e.count > 0)
      .map((e) => ({
        ...e,
        percentage: Math.round((e.count / totalDated) * 100),
      }));
  }, [games]);

  // 5. Betygsfördelning (1–10)
  const ratingDistribution = useMemo(() => {
    const counts: Record<number, number> = { 10: 0, 9: 0, 8: 0, 7: 0, 6: 0, 5: 0, 4: 0, 3: 0, 2: 0, 1: 0 };
    let maxCount = 0;
    let totalRatings = 0;

    games.forEach((g) => {
      if (g.rating && g.rating >= 1 && g.rating <= 10) {
        counts[g.rating] = (counts[g.rating] || 0) + 1;
        totalRatings++;
        if (counts[g.rating] > maxCount) maxCount = counts[g.rating];
      }
    });

    const items = [10, 9, 8, 7, 6, 5, 4, 3, 2, 1].map((rating) => ({
      rating,
      count: counts[rating],
      percentage: totalRatings > 0 ? Math.round((counts[rating] / totalRatings) * 100) : 0,
    }));

    return {
      items,
      totalRatings,
      maxCount,
    };
  }, [games]);

  // 6. Spel-DNA Profil
  const spelDNA = useMemo(() => {
    try {
      const stored = typeof window !== 'undefined' ? loadUserProfile() : null;
      return calculateSpelDNA(
        games,
        stored?.playFor || [],
        stored?.favoriteGenres || [],
        stored?.favoriteGameIDs || [],
        stored?.playstyle || []
      );
    } catch (e) {
      return null;
    }
  }, [games]);

  // 7. Topprankade spel (Betyg 8-10)
  const topRatedGames = useMemo(() => {
    return games
      .filter((g) => g.rating && g.rating >= 8)
      .sort((a, b) => (b.rating || 0) - (a.rating || 0))
      .slice(0, 6);
  }, [games]);

  // ==================== SPELDAGBOK DATA ====================
  // Aktiva genomspelningar med loggat datum ELLER avklarat år
  const activeDiaryGames = useMemo(() => {
    return games
      .filter(
        (g) =>
          g.status === 'completed' &&
          (Boolean(g.completed_date) || (Boolean(g.completed_year) && g.completed_year! > 0))
      )
      .sort((a, b) => {
        const timeA = a.completed_date
          ? new Date(a.completed_date).getTime()
          : new Date(a.completed_year!, 0, 1).getTime();
        const timeB = b.completed_date
          ? new Date(b.completed_date).getTime()
          : new Date(b.completed_year!, 0, 1).getTime();
        return timeB - timeA;
      });
  }, [games]);

  // Spelminnen (completed utan varken klardatum eller avklarat år)
  const memoryGames = useMemo(() => {
    return games
      .filter(
        (g) =>
          g.status === 'completed' &&
          !g.completed_date &&
          (!g.completed_year || g.completed_year <= 0)
      )
      .sort((a, b) => (b.release_year || 0) - (a.release_year || 0));
  }, [games]);

  // Tillgängliga år för aktiv dagbok
  const availableYears = useMemo(() => {
    const years = new Set<number>();
    years.add(currentYear);
    activeDiaryGames.forEach((g) => {
      if (g.completed_date) {
        const y = new Date(g.completed_date).getFullYear();
        if (!isNaN(y)) years.add(y);
      } else if (g.completed_year && g.completed_year > 0) {
        years.add(g.completed_year);
      }
    });
    return Array.from(years).sort((a, b) => b - a);
  }, [activeDiaryGames, currentYear]);

  // Filtrerade spel för vald period
  const filteredActiveDiaryGames = useMemo(() => {
    if (selectedYear === 'all') return activeDiaryGames;
    return activeDiaryGames.filter((g) => {
      if (g.completed_date) {
        return new Date(g.completed_date).getFullYear() === selectedYear;
      }
      return g.completed_year === selectedYear;
    });
  }, [activeDiaryGames, selectedYear]);

  // Gruppering per månad / år
  const groupedByMonth = useMemo(() => {
    const groups: { [key: string]: { monthTitle: string; games: Game[] } } = {};
    const order: string[] = [];

    filteredActiveDiaryGames.forEach((game) => {
      let key: string;
      let monthTitle: string;

      if (game.completed_date) {
        const d = new Date(game.completed_date);
        key = `${d.getFullYear()}-${d.getMonth()}`;
        const rawTitle = d.toLocaleDateString('sv-SE', { month: 'long', year: 'numeric' });
        monthTitle = rawTitle.charAt(0).toUpperCase() + rawTitle.slice(1);
      } else {
        const y = game.completed_year || currentYear;
        key = `${y}-undated`;
        monthTitle = `År ${y} (Genomspelat)`;
      }

      if (!groups[key]) {
        groups[key] = {
          monthTitle,
          games: [],
        };
        order.push(key);
      }
      groups[key].games.push(game);
    });

    return order.map((key) => groups[key]);
  }, [filteredActiveDiaryGames, currentYear]);

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
          {onOpenWrapped && isGotySeason() && (
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
                  {ownedGames} i samlingen
                </div>
              </div>
            </div>

            {/* Spelmål {currentYear} (Ersätter missvisande speltid) */}
            <div
              onClick={onOpenGamingGoal}
              className={`p-3.5 sm:p-5 rounded-2xl bg-zinc-900/60 border border-zinc-800 shadow-md flex flex-col justify-between transition ${
                onOpenGamingGoal ? 'cursor-pointer hover:border-amber-500/40 hover:bg-zinc-900/90 group' : ''
              }`}
            >
              <div className="flex items-center justify-between">
                <span className="text-[10px] sm:text-xs font-semibold uppercase tracking-wider text-zinc-400 group-hover:text-amber-400 transition">
                  Spelmål {currentYear}
                </span>
                <div className="w-7 h-7 sm:w-8 sm:h-8 rounded-xl bg-amber-500/10 border border-amber-500/30 flex items-center justify-center text-amber-400 group-hover:scale-105 transition">
                  <Trophy className="w-3.5 h-3.5 sm:w-4 sm:h-4" />
                </div>
              </div>
              <div className="mt-3 sm:mt-4">
                <div className="flex items-baseline gap-1.5">
                  <span className="text-2xl sm:text-3xl font-extrabold text-white">{completedThisYear}</span>
                  <span className="text-xs font-semibold text-zinc-500">/ {effectiveAnnualGoal} klara</span>
                </div>
                <div className="mt-2 w-full h-1.5 rounded-full bg-zinc-950 overflow-hidden">
                  <div
                    style={{ width: `${goalProgressPct}%` }}
                    className="h-full bg-gradient-to-r from-amber-500 to-yellow-400 rounded-full transition-all duration-500"
                  />
                </div>
                <div className="flex items-center justify-between text-[11px] sm:text-xs text-amber-400 font-medium mt-1.5">
                  <span>{goalProgressPct}% uppnått</span>
                  {onOpenGamingGoal && (
                    <span className="text-[10px] text-zinc-500 group-hover:text-amber-300 transition">Mål →</span>
                  )}
                </div>
              </div>
            </div>

            {/* Completed */}
            <div className="p-3.5 sm:p-5 rounded-2xl bg-zinc-900/60 border border-zinc-800 shadow-md flex flex-col justify-between">
              <div className="flex items-center justify-between">
                <span className="text-[10px] sm:text-xs font-semibold uppercase tracking-wider text-zinc-400">Avklarat</span>
                <div className="w-7 h-7 sm:w-8 sm:h-8 rounded-xl bg-teal-500/10 border border-teal-500/30 flex items-center justify-center text-teal-400">
                  <CheckCircle2 className="w-3.5 h-3.5 sm:w-4 sm:h-4" />
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

          {/* SPEL-DNA / GAMER PROFILE HIGHLIGHT */}
          {spelDNA && (
            <div
              style={{
                borderColor: `${spelDNA.accentHex || '#a855f7'}30`,
              }}
              className="p-4 sm:p-6 rounded-2xl bg-gradient-to-r from-purple-950/20 via-zinc-900/80 to-zinc-900/60 border shadow-lg relative overflow-hidden"
            >
              <div
                style={{ background: spelDNA.accentHex || '#a855f7' }}
                className="absolute top-0 right-0 w-64 h-64 opacity-10 rounded-full blur-3xl pointer-events-none"
              />
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 relative">
                <div className="flex items-start sm:items-center gap-3.5">
                  <div
                    style={{
                      background: `${spelDNA.accentHex || '#a855f7'}20`,
                      borderColor: `${spelDNA.accentHex || '#a855f7'}40`,
                    }}
                    className="w-12 h-12 rounded-2xl border flex items-center justify-center text-2xl shrink-0 shadow-sm"
                  >
                    {spelDNA.icon || '🎮'}
                  </div>
                  <div>
                    <div className="flex items-center gap-2">
                      <span
                        style={{ color: spelDNA.accentHex || '#c084fc' }}
                        className="text-[10px] font-bold uppercase tracking-wider flex items-center gap-1"
                      >
                        <Dna className="w-3 h-3" /> Ditt Spel-DNA
                      </span>
                    </div>
                    <h3 className="text-base sm:text-lg font-extrabold text-white">
                      {spelDNA.title}
                    </h3>
                    <p className="text-xs text-zinc-400 max-w-xl mt-0.5">
                      {spelDNA.description}
                    </p>
                  </div>
                </div>

                <div className="flex flex-col sm:items-end gap-2 shrink-0">
                  {spelDNA.supportingStats && spelDNA.supportingStats.length > 0 && (
                    <div className="flex items-center gap-1.5 flex-wrap sm:justify-end">
                      {spelDNA.supportingStats.slice(0, 3).map((stat, i) => (
                        <span
                          key={i}
                          style={{
                            borderColor: `${spelDNA.accentHex || '#a855f7'}40`,
                            color: spelDNA.accentHex || '#e9d5ff',
                          }}
                          className="px-2.5 py-1 rounded-lg bg-zinc-950/70 border text-[11px] font-semibold flex items-center gap-1"
                        >
                          <span>{stat}</span>
                        </span>
                      ))}
                    </div>
                  )}

                  {spelDNA.secondaryArchetypes && spelDNA.secondaryArchetypes.length > 0 && (
                    <div className="flex items-center gap-1.5 flex-wrap sm:justify-end">
                      <span className="text-[10px] font-bold uppercase tracking-wider text-zinc-500">
                        Sekundärt:
                      </span>
                      {spelDNA.secondaryArchetypes.map((sec) => (
                        <span
                          key={sec.archetypeID}
                          style={{
                            borderColor: `${sec.accentHex}40`,
                            background: `${sec.accentHex}15`,
                          }}
                          className="inline-flex items-center gap-1 px-2 py-0.5 rounded-lg border text-[11px] font-bold text-white shadow-sm"
                        >
                          <span>{sec.icon}</span>
                          <span>{sec.title}</span>
                          <span style={{ color: sec.accentHex }} className="text-[10px] font-black">
                            {sec.matchPercentage}%
                          </span>
                        </span>
                      ))}
                    </div>
                  )}
                </div>
              </div>
            </div>
          )}

          {/* Sektion 1: Statusfördelning & Mest spelade genrer */}
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

            {/* Mest spelade genrer (Ersätter Topp-plattformar) */}
            <div className="p-4 sm:p-6 rounded-2xl bg-zinc-900/60 border border-zinc-800 shadow-md space-y-4">
              <h3 className="text-sm font-bold text-white flex items-center gap-2">
                <Gamepad2 className="w-4 h-4 text-purple-400" />
                <span>Mest spelade genrer</span>
              </h3>

              {genreStats.length === 0 ? (
                <div className="text-xs text-zinc-500 py-6 text-center">Inga genrer registrerade än.</div>
              ) : (
                <div className="space-y-3">
                  {genreStats.map((item) => (
                    <div key={item.genre} className="space-y-1.5">
                      <div className="flex items-center justify-between text-xs">
                        <span className="font-medium text-zinc-200 truncate">{item.genre}</span>
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
              )}
            </div>
          </div>

          {/* Sektion 2: Epoker (Tidsresan) & Betygsfördelning */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 sm:gap-6">
            {/* Epoker / Lanseringsårtionden */}
            <div className="p-4 sm:p-6 rounded-2xl bg-zinc-900/60 border border-zinc-800 shadow-md space-y-4">
              <div className="flex items-center justify-between">
                <h3 className="text-sm font-bold text-white flex items-center gap-2">
                  <History className="w-4 h-4 text-blue-400" />
                  <span>Tidsresan: Spel per epok</span>
                </h3>
              </div>

              {eraStats.length === 0 ? (
                <div className="text-xs text-zinc-500 py-6 text-center">Inga lanseringsår tillgängliga.</div>
              ) : (
                <div className="space-y-3">
                  {eraStats.map((era) => (
                    <div key={era.label} className="space-y-1.5">
                      <div className="flex items-center justify-between text-xs">
                        <div className="flex items-center gap-1.5">
                          <span className="font-medium text-zinc-200">{era.label}</span>
                          <span className="text-[10px] text-zinc-500">({era.sub})</span>
                        </div>
                        <span className="text-zinc-400">
                          {era.count} spel ({era.percentage}%)
                        </span>
                      </div>
                      <div className="w-full h-2 rounded-full bg-zinc-950 overflow-hidden">
                        <div
                          style={{ width: `${era.percentage}%` }}
                          className={`h-full ${era.barColor} rounded-full transition-all duration-500`}
                        />
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* Betygsfördelning (1–10) */}
            <div className="p-4 sm:p-6 rounded-2xl bg-zinc-900/60 border border-zinc-800 shadow-md space-y-4">
              <div className="flex items-center justify-between">
                <h3 className="text-sm font-bold text-white flex items-center gap-2">
                  <Star className="w-4 h-4 text-yellow-400 fill-current" />
                  <span>Betygsfördelning (1–10)</span>
                </h3>
                <span className="text-xs text-zinc-500">{ratingDistribution.totalRatings} satta betyg</span>
              </div>

              {ratingDistribution.totalRatings === 0 ? (
                <div className="text-xs text-zinc-500 py-6 text-center">
                  Sätt betyg på dina spel i biblioteket för att se hur du betygsätter.
                </div>
              ) : (
                <div className="space-y-1.5">
                  {ratingDistribution.items
                    .filter((item) => item.rating >= 5 || item.count > 0)
                    .map((item) => {
                      const barWidth =
                        ratingDistribution.maxCount > 0
                          ? Math.round((item.count / ratingDistribution.maxCount) * 100)
                          : 0;

                      return (
                        <div key={item.rating} className="flex items-center gap-2.5 text-xs">
                          <div className="w-8 flex items-center gap-0.5 justify-end font-semibold text-zinc-300">
                            <span>{item.rating}</span>
                            <Star className="w-2.5 h-2.5 text-yellow-500 fill-current" />
                          </div>

                          <div className="flex-1 h-3 rounded bg-zinc-950 overflow-hidden flex items-center">
                            <div
                              style={{ width: `${barWidth}%` }}
                              className={`h-full rounded transition-all duration-500 ${
                                item.rating >= 8
                                  ? 'bg-gradient-to-r from-amber-500 to-yellow-400'
                                  : item.rating >= 6
                                  ? 'bg-teal-500'
                                  : 'bg-zinc-600'
                              }`}
                            />
                          </div>

                          <div className="w-7 text-right font-medium text-[11px] text-zinc-400">
                            {item.count > 0 ? item.count : '—'}
                          </div>
                        </div>
                      );
                    })}
                </div>
              )}
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
                        {game.genres?.[0] || 'Spel'}
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
                  <h4 className="text-sm font-bold text-zinc-300">Inga genomspelningar med klardatum för valt år</h4>
                  <p className="text-xs text-zinc-500 mt-1 max-w-sm mx-auto">
                    När du klarar spel i Gameshelf och sparar med ett klardatum eller avklarat år dyker de upp här i din tidslinje.
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
                                {game.completed_date ? (
                                  <span className="text-purple-400 font-semibold">
                                    {new Date(game.completed_date).toLocaleDateString('sv-SE', {
                                      day: 'numeric',
                                      month: 'short',
                                    })}
                                  </span>
                                ) : game.completed_year ? (
                                  <span className="text-purple-400 font-semibold">
                                    År {game.completed_year}
                                  </span>
                                ) : null}
                                {game.genres?.[0] && (
                                  <>
                                    <span>•</span>
                                    <span className="truncate">{game.genres[0]}</span>
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
                  Här samlas äldre spel du redan klarat tidigare i livet utan loggat klardatum eller år. De räknas som avklarade i din samling men förorenar inte årets månadsvisa tidslinje.
                </span>
              </div>

              {memoryGames.length === 0 ? (
                <div className="text-center py-16 bg-zinc-900/30 border border-dashed border-zinc-800 rounded-2xl p-6">
                  <Archive className="w-10 h-10 text-zinc-600 mx-auto mb-3" />
                  <h4 className="text-sm font-bold text-zinc-300">Inga odaterade spelminnen sparade</h4>
                  <p className="text-xs text-zinc-500 mt-1 max-w-sm mx-auto">
                    När du söker och snabbt lägger till gamla barndomsspel utan årtal sparas de här.
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
                          <span className="truncate max-w-[70px]">{game.genres?.[0] || 'Klarat'}</span>
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
