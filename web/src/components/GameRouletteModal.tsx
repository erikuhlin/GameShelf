'use client';

import React, { useState, useEffect } from 'react';
import { Game, PlayStatus } from '@/types/game';
import { StatusBadge } from './StatusBadge';
import {
  Sparkles,
  Dices,
  RotateCw,
  X,
  Play,
  Clock,
  Star,
  Gamepad,
  Plus,
  Compass,
  BookmarkPlus,
  Check,
} from 'lucide-react';

interface GameRouletteModalProps {
  isOpen: boolean;
  onClose: () => void;
  games: Game[];
  onSelectGame: (game: Game) => void;
  onUpdateGameStatus: (gameId: string, newStatus: PlayStatus) => void;
  onAddGameToLibrary?: (game: Game) => void;
}

export function GameRouletteModal({
  isOpen,
  onClose,
  games,
  onSelectGame,
  onUpdateGameStatus,
  onAddGameToLibrary,
}: GameRouletteModalProps) {
  const [rouletteMode, setRouletteMode] = useState<'my_games' | 'discover'>('my_games');
  const [selectedStatusFilter, setSelectedStatusFilter] = useState<'Backlog' | 'Spelar nu' | 'Alla'>('Backlog');
  const [isSpinning, setIsSpinning] = useState(false);
  const [displayedGame, setDisplayedGame] = useState<Game | null>(null);
  const [selectedWinner, setSelectedWinner] = useState<Game | null>(null);

  // Discovery games from IGDB
  const [discoveryGames, setDiscoveryGames] = useState<Game[]>([]);
  const [isLoadingDiscovery, setIsLoadingDiscovery] = useState(false);
  const [addedGameIds, setAddedGameIds] = useState<Set<string>>(new Set());

  // Hämta förslag från aktuell generation via IGDB
  const loadDiscoveryGames = async () => {
    setIsLoadingDiscovery(true);
    try {
      const existingIgdbIds = games
        .map((g) => g.igdb_id)
        .filter(Boolean)
        .join(',');

      const res = await fetch(`/api/games/discover?exclude_ids=${existingIgdbIds}`);
      if (res.ok) {
        const data = await res.json();
        if (data.results && data.results.length > 0) {
          setDiscoveryGames(data.results);
          return data.results;
        }
      }
    } catch (err) {
      console.error('Failed to load discovery games:', err);
    } finally {
      setIsLoadingDiscovery(false);
    }
    return [];
  };

  // Filtrera poolen av kandidater
  const candidateGames = React.useMemo(() => {
    if (rouletteMode === 'discover') {
      return discoveryGames;
    }
    return games.filter((g) => {
      if (selectedStatusFilter === 'Backlog' && g.status !== 'Backlog') return false;
      if (selectedStatusFilter === 'Spelar nu' && g.status !== 'Spelar nu') return false;
      return true;
    });
  }, [games, selectedStatusFilter, rouletteMode, discoveryGames]);

  const spinRoulette = (customPool?: Game[]) => {
    const pool = customPool || candidateGames;
    if (!pool || pool.length === 0) {
      setSelectedWinner(null);
      setDisplayedGame(null);
      return;
    }

    setIsSpinning(true);
    setSelectedWinner(null);

    let counter = 0;
    const totalSteps = 20 + Math.floor(Math.random() * 8);
    const speed = 70;

    const interval = setInterval(() => {
      const randomIndex = Math.floor(Math.random() * pool.length);
      setDisplayedGame(pool[randomIndex]);
      counter++;

      if (counter >= totalSteps) {
        clearInterval(interval);
        const finalWinner = pool[Math.floor(Math.random() * pool.length)];
        setDisplayedGame(finalWinner);
        setSelectedWinner(finalWinner);
        setIsSpinning(false);
      }
    }, speed);
  };

  // När modalläget öppnas
  useEffect(() => {
    if (isOpen) {
      setSelectedWinner(null);
      setDisplayedGame(null);
      if (rouletteMode === 'my_games' && candidateGames.length > 0) {
        spinRoulette();
      } else if (rouletteMode === 'discover') {
        loadDiscoveryGames().then((results) => {
          if (results && results.length > 0) {
            spinRoulette(results);
          }
        });
      }
    }
  }, [isOpen, rouletteMode]);

  if (!isOpen) return null;

  const handleStartPlaying = (game: Game) => {
    onUpdateGameStatus(game.id, 'Spelar nu');
    onClose();
    onSelectGame({ ...game, status: 'Spelar nu' });
  };

  const handleAddDiscoveryGame = (game: Game, targetStatus: PlayStatus) => {
    const newGame: Game = {
      ...game,
      id: crypto.randomUUID(),
      status: targetStatus,
      is_owned: targetStatus !== 'Önskelista',
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    if (onAddGameToLibrary) {
      onAddGameToLibrary(newGame);
    }
    setAddedGameIds((prev) => {
      const next = new Set(prev);
      next.add(game.id);
      return next;
    });
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/85 backdrop-blur-md animate-in fade-in duration-200">
      <div className="bg-[#14151b] border border-zinc-800 rounded-3xl w-full max-w-lg shadow-2xl overflow-hidden flex flex-col">
        {/* Header */}
        <div className="p-5 border-b border-zinc-800/80 flex items-center justify-between bg-gradient-to-r from-brand-red/10 via-rose-950/20 to-transparent">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-2xl bg-brand-red/20 border border-brand-red/40 flex items-center justify-center text-brand-red shadow-inner">
              <Dices className="w-5 h-5 animate-pulse" />
            </div>
            <div>
              <h3 className="font-bold text-white text-lg flex items-center gap-2">
                <span>Game Roulette</span>
                <Sparkles className="w-4 h-4 text-amber-400" />
              </h3>
              <p className="text-xs text-zinc-400">
                {rouletteMode === 'my_games'
                  ? 'Slumpa vad du ska spela ur ditt bibliotek'
                  : 'Upptäck nya hyllade spel från nuvarande generation'}
              </p>
            </div>
          </div>

          <button
            onClick={onClose}
            className="p-2 rounded-xl bg-zinc-900/80 hover:bg-zinc-800 text-zinc-400 hover:text-white border border-zinc-800 transition"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Mode Switcher Tabs */}
        <div className="grid grid-cols-2 p-1.5 m-4 mb-0 bg-zinc-950/80 border border-zinc-800 rounded-2xl">
          <button
            onClick={() => {
              if (isSpinning) return;
              setRouletteMode('my_games');
            }}
            className={`flex items-center justify-center gap-2 py-2 rounded-xl text-xs font-bold transition ${
              rouletteMode === 'my_games'
                ? 'bg-zinc-800 text-white shadow'
                : 'text-zinc-400 hover:text-zinc-200'
            }`}
          >
            <Gamepad className="w-3.5 h-3.5" />
            <span>Mina spel</span>
          </button>

          <button
            onClick={() => {
              if (isSpinning) return;
              setRouletteMode('discover');
            }}
            className={`flex items-center justify-center gap-2 py-2 rounded-xl text-xs font-bold transition ${
              rouletteMode === 'discover'
                ? 'bg-gradient-to-r from-amber-500 to-orange-500 text-white shadow-md'
                : 'text-zinc-400 hover:text-zinc-200'
            }`}
          >
            <Compass className="w-3.5 h-3.5" />
            <span>Upptäck nya spel (IGDB)</span>
          </button>
        </div>

        {/* Sub-Filters */}
        <div className="px-5 pt-3 pb-2 flex flex-wrap items-center justify-between gap-2 border-b border-zinc-800/60 text-xs">
          {rouletteMode === 'my_games' ? (
            <div className="flex items-center gap-1.5">
              <span className="text-zinc-500 font-medium mr-1">Pool:</span>
              {(['Backlog', 'Spelar nu', 'Alla'] as const).map((filter) => (
                <button
                  key={filter}
                  disabled={isSpinning}
                  onClick={() => setSelectedStatusFilter(filter)}
                  className={`px-2.5 py-1 rounded-lg font-medium transition ${
                    selectedStatusFilter === filter
                      ? 'bg-zinc-200 text-zinc-950 shadow'
                      : 'bg-zinc-900 text-zinc-400 hover:text-zinc-200 border border-zinc-800'
                  }`}
                >
                  {filter === 'Alla' ? 'Hela biblioteket' : filter}
                </button>
              ))}
            </div>
          ) : (
            <div className="flex items-center gap-2 text-amber-300 font-medium">
              <span className="w-2 h-2 rounded-full bg-amber-400 animate-pulse"></span>
              <span>Aktuella spelsläpp (2021–nu) med betyg 7.5+</span>
            </div>
          )}

          <div className="text-zinc-400 font-medium">
            {isLoadingDiscovery ? 'Hämtar förslag...' : `${candidateGames.length} spel i poolen`}
          </div>
        </div>

        {/* Main Roulette Card Display */}
        <div className="p-6 flex flex-col items-center justify-center min-h-[320px]">
          {isLoadingDiscovery ? (
            <div className="text-center py-12">
              <RotateCw className="w-8 h-8 text-amber-400 animate-spin mx-auto mb-3" />
              <p className="text-xs text-zinc-400 font-medium">Söker bland aktuella topptitlar på IGDB...</p>
            </div>
          ) : candidateGames.length === 0 ? (
            <div className="text-center py-10">
              <Gamepad className="w-12 h-12 text-zinc-600 mx-auto mb-3" />
              <h4 className="text-sm font-semibold text-zinc-300">Inga spel tillgängliga</h4>
              <p className="text-xs text-zinc-500 max-w-xs mt-1">
                {rouletteMode === 'my_games'
                  ? 'Lägg till fler spel i biblioteket eller växla filter ovan.'
                  : 'Kunde inte ladda nya förslag just nu.'}
              </p>
            </div>
          ) : (
            <div className="w-full flex flex-col items-center">
              {/* Spinning / Selected Card */}
              <div
                className={`relative w-44 aspect-[3/4] rounded-2xl overflow-hidden bg-zinc-900 border-2 shadow-2xl transition-all duration-300 ${
                  isSpinning
                    ? 'border-brand-red/60 scale-95 blur-[0.5px]'
                    : selectedWinner
                    ? rouletteMode === 'discover'
                      ? 'border-amber-400 scale-105 shadow-amber-500/20'
                      : 'border-brand-red scale-105 shadow-brand-red/20'
                    : 'border-zinc-800'
                }`}
              >
                {displayedGame?.cover_url ? (
                  <img
                    src={displayedGame.cover_url}
                    alt={displayedGame.title}
                    className="w-full h-full object-cover"
                  />
                ) : (
                  <div className="w-full h-full flex flex-col items-center justify-center p-4 text-center bg-zinc-800">
                    <Gamepad className="w-10 h-10 text-zinc-600 mb-2" />
                    <span className="text-xs font-semibold text-zinc-300">
                      {displayedGame?.title || 'Väljer spel...'}
                    </span>
                  </div>
                )}

                {/* Rating Badge */}
                {(displayedGame?.igdb_rating || displayedGame?.rating) && (
                  <div className="absolute top-2.5 right-2.5 flex items-center gap-1 px-2 py-0.5 rounded-lg bg-black/80 backdrop-blur-md text-amber-400 text-xs font-bold border border-amber-500/30">
                    <Star className="w-3 h-3 fill-current" />
                    <span>
                      {displayedGame.igdb_rating
                        ? (Math.round(Number(displayedGame.igdb_rating) * 10) / 10).toFixed(1)
                        : Math.round(Number(displayedGame.rating))}
                    </span>
                  </div>
                )}

                {/* Status / Discovery badge */}
                {rouletteMode === 'my_games' && displayedGame && (
                  <div className="absolute top-2.5 left-2.5">
                    <StatusBadge status={displayedGame.status} size="sm" />
                  </div>
                )}

                {rouletteMode === 'discover' && (
                  <div className="absolute top-2.5 left-2.5 px-2 py-0.5 rounded-lg bg-amber-500 text-zinc-950 text-[10px] font-bold shadow-md">
                    Nytt förslag
                  </div>
                )}
              </div>

              {/* Game Info Details */}
              <div className="mt-5 text-center max-w-sm px-2">
                <h4 className="text-lg font-bold text-white truncate">
                  {displayedGame?.title || 'Snurrar...'}
                </h4>
                <div className="flex items-center justify-center gap-2 mt-1 text-xs text-zinc-400">
                  {displayedGame?.release_year && (
                    <span className="px-2 py-0.5 rounded bg-zinc-800 text-zinc-300 font-semibold">
                      {displayedGame.release_year}
                    </span>
                  )}
                  {displayedGame?.platforms && displayedGame.platforms.length > 0 && (
                    <span className="truncate max-w-[180px]">
                      {displayedGame.platforms.join(', ')}
                    </span>
                  )}
                </div>

                {/* Summary snippet if discovery */}
                {rouletteMode === 'discover' && displayedGame?.summary && (
                  <p className="text-[11px] text-zinc-400 mt-2 line-clamp-2 italic">
                    "{displayedGame.summary}"
                  </p>
                )}
              </div>
            </div>
          )}
        </div>

        {/* Footer Actions */}
        <div className="p-5 border-t border-zinc-800 bg-zinc-950/60 flex flex-col sm:flex-row items-center justify-between gap-3">
          <button
            onClick={() => spinRoulette()}
            disabled={isSpinning || candidateGames.length === 0}
            className="w-full sm:w-auto flex items-center justify-center gap-2 px-5 py-2.5 rounded-xl bg-zinc-800 hover:bg-zinc-700 disabled:opacity-50 text-zinc-200 text-xs font-semibold border border-zinc-700 transition"
          >
            <RotateCw className={`w-4 h-4 ${isSpinning ? 'animate-spin' : ''}`} />
            <span>{isSpinning ? 'Slumpar...' : 'Snurra igen'}</span>
          </button>

          {selectedWinner && (
            <div className="flex items-center gap-2 w-full sm:w-auto">
              {rouletteMode === 'my_games' ? (
                <>
                  <button
                    onClick={() => {
                      onSelectGame(selectedWinner);
                      onClose();
                    }}
                    className="flex-1 sm:flex-none px-4 py-2.5 rounded-xl bg-zinc-800 hover:bg-zinc-700 text-zinc-200 text-xs font-semibold border border-zinc-700 transition"
                  >
                    Visa detaljer
                  </button>

                  <button
                    onClick={() => handleStartPlaying(selectedWinner)}
                    className="flex-1 sm:flex-none flex items-center justify-center gap-2 px-5 py-2.5 rounded-xl bg-brand-red hover:bg-brand-redPressed text-white text-xs font-bold shadow-lg shadow-brand-red/25 transition transform active:scale-95"
                  >
                    <Play className="w-3.5 h-3.5 fill-current" />
                    <span>Börja spela!</span>
                  </button>
                </>
              ) : (
                /* Discovery Actions */
                <div className="flex items-center gap-2">
                  {addedGameIds.has(selectedWinner.id) ? (
                    <div className="flex items-center gap-1.5 px-4 py-2.5 rounded-xl bg-emerald-950 border border-emerald-500/40 text-emerald-300 text-xs font-bold">
                      <Check className="w-4 h-4 text-emerald-400" />
                      <span>Tillagd i biblioteket!</span>
                    </div>
                  ) : (
                    <>
                      <button
                        onClick={() => handleAddDiscoveryGame(selectedWinner, 'Önskelista')}
                        className="flex items-center gap-1.5 px-3.5 py-2.5 rounded-xl bg-zinc-800 hover:bg-zinc-700 text-zinc-200 text-xs font-semibold border border-zinc-700 transition"
                      >
                        <BookmarkPlus className="w-3.5 h-3.5" />
                        <span>+ Önskelista</span>
                      </button>

                      <button
                        onClick={() => handleAddDiscoveryGame(selectedWinner, 'Backlog')}
                        className="flex items-center gap-1.5 px-4 py-2.5 rounded-xl bg-amber-500 hover:bg-amber-400 text-zinc-950 text-xs font-bold shadow-lg shadow-amber-500/20 transition transform active:scale-95"
                      >
                        <Plus className="w-3.5 h-3.5" />
                        <span>+ Lägg i Backlog</span>
                      </button>
                    </>
                  )}
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
