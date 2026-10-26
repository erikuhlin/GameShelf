'use client';

import React, { useState, useMemo } from 'react';
import {
  X,
  Trophy,
  Target,
  Plus,
  Search,
  Gamepad,
  Check,
  Minus,
  Sparkles,
  TrendingUp,
  Clock,
  ChevronRight,
  Flame,
  AlertCircle,
  Flag,
} from 'lucide-react';
import { Game } from '@/types/game';
import { GamingGoalEngine, GameGoalBadge } from '@/lib/gamingGoalEngine';

interface GamingGoalModalProps {
  isOpen: boolean;
  onClose: () => void;
  annualGoal: number;
  onUpdateAnnualGoal: (goal: number) => void;
  targetGameIds: string[];
  onToggleTargetGoal: (gameId: string) => void;
  libraryGames: Game[];
  completedGamesCount: number;
  onSelectGame?: (game: Game) => void;
}

const PRESET_GOALS = [3, 5, 10, 12, 15, 20, 25, 50];

export function GamingGoalModal({
  isOpen,
  onClose,
  annualGoal,
  onUpdateAnnualGoal,
  targetGameIds,
  onToggleTargetGoal,
  libraryGames,
  completedGamesCount,
  onSelectGame,
}: GamingGoalModalProps) {
  const currentYear = GamingGoalEngine.currentYear();
  const [searchQuery, setSearchQuery] = useState('');
  const [goalInput, setGoalInput] = useState<number>(annualGoal);
  const [isSearchingLibrary, setIsSearchingLibrary] = useState(false);
  const [dismissedSuggestionId, setDismissedSuggestionId] = useState<string | null>(null);

  React.useEffect(() => {
    setGoalInput(annualGoal);
  }, [annualGoal, isOpen]);

  // Beräkningar via GamingGoalEngine
  const completedThisYearGames = useMemo(() => {
    return GamingGoalEngine.completedGames(libraryGames, currentYear);
  }, [libraryGames, currentYear]);

  const completedCount = completedThisYearGames.length;

  const abandonedCount = useMemo(() => {
    return GamingGoalEngine.abandonedCount(libraryGames, currentYear);
  }, [libraryGames, currentYear]);

  const targetGames = useMemo(() => {
    return GamingGoalEngine.focusGames(libraryGames, targetGameIds);
  }, [libraryGames, targetGameIds]);

  const tempoInfo = useMemo(() => {
    return GamingGoalEngine.calculateTempo(goalInput, completedCount, currentYear);
  }, [goalInput, completedCount, currentYear]);

  const closestGame = useMemo(() => {
    return GamingGoalEngine.closestToFinish(targetGames);
  }, [targetGames]);

  const badges = useMemo(() => {
    return GamingGoalEngine.badges(goalInput, completedCount, currentYear);
  }, [goalInput, completedCount, currentYear]);

  const suggestedGame = useMemo(() => {
    return GamingGoalEngine.suggestedNextGame(
      libraryGames,
      targetGameIds,
      dismissedSuggestionId || undefined
    );
  }, [libraryGames, targetGameIds, dismissedSuggestionId]);

  // Tillgängliga biblioteksspel för sökning
  const availableGames = useMemo(() => {
    const targetSet = new Set(targetGameIds.map((id) => id.toLowerCase()));
    const q = searchQuery.toLowerCase().trim();

    return libraryGames
      .filter((g) => g.is_owned !== false)
      .filter(
        (g) =>
          !targetSet.has(g.id.toLowerCase()) &&
          (!g.igdb_id || !targetSet.has(String(g.igdb_id).toLowerCase()))
      )
      .filter((g) => {
        if (!q) return true;
        return (
          g.title.toLowerCase().includes(q) ||
          g.platforms?.some((p) => p.toLowerCase().includes(q))
        );
      });
  }, [libraryGames, targetGameIds, searchQuery]);

  if (!isOpen) return null;

  const handleGoalChange = (newVal: number) => {
    const clamped = Math.max(1, Math.min(999, newVal));
    setGoalInput(clamped);
    onUpdateAnnualGoal(clamped);
  };

  const progressPct = Math.min(100, Math.round((completedCount / goalInput) * 100));

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-black/85 backdrop-blur-md animate-in fade-in duration-150"
      onClick={onClose}
    >
      <div
        className="relative w-full max-w-2xl bg-zinc-900 border border-zinc-800 rounded-3xl shadow-2xl overflow-hidden flex flex-col max-h-[92vh] animate-in zoom-in-95 duration-150"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="p-4 sm:p-5 sm:px-6 border-b border-zinc-800 flex items-center justify-between bg-zinc-900/90 backdrop-blur-sm">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-2xl bg-amber-500/15 border border-amber-500/30 flex items-center justify-center text-amber-400">
              <Trophy className="w-5 h-5" />
            </div>
            <div>
              <h2 className="text-lg font-bold text-white flex items-center gap-2">
                Spelmål {currentYear}
              </h2>
              <p className="text-xs text-zinc-400">
                Årsmål, aktiva fokusspel och tempo
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-2 rounded-xl bg-zinc-800/80 hover:bg-zinc-700 text-zinc-400 hover:text-white transition cursor-pointer"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Scrollbart innehåll */}
        <div className="p-4 sm:p-6 overflow-y-auto space-y-6 flex-1 scrollbar-thin">
          {/* 1. ÅRSMÅLSKORT */}
          <div className="p-5 rounded-2xl bg-gradient-to-b from-zinc-900 to-zinc-950 border border-zinc-800 space-y-4 shadow-lg">
            <div className="flex items-center justify-between flex-wrap gap-2">
              <span className="text-xs font-bold uppercase tracking-wider text-amber-400 flex items-center gap-1.5">
                <Trophy className="w-3.5 h-3.5" />
                Årsmål {currentYear}
              </span>
              <div className="flex items-center gap-2">
                <span className="text-xs font-mono font-bold text-white bg-zinc-800/80 px-2.5 py-1 rounded-lg border border-zinc-700/60">
                  {completedCount} av {goalInput} klara ({progressPct}%)
                </span>
                {abandonedCount > 0 && (
                  <span className="text-[11px] font-medium text-zinc-400 bg-purple-950/40 text-purple-300 px-2 py-1 rounded-lg border border-purple-800/40 flex items-center gap-1" title="Avbrutna spel i år">
                    <Flag className="w-3 h-3 text-purple-400" />
                    {abandonedCount} avbrutna
                  </span>
                )}
              </div>
            </div>

            {/* Stepper + Input */}
            <div className="flex items-center gap-3">
              <button
                type="button"
                onClick={() => handleGoalChange(goalInput - 1)}
                className="w-11 h-11 rounded-xl bg-zinc-900 hover:bg-zinc-800 border border-zinc-700 flex items-center justify-center text-zinc-200 hover:text-white transition active:scale-95 cursor-pointer font-bold"
                title="Minska mål"
              >
                <Minus className="w-4 h-4" />
              </button>

              <div className="flex-1 relative">
                <input
                  type="number"
                  min="1"
                  max="999"
                  value={goalInput}
                  onChange={(e) => {
                    const v = parseInt(e.target.value, 10);
                    if (!isNaN(v)) handleGoalChange(v);
                  }}
                  onBlur={() => handleGoalChange(goalInput)}
                  className="w-full py-2 px-4 text-center bg-zinc-950 border border-zinc-700 focus:border-amber-400 rounded-xl text-2xl font-black font-mono text-white focus:outline-none"
                />
                <span className="absolute right-4 top-1/2 -translate-y-1/2 text-xs text-zinc-500 pointer-events-none font-medium">
                  spel
                </span>
              </div>

              <button
                type="button"
                onClick={() => handleGoalChange(goalInput + 1)}
                className="w-11 h-11 rounded-xl bg-zinc-900 hover:bg-zinc-800 border border-zinc-700 flex items-center justify-center text-zinc-200 hover:text-white transition active:scale-95 cursor-pointer font-bold"
                title="Öka mål"
              >
                <Plus className="w-4 h-4" />
              </button>
            </div>

            {/* Snabbvalsknappar */}
            <div className="flex items-center gap-1.5 flex-wrap">
              <span className="text-[11px] text-zinc-500 mr-1">Snabbval:</span>
              {PRESET_GOALS.map((preset) => (
                <button
                  key={preset}
                  type="button"
                  onClick={() => handleGoalChange(preset)}
                  className={`px-3 py-1 rounded-lg text-xs font-bold transition cursor-pointer ${
                    goalInput === preset
                      ? 'bg-amber-500 text-zinc-950 shadow-md scale-105'
                      : 'bg-zinc-900 text-zinc-400 hover:bg-zinc-800 hover:text-white border border-zinc-800'
                  }`}
                >
                  {preset}
                </button>
              ))}
            </div>

            {/* Progress bar */}
            <div className="space-y-1.5 pt-1">
              <div className="w-full h-2.5 rounded-full bg-zinc-950 border border-zinc-800 overflow-hidden">
                <div
                  className="h-full bg-gradient-to-r from-amber-500 via-emerald-400 to-teal-400 rounded-full transition-all duration-300"
                  style={{ width: `${progressPct}%` }}
                />
              </div>

              {/* Tempotext */}
              <div className="flex items-center gap-1.5 text-xs text-zinc-400 pt-0.5">
                {tempoInfo.isGoalReached ? (
                  <span className="text-emerald-400 font-semibold flex items-center gap-1">
                    <Sparkles className="w-3.5 h-3.5" />
                    {tempoInfo.displayText}
                  </span>
                ) : (
                  <span className="flex items-center gap-1">
                    <TrendingUp className="w-3.5 h-3.5 text-amber-400 shrink-0" />
                    {tempoInfo.displayText}
                  </span>
                )}
              </div>
            </div>

            {/* Avklarade spel i år - Miniatyrlista */}
            {completedThisYearGames.length > 0 && (
              <div className="pt-3 border-t border-zinc-800/70 space-y-2">
                <span className="text-[11px] font-bold uppercase tracking-wider text-zinc-400">
                  Avklarade spel i år ({completedThisYearGames.length})
                </span>
                <div className="flex items-center gap-2 overflow-x-auto pb-1 scrollbar-none">
                  {completedThisYearGames.map((game) => (
                    <div
                      key={`comp-${game.id}`}
                      onClick={() => onSelectGame?.(game)}
                      className="w-16 flex-shrink-0 cursor-pointer group text-center"
                      title={game.title}
                    >
                      <div className="w-16 h-20 rounded-xl overflow-hidden bg-zinc-800 border border-zinc-700/60 relative group-hover:scale-105 transition shadow-sm">
                        {game.cover_url ? (
                          <img
                            src={game.cover_url}
                            alt={game.title}
                            className="w-full h-full object-cover"
                          />
                        ) : (
                          <div className="w-full h-full flex items-center justify-center text-zinc-600">
                            🎮
                          </div>
                        )}
                        {game.rating && (
                          <span className="absolute bottom-1 right-1 text-[9px] font-black bg-black/80 text-amber-400 px-1 rounded">
                            ★{game.rating}
                          </span>
                        )}
                      </div>
                      <p className="text-[10px] text-zinc-400 truncate mt-1 group-hover:text-white">
                        {game.title}
                      </p>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>

          {/* 2. NÄRMAST I MÅL (HIGHLIGHT-KORT) */}
          {closestGame && (
            <div
              onClick={() => onSelectGame?.(closestGame.game)}
              className="p-4 rounded-2xl bg-gradient-to-r from-emerald-950/40 via-zinc-900 to-zinc-900 border border-emerald-800/40 hover:border-emerald-600/60 transition cursor-pointer group shadow-md"
            >
              <div className="flex items-center justify-between gap-3">
                <div className="flex items-center gap-3 min-w-0">
                  <div className="w-12 h-16 rounded-xl overflow-hidden bg-zinc-800 flex-shrink-0 border border-emerald-500/30">
                    {closestGame.game.cover_url ? (
                      <img
                        src={closestGame.game.cover_url}
                        alt={closestGame.game.title}
                        className="w-full h-full object-cover group-hover:scale-105 transition"
                      />
                    ) : (
                      <div className="w-full h-full flex items-center justify-center text-zinc-600">
                        🎮
                      </div>
                    )}
                  </div>
                  <div className="min-w-0">
                    <span className="text-[10px] font-bold text-emerald-400 uppercase tracking-wider flex items-center gap-1 mb-0.5">
                      <Flame className="w-3 h-3 text-emerald-400 fill-emerald-400" />
                      Närmast i mål
                    </span>
                    <h4 className="text-sm font-bold text-white truncate group-hover:text-emerald-300 transition">
                      {closestGame.game.title}
                    </h4>
                    <p className="text-xs text-zinc-400 truncate mt-0.5">
                      {closestGame.info.displaySubtext}
                    </p>
                  </div>
                </div>

                <div className="text-right flex-shrink-0">
                  <span className="text-xl font-black text-emerald-400">
                    {closestGame.info.percentage}%
                  </span>
                  <div className="text-[10px] text-zinc-500 uppercase font-bold">Klart</div>
                </div>
              </div>
            </div>
          )}

          {/* 3. FOKUSMÅL (MAX 3) */}
          <div className="space-y-3.5">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Target className="w-4 h-4 text-amber-400" />
                <h3 className="text-sm font-bold text-white">
                  Aktiva Fokusmål ({targetGames.length}/3)
                </h3>
              </div>
              <span className="text-xs text-zinc-500">
                Spelen du vill klara härnäst
              </span>
            </div>

            {/* Lista med aktiva fokusmål */}
            {targetGames.length > 0 ? (
              <div className="space-y-2.5">
                {targetGames.map((game) => {
                  const progress = GamingGoalEngine.calculateProgress(game);
                  return (
                    <div
                      key={game.id}
                      className="p-3.5 bg-zinc-950/70 border border-zinc-800 hover:border-zinc-700 rounded-2xl flex items-center justify-between gap-3 group transition"
                    >
                      <div
                        onClick={() => onSelectGame?.(game)}
                        className="flex items-center gap-3 min-w-0 flex-1 cursor-pointer"
                      >
                        <div className="w-12 h-16 rounded-xl overflow-hidden bg-zinc-800 flex-shrink-0 relative border border-zinc-800">
                          {game.cover_url ? (
                            <img
                              src={game.cover_url}
                              alt={game.title}
                              className="w-full h-full object-cover group-hover:scale-105 transition"
                            />
                          ) : (
                            <div className="w-full h-full flex items-center justify-center text-zinc-600">
                              <Gamepad className="w-5 h-5" />
                            </div>
                          )}
                        </div>
                        <div className="min-w-0 flex-1">
                          <div className="flex items-center gap-1.5 mb-0.5">
                            <span className="text-[9px] font-bold px-1.5 py-0.5 rounded bg-amber-500/20 text-amber-400 border border-amber-500/30">
                              🎯 FOKUS
                            </span>
                            {game.status === 'playing' ? (
                              <span className="text-[9px] font-bold px-1.5 py-0.5 rounded bg-emerald-500/20 text-emerald-400">
                                Spelar nu
                              </span>
                            ) : game.status === 'paused' ? (
                              <span className="text-[9px] font-bold px-1.5 py-0.5 rounded bg-orange-500/20 text-orange-400">
                                Pausat
                              </span>
                            ) : null}
                          </div>
                          <h4 className="text-sm font-bold text-white truncate leading-snug group-hover:text-amber-400 transition">
                            {game.title}
                          </h4>
                          <p className="text-[11px] text-zinc-400 truncate mt-0.5">
                            {progress.displaySubtext}
                          </p>

                          {/* Progress bar för fokusmål */}
                          {progress.percentage > 0 && (
                            <div className="w-full max-w-[180px] h-1.5 bg-zinc-800 rounded-full overflow-hidden mt-1.5">
                              <div
                                className="h-full bg-amber-400 rounded-full"
                                style={{ width: `${progress.percentage}%` }}
                              />
                            </div>
                          )}
                        </div>
                      </div>

                      <button
                        type="button"
                        onClick={() => onToggleTargetGoal(game.id)}
                        className="px-2.5 py-1.5 rounded-xl text-xs font-medium text-zinc-400 hover:text-red-400 hover:bg-red-950/30 border border-zinc-800 hover:border-red-900/50 transition cursor-pointer flex items-center gap-1 flex-shrink-0"
                        title="Ta bort från fokusmål"
                      >
                        <X className="w-3.5 h-3.5" />
                        <span>Ta bort</span>
                      </button>
                    </div>
                  );
                })}
              </div>
            ) : (
              <div className="p-4 rounded-2xl border border-dashed border-zinc-800 text-center text-zinc-500 text-xs space-y-1">
                <p className="font-semibold text-zinc-400">Inga aktiva fokusmål satta</p>
                <p>Välj upp till 3 spel från ditt bibliotek nedan för extra fokus.</p>
              </div>
            )}

            {/* Smart förslag på nästa fokusspel om plats finns */}
            {targetGames.length < 3 && suggestedGame && !isSearchingLibrary && (
              <div className="p-3.5 rounded-2xl bg-zinc-950/60 border border-dashed border-amber-500/30 flex items-center justify-between gap-3">
                <div className="flex items-center gap-3 min-w-0">
                  <div className="w-10 h-14 rounded-lg overflow-hidden bg-zinc-800 flex-shrink-0">
                    {suggestedGame.cover_url ? (
                      <img
                        src={suggestedGame.cover_url}
                        alt={suggestedGame.title}
                        className="w-full h-full object-cover"
                      />
                    ) : (
                      <div className="w-full h-full flex items-center justify-center text-zinc-600">
                        🎮
                      </div>
                    )}
                  </div>
                  <div className="min-w-0">
                    <span className="text-[9px] font-bold text-amber-400 uppercase tracking-wider flex items-center gap-1">
                      <Sparkles className="w-3 h-3 text-amber-400" />
                      Föreslaget fokusspel
                    </span>
                    <h5 className="text-xs font-bold text-white truncate">
                      {suggestedGame.title}
                    </h5>
                    <p className="text-[10px] text-zinc-400 truncate">
                      {suggestedGame.status === 'playing'
                        ? 'Från dina aktiva spel'
                        : suggestedGame.status === 'paused'
                        ? 'Pausat äventyr'
                        : 'Från din backlog'}
                    </p>
                  </div>
                </div>

                <div className="flex items-center gap-1.5 flex-shrink-0">
                  <button
                    type="button"
                    onClick={() => onToggleTargetGoal(suggestedGame.id)}
                    className="px-3 py-1.5 rounded-xl bg-amber-500 hover:bg-amber-400 text-zinc-950 font-bold text-xs transition cursor-pointer flex items-center gap-1"
                  >
                    <Plus className="w-3.5 h-3.5" />
                    <span>Välj</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => setDismissedSuggestionId(suggestedGame.id)}
                    className="p-1.5 rounded-xl text-zinc-500 hover:text-zinc-300 hover:bg-zinc-800 transition cursor-pointer"
                    title="Avvisa förslag"
                  >
                    <X className="w-3.5 h-3.5" />
                  </button>
                </div>
              </div>
            )}

            {/* Välj manuellt från biblioteket */}
            {targetGames.length < 3 && (
              <div className="pt-1">
                {!isSearchingLibrary ? (
                  <button
                    type="button"
                    onClick={() => setIsSearchingLibrary(true)}
                    className="w-full py-2.5 px-4 rounded-2xl bg-zinc-950/80 hover:bg-zinc-800/80 border border-dashed border-zinc-700 hover:border-amber-500/50 text-xs font-bold text-amber-400 flex items-center justify-center gap-2 transition cursor-pointer"
                  >
                    <Plus className="w-4 h-4" />
                    <span>Sök i biblioteket ({3 - targetGames.length} platser kvar)</span>
                  </button>
                ) : (
                  <div className="p-3.5 bg-zinc-950 rounded-2xl border border-zinc-800 space-y-3">
                    <div className="flex items-center justify-between">
                      <span className="text-xs font-bold text-zinc-300">
                        Lägg till från biblioteket:
                      </span>
                      <button
                        type="button"
                        onClick={() => {
                          setIsSearchingLibrary(false);
                          setSearchQuery('');
                        }}
                        className="text-xs text-zinc-500 hover:text-zinc-300 cursor-pointer"
                      >
                        Avbryt
                      </button>
                    </div>

                    <div className="relative">
                      <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-zinc-500" />
                      <input
                        type="text"
                        autoFocus
                        value={searchQuery}
                        onChange={(e) => setSearchQuery(e.target.value)}
                        placeholder="Sök bland dina spel..."
                        className="w-full pl-9 pr-3 py-2 bg-zinc-900 border border-zinc-700 rounded-xl text-xs text-white placeholder-zinc-500 focus:outline-none focus:border-amber-400"
                      />
                    </div>

                    <div className="max-h-48 overflow-y-auto space-y-1.5 pr-1 scrollbar-thin">
                      {availableGames.length > 0 ? (
                        availableGames.map((game) => (
                          <div
                            key={game.id}
                            onClick={() => {
                              onToggleTargetGoal(game.id);
                              if (targetGames.length + 1 >= 3) {
                                setIsSearchingLibrary(false);
                              }
                            }}
                            className="p-2 rounded-xl bg-zinc-900/60 hover:bg-zinc-800/90 border border-zinc-800/80 flex items-center justify-between gap-2.5 cursor-pointer group transition"
                          >
                            <div className="flex items-center gap-2.5 min-w-0">
                              <div className="w-7 h-10 rounded overflow-hidden bg-zinc-800 flex-shrink-0">
                                {game.cover_url ? (
                                  <img
                                    src={game.cover_url}
                                    alt={game.title}
                                    className="w-full h-full object-cover"
                                  />
                                ) : (
                                  <div className="w-full h-full flex items-center justify-center text-zinc-600">
                                    <Gamepad className="w-3.5 h-3.5" />
                                  </div>
                                )}
                              </div>
                              <div className="min-w-0">
                                <h5 className="text-xs font-bold text-white line-clamp-2 leading-snug group-hover:text-amber-400 transition-colors">
                                  {game.title}
                                </h5>
                                <p className="text-[10px] text-zinc-400 truncate">
                                  {game.platforms?.join(', ') || 'Inget format'}
                                </p>
                              </div>
                            </div>

                            <button
                              type="button"
                              className="px-2 py-1 rounded-lg bg-amber-500/10 text-amber-400 group-hover:bg-amber-500 group-hover:text-zinc-950 text-[11px] font-bold transition flex items-center gap-1 flex-shrink-0"
                            >
                              <Plus className="w-3 h-3" />
                              <span>Välj</span>
                            </button>
                          </div>
                        ))
                      ) : (
                        <p className="text-center py-4 text-xs text-zinc-500">
                          {searchQuery ? 'Inga matchande spel i biblioteket' : 'Inga fler spel i biblioteket'}
                        </p>
                      )}
                    </div>
                  </div>
                )}
              </div>
            )}
          </div>

          {/* 4. MÄRKEN & MILSTOLPAR */}
          <div className="space-y-3 pt-2">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold uppercase tracking-wider text-zinc-400 flex items-center gap-1.5">
                <Trophy className="w-3.5 h-3.5 text-amber-400" />
                Märken & Milstolpar {currentYear}
              </span>
            </div>

            <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5">
              {badges.map((b) => (
                <div
                  key={b.id}
                  className={`p-3 rounded-2xl border text-center transition ${
                    b.isUnlocked
                      ? 'bg-amber-500/10 border-amber-500/30 text-amber-300 shadow-sm'
                      : 'bg-zinc-950/50 border-zinc-800/70 text-zinc-600 opacity-60'
                  }`}
                >
                  <div className="text-2xl mb-1">{b.icon}</div>
                  <div className="text-xs font-bold text-white truncate">{b.title}</div>
                  <div className="text-[10px] text-zinc-400 truncate mt-0.5">{b.subtitle}</div>
                  {b.isUnlocked ? (
                    <span className="inline-block mt-1 text-[9px] font-black uppercase text-amber-400 bg-amber-400/20 px-1.5 py-0.5 rounded">
                      Upplåst
                    </span>
                  ) : (
                    <div className="w-full bg-zinc-800 h-1 rounded-full overflow-hidden mt-1.5">
                      <div
                        className="bg-zinc-600 h-full rounded-full"
                        style={{ width: `${Math.round(b.progressRatio * 100)}%` }}
                      />
                    </div>
                  )}
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="p-4 px-6 border-t border-zinc-800 bg-zinc-900/90 flex items-center justify-end">
          <button
            type="button"
            onClick={onClose}
            className="px-6 py-2 rounded-xl bg-amber-500 hover:bg-amber-400 text-zinc-950 font-bold text-sm transition cursor-pointer shadow-md"
          >
            Klar
          </button>
        </div>
      </div>
    </div>
  );
}
