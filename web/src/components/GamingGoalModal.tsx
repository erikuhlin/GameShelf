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
} from 'lucide-react';
import { Game } from '@/types/game';

interface GamingGoalModalProps {
  isOpen: boolean;
  onClose: () => void;
  annualGoal: number;
  onUpdateAnnualGoal: (goal: number) => void;
  targetGameIds: string[];
  onToggleTargetGoal: (gameId: string) => void;
  libraryGames: Game[];
  completedGamesCount: number;
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
}: GamingGoalModalProps) {
  const [searchQuery, setSearchQuery] = useState('');
  const [goalInput, setGoalInput] = useState<number>(annualGoal);
  const [isSearchingLibrary, setIsSearchingLibrary] = useState(false);

  // Synka goalInput när modalen öppnas eller annualGoal ändras
  React.useEffect(() => {
    setGoalInput(annualGoal);
  }, [annualGoal, isOpen]);

  const targetGames = useMemo(() => {
    const ids = new Set(targetGameIds.map((id) => id.toLowerCase()));
    return libraryGames.filter((g) => ids.has(g.id.toLowerCase()));
  }, [libraryGames, targetGameIds]);

  // Tillgängliga biblioteksspel som inte redan är fokusmål
  const availableGames = useMemo(() => {
    const targetSet = new Set(targetGameIds.map((id) => id.toLowerCase()));
    const q = searchQuery.toLowerCase().trim();

    return libraryGames
      .filter((g) => g.is_owned !== false)
      .filter((g) => !targetSet.has(g.id.toLowerCase()))
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

  const progressPct = Math.min(100, Math.round((completedGamesCount / goalInput) * 100));

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md animate-in fade-in duration-150"
      onClick={onClose}
    >
      <div
        className="relative w-full max-w-xl bg-zinc-900 border border-zinc-800 rounded-3xl shadow-2xl overflow-hidden flex flex-col max-h-[90vh] animate-in zoom-in-95 duration-150"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="p-5 sm:px-6 border-b border-zinc-800 flex items-center justify-between bg-zinc-900/80">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-2xl bg-amber-500/15 border border-amber-500/30 flex items-center justify-center text-amber-400">
              <Trophy className="w-5 h-5" />
            </div>
            <div>
              <h2 className="text-lg font-bold text-white">Spelmål 2026</h2>
              <p className="text-xs text-zinc-400">
                Sätt ditt årsmål och välj ut upp till 3 fokusmål
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

        {/* Innehåll */}
        <div className="p-5 sm:px-6 overflow-y-auto space-y-6 flex-1">
          {/* 1. Årsmål */}
          <div className="p-4 rounded-2xl bg-zinc-950/70 border border-zinc-800/80 space-y-4">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold uppercase tracking-wider text-amber-400 flex items-center gap-1.5">
                <Trophy className="w-3.5 h-3.5" />
                Antal spel att klara i år
              </span>
              <span className="text-xs font-mono font-bold text-zinc-300">
                {completedGamesCount} av {goalInput} klara ({progressPct}%)
              </span>
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
                  className="w-full py-2 px-4 text-center bg-zinc-900 border border-zinc-700 focus:border-amber-400 rounded-xl text-xl font-bold font-mono text-white focus:outline-none"
                />
                <span className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-zinc-500 pointer-events-none font-medium">
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
            <div className="space-y-1.5">
              <span className="text-[11px] text-zinc-400">Snabbval:</span>
              <div className="flex items-center gap-1.5 flex-wrap">
                {PRESET_GOALS.map((preset) => (
                  <button
                    key={preset}
                    type="button"
                    onClick={() => handleGoalChange(preset)}
                    className={`px-3 py-1 rounded-lg text-xs font-bold transition cursor-pointer ${
                      goalInput === preset
                        ? 'bg-amber-500 text-zinc-950 shadow-md scale-105'
                        : 'bg-zinc-900 text-zinc-300 hover:bg-zinc-800 border border-zinc-800'
                    }`}
                  >
                    {preset}
                  </button>
                ))}
              </div>
            </div>

            {/* Progress bar */}
            <div className="space-y-1 pt-1">
              <div className="w-full h-2 rounded-full bg-zinc-900 border border-zinc-800 overflow-hidden">
                <div
                  className="h-full bg-gradient-to-r from-amber-500 to-emerald-400 rounded-full transition-all duration-300"
                  style={{ width: `${progressPct}%` }}
                />
              </div>
              <p className="text-[11px] text-zinc-400">
                {completedGamesCount >= goalInput
                  ? 'Fantastiskt! Målet för 2026 är redan uppnått! 🎉'
                  : `${Math.max(0, goalInput - completedGamesCount)} spel kvar till årets mål`}
              </p>
            </div>
          </div>

          {/* 2. Fokusmål (Max 3) */}
          <div className="space-y-3.5">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Target className="w-4 h-4 text-amber-400" />
                <h3 className="text-sm font-bold text-white">
                  Aktiva Fokusmål ({targetGames.length}/3)
                </h3>
              </div>
              <span className="text-xs text-zinc-500">
                Prioriterade spel du vill klara
              </span>
            </div>

            {/* Befintliga fokusmål */}
            {targetGames.length > 0 ? (
              <div className="space-y-2">
                {targetGames.map((game) => (
                  <div
                    key={game.id}
                    className="p-3 bg-zinc-950/60 border border-zinc-800 hover:border-zinc-700 rounded-2xl flex items-center justify-between gap-3 group transition"
                  >
                    <div className="flex items-center gap-3 min-w-0">
                      <div className="w-10 h-14 rounded-lg overflow-hidden bg-zinc-800 flex-shrink-0 relative">
                        {game.cover_url ? (
                          <img
                            src={game.cover_url}
                            alt={game.title}
                            className="w-full h-full object-cover"
                          />
                        ) : (
                          <div className="w-full h-full flex items-center justify-center text-zinc-600">
                            <Gamepad className="w-5 h-5" />
                          </div>
                        )}
                      </div>
                      <div className="min-w-0">
                        <div className="flex items-center gap-1.5">
                          <span className="text-[9px] font-bold px-1.5 py-0.5 rounded bg-amber-500/20 text-amber-400 border border-amber-500/30">
                            🎯 MÅL
                          </span>
                          {game.status === 'completed' && (
                            <span className="text-[9px] font-bold px-1.5 py-0.5 rounded bg-emerald-500/20 text-emerald-400 border border-emerald-500/30">
                              Klarat! 🏆
                            </span>
                          )}
                        </div>
                        <h4 className="text-sm font-bold text-white truncate">
                          {game.title}
                        </h4>
                        <p className="text-[11px] text-zinc-400 truncate">
                          {game.platforms?.join(', ') || 'Inget format angivet'}
                        </p>
                      </div>
                    </div>

                    <button
                      type="button"
                      onClick={() => onToggleTargetGoal(game.id)}
                      className="px-2.5 py-1 rounded-xl text-xs font-medium text-zinc-400 hover:text-red-400 hover:bg-red-950/30 border border-zinc-800 hover:border-red-900/50 transition cursor-pointer flex items-center gap-1 flex-shrink-0"
                    >
                      <X className="w-3.5 h-3.5" />
                      <span>Ta bort</span>
                    </button>
                  </div>
                ))}
              </div>
            ) : (
              <div className="p-4 rounded-2xl border border-dashed border-zinc-800 text-center text-zinc-500 text-xs space-y-1">
                <p className="font-semibold text-zinc-400">Inga aktiva fokusmål satta</p>
                <p>Välj upp till 3 spel från ditt bibliotek nedan för extra fokus.</p>
              </div>
            )}

            {/* Välj från biblioteket */}
            {targetGames.length < 3 ? (
              <div className="pt-1">
                {!isSearchingLibrary ? (
                  <button
                    type="button"
                    onClick={() => setIsSearchingLibrary(true)}
                    className="w-full py-2.5 px-4 rounded-2xl bg-zinc-950/80 hover:bg-zinc-800/80 border border-dashed border-zinc-700 hover:border-amber-500/50 text-xs font-bold text-amber-400 flex items-center justify-center gap-2 transition cursor-pointer"
                  >
                    <Plus className="w-4 h-4" />
                    <span>Välj spel från biblioteket (+{3 - targetGames.length} kvar)</span>
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

                    <div className="max-h-48 overflow-y-auto space-y-1.5 pr-1">
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
                                <h5 className="text-xs font-bold text-white truncate group-hover:text-amber-400 transition-colors">
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
            ) : (
              <p className="text-[11px] text-amber-400/80 bg-amber-950/20 border border-amber-900/30 p-2.5 rounded-xl text-center">
                🎯 Du har nått gränsen på 3 aktiva fokusmål. Ta bort ett mål för att välja ett nytt spel.
              </p>
            )}
          </div>
        </div>

        {/* Footer */}
        <div className="p-4 sm:px-6 border-t border-zinc-800 flex justify-end bg-zinc-900/80">
          <button
            type="button"
            onClick={onClose}
            className="px-5 py-2.5 rounded-xl bg-amber-500 hover:bg-amber-400 text-zinc-950 font-bold text-xs transition cursor-pointer shadow-md"
          >
            Klar
          </button>
        </div>
      </div>
    </div>
  );
}
