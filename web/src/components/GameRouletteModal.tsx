'use client';

import React, { useState, useEffect } from 'react';
import { Game, PlayStatus } from '@/types/game';
import { StatusBadge } from './StatusBadge';
import { inferPlayTypes } from '@/lib/statusHelper';
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
  Flame,
  ArrowRight,
  Lightbulb,
} from 'lucide-react';

export type RouletteMood = 'quick' | 'backlog' | 'playing' | 'top' | 'discover' | 'all';

interface GameRouletteModalProps {
  isOpen: boolean;
  onClose: () => void;
  games: Game[];
  onSelectGame: (game: Game) => void;
  onUpdateGameStatus: (gameId: string, newStatus: PlayStatus) => void;
  onAddGameToLibrary?: (game: Game) => void;
}

export function getSmartRouletteReason(game: Game, mood?: RouletteMood): string {
  if (game.status === 'playing' || (game.status as string) === 'Spelar nu') {
    return 'Fortsätt ditt äventyr – du är redan igång och har kommit en bra bit!';
  }
  if (game.estimated_hours && game.estimated_hours > 0 && game.estimated_hours <= 10) {
    return `Perfekt för ikväll – beräknad speltid är bara ca ${game.estimated_hours} timmar!`;
  }
  if (game.is_backlog) {
    const rating = game.igdb_rating || game.rating;
    if (rating && Number(rating) >= 85) {
      return `Ett riktigt mästerverk (${Math.round(Number(rating))}% betyg) som väntar tålmodigt i din backlog.`;
    }
    return 'Dags att ta tag i backloggen – detta spel förtjänar din tid!';
  }
  if (game.status === 'completed') {
    return 'Dags att återbesöka en avklarad favorit för en härlig nostalgitripp!';
  }
  if (game.genres && game.genres.length > 0) {
    return `Ett fantastiskt ${game.genres[0]}-spel rekommenderat för dig just nu.`;
  }
  return 'Ett handplockat spel från din spelsamling!';
}

const MOOD_OPTIONS: { id: RouletteMood; label: string; icon: any; desc: string }[] = [
  { id: 'quick', label: '⚡ Kort & Gott (<10h)', icon: Clock, desc: 'Snabba sessioner och kortare spel' },
  { id: 'backlog', label: '📦 Backloggen', icon: BookmarkPlus, desc: 'Ospelade spel i din samling' },
  { id: 'playing', label: '🎯 Fortsätt spela', icon: Play, desc: 'Spel du redan påbörjat eller pausat' },
  { id: 'top', label: '🏆 Högst rankade', icon: Star, desc: 'Mästerverk med högst betyg' },
  { id: 'discover', label: '🌟 Upptäck nytt (IGDB)', icon: Compass, desc: 'Populära speltitlar från spelvärlden' },
  { id: 'all', label: '🎲 Ren slump', icon: Dices, desc: 'Hela samlingen utan restriktioner' },
];

export function GameRouletteModal({
  isOpen,
  onClose,
  games,
  onSelectGame,
  onUpdateGameStatus,
  onAddGameToLibrary,
}: GameRouletteModalProps) {
  const hasOwnedGames = games.some((g) => g.is_owned);
  const [selectedMood, setSelectedMood] = useState<RouletteMood>(hasOwnedGames ? 'backlog' : 'discover');
  const [isSpinning, setIsSpinning] = useState(false);
  const [displayedGame, setDisplayedGame] = useState<Game | null>(null);
  const [selectedWinner, setSelectedWinner] = useState<Game | null>(null);
  const [smartReason, setSmartReason] = useState<string>('');

  // Discovery games from IGDB
  const [discoveryGames, setDiscoveryGames] = useState<Game[]>([]);
  const [isLoadingDiscovery, setIsLoadingDiscovery] = useState(false);
  const [addedGameIds, setAddedGameIds] = useState<Set<string>>(new Set());

  // Hämta förslag från IGDB discover
  const loadDiscoveryGames = async () => {
    setIsLoadingDiscovery(true);
    try {
      const res = await fetch('/api/games/discover?category=popular&limit=30');
      const data = await res.json();
      if (res.ok && Array.isArray(data.results)) {
        const mapped: Game[] = data.results.map((item: any) => ({
          id: String(item.id),
          title: item.title,
          cover_url: item.cover_url || null,
          platforms: item.platforms || [],
          release_year: item.release_year || null,
          genres: item.genres || [],
          developers: item.developers || [],
          status: 'notStarted' as PlayStatus,
          rating: null,
          igdb_rating: item.igdb_rating || item.rating || null,
          igdb_id: item.id || item.igdb_id,
          estimated_hours: null,
          is_owned: false,
          notes: '',
          todos: [],
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        }));
        setDiscoveryGames(mapped);
        return mapped;
      }
    } catch (e) {
      console.error('Failed to load discovery games for roulette:', e);
    } finally {
      setIsLoadingDiscovery(false);
    }
    return [];
  };

  // Filtrera poolen av kandidater baserat på humör
  const candidateGames = React.useMemo(() => {
    if (selectedMood === 'discover') {
      return discoveryGames;
    }
    const owned = games.filter((g) => g.is_owned);
    if (owned.length === 0) {
      return discoveryGames;
    }

    if (selectedMood === 'quick') {
      const quick = owned.filter(
        (g) =>
          (g.estimated_hours && g.estimated_hours <= 10) ||
          g.genres?.includes('Puzzle') ||
          g.genres?.includes('Platform') ||
          g.genres?.includes('Indie')
      );
      return quick.length > 0 ? quick : owned;
    }
    if (selectedMood === 'playing') {
      const playing = owned.filter(
        (g) =>
          g.status === 'playing' ||
          g.status === 'paused' ||
          (g.status as string) === 'Spelar nu'
      );
      return playing.length > 0 ? playing : owned;
    }
    if (selectedMood === 'backlog') {
      const backlog = owned.filter((g) => g.is_backlog || g.status === 'notStarted');
      return backlog.length > 0 ? backlog : owned;
    }
    if (selectedMood === 'top') {
      const top = owned.filter((g) => {
        const r = g.igdb_rating || g.rating;
        return r && Number(r) >= 80;
      });
      return top.length > 0 ? top : owned;
    }
    return owned;
  }, [games, selectedMood, discoveryGames]);

  const spinRoulette = (customPool?: Game[]) => {
    const pool = customPool || candidateGames;
    if (!pool || pool.length === 0) {
      setSelectedWinner(null);
      setDisplayedGame(null);
      setSmartReason('');
      return;
    }

    setIsSpinning(true);
    setSelectedWinner(null);
    setSmartReason('');

    let counter = 0;
    const totalSteps = 22 + Math.floor(Math.random() * 8);
    const speed = 65;

    const interval = setInterval(() => {
      const randomIndex = Math.floor(Math.random() * pool.length);
      setDisplayedGame(pool[randomIndex]);
      counter++;

      if (counter >= totalSteps) {
        clearInterval(interval);
        const finalWinner = pool[Math.floor(Math.random() * pool.length)];
        setDisplayedGame(finalWinner);
        setSelectedWinner(finalWinner);
        setSmartReason(getSmartRouletteReason(finalWinner, selectedMood));
        setIsSpinning(false);
      }
    }, speed);
  };

  // När modalläget öppnas
  useEffect(() => {
    if (isOpen) {
      setSelectedWinner(null);
      setDisplayedGame(null);
      setSmartReason('');
      if (selectedMood === 'discover' || discoveryGames.length === 0) {
        loadDiscoveryGames().then((results) => {
          if (selectedMood === 'discover' && results && results.length > 0) {
            spinRoulette(results);
          } else if (hasOwnedGames) {
            spinRoulette();
          }
        });
      } else {
        spinRoulette();
      }
    }
  }, [isOpen, selectedMood]);

  if (!isOpen) return null;

  const handleStartPlaying = (game: Game) => {
    onUpdateGameStatus(game.id, 'playing');
    onClose();
    onSelectGame({ ...game, status: 'playing', is_backlog: false });
  };

  const handleAddDiscoveryGame = (
    game: Game,
    options: { status: PlayStatus; isOwned: boolean; isBacklog: boolean }
  ) => {
    const playTypes = game.play_types || inferPlayTypes(game);
    const newGame: Game = {
      ...game,
      id: crypto.randomUUID(),
      status: options.status,
      is_owned: options.isOwned,
      is_backlog: options.isBacklog,
      play_types: playTypes,
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
      <div className="bg-[#14151b] border border-zinc-800 rounded-3xl w-full max-w-xl shadow-2xl overflow-hidden flex flex-col">
        {/* Header */}
        <div className="p-5 border-b border-zinc-800/80 flex items-center justify-between bg-gradient-to-r from-brand-red/15 via-rose-950/20 to-transparent">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-2xl bg-brand-red/20 border border-brand-red/40 flex items-center justify-center text-brand-red shadow-inner">
              <Dices className="w-5 h-5 animate-pulse" />
            </div>
            <div>
              <h3 className="font-bold text-white text-lg flex items-center gap-2">
                <span>Smart Spelsnurra</span>
                <Sparkles className="w-4 h-4 text-amber-400" />
              </h3>
              <p className="text-xs text-zinc-400">
                Låt slumpen välja rätt spel baserat på tid, humör eller backlog.
              </p>
            </div>
          </div>

          <button
            onClick={onClose}
            className="p-2 rounded-xl bg-zinc-900/80 hover:bg-zinc-800 text-zinc-400 hover:text-white border border-zinc-800 transition cursor-pointer"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Smarta Humör / Filter Pills */}
        <div className="p-4 border-b border-zinc-800/60 bg-zinc-950/40">
          <div className="text-[11px] font-bold text-zinc-400 uppercase tracking-wider mb-2 flex items-center gap-1.5">
            <span>Vad är du sugen på?</span>
          </div>
          <div className="flex items-center gap-2 overflow-x-auto pb-1 scrollbar-none">
            {MOOD_OPTIONS.map((mood) => {
              const Icon = mood.icon;
              const isActive = selectedMood === mood.id;
              return (
                <button
                  key={mood.id}
                  disabled={isSpinning}
                  onClick={() => setSelectedMood(mood.id)}
                  className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold whitespace-nowrap transition cursor-pointer ${
                    isActive
                      ? 'bg-brand-red text-white shadow-md shadow-brand-red/25 font-extrabold'
                      : 'bg-zinc-900 border border-zinc-800 text-zinc-400 hover:text-zinc-200'
                  }`}
                  title={mood.desc}
                >
                  <Icon className="w-3.5 h-3.5" />
                  <span>{mood.label}</span>
                </button>
              );
            })}
          </div>
          <div className="flex items-center justify-between text-[11px] text-zinc-500 mt-2 px-0.5">
            <span>
              {MOOD_OPTIONS.find((m) => m.id === selectedMood)?.desc}
            </span>
            <span>
              {isLoadingDiscovery ? 'Laddar...' : `${candidateGames.length} spel i poolen`}
            </span>
          </div>
        </div>

        {/* Main Roulette Display */}
        <div className="p-6 flex flex-col items-center justify-center min-h-[340px] bg-gradient-to-b from-transparent to-zinc-950/40">
          {isLoadingDiscovery && candidateGames.length === 0 ? (
            <div className="text-center py-12">
              <RotateCw className="w-8 h-8 text-brand-red animate-spin mx-auto mb-3" />
              <p className="text-xs text-zinc-400 font-medium">Hämtar smarta spelförslag...</p>
            </div>
          ) : candidateGames.length === 0 ? (
            <div className="text-center py-10 space-y-2">
              <Gamepad className="w-12 h-12 text-zinc-600 mx-auto mb-1" />
              <h4 className="text-sm font-semibold text-zinc-300">Inga spel matchade filtret</h4>
              <p className="text-xs text-zinc-500 max-w-xs mx-auto">
                Testa att byta till "Ren slump" eller "Upptäck nytt" för att hitta titlar.
              </p>
            </div>
          ) : (
            <div className="w-full flex flex-col items-center">
              {/* Spinning / Selected Card */}
              <div
                className={`relative w-44 sm:w-48 aspect-[3/4] rounded-2xl overflow-hidden bg-zinc-900 border-2 shadow-2xl transition-all duration-300 ${
                  isSpinning
                    ? 'border-brand-red/60 scale-95 blur-[0.4px]'
                    : selectedWinner
                    ? 'border-brand-red scale-105 shadow-brand-red/25 ring-4 ring-brand-red/20'
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
                {displayedGame && (
                  <div className="absolute top-2.5 left-2.5">
                    {displayedGame.is_owned ? (
                      <StatusBadge game={displayedGame} size="sm" />
                    ) : (
                      <span className="px-2 py-0.5 rounded-md bg-amber-500 text-zinc-950 text-[10px] font-black shadow-md">
                        Nytt förslag
                      </span>
                    )}
                  </div>
                )}
              </div>

              {/* Game Info Details */}
              <div className="mt-5 text-center max-w-sm px-2">
                <h4 className="text-lg font-bold text-white line-clamp-1 leading-snug">
                  {displayedGame?.title || 'Snurrar...'}
                </h4>
                <div className="flex items-center justify-center gap-2 mt-1 text-xs text-zinc-400">
                  {displayedGame?.release_year && (
                    <span className="px-2 py-0.5 rounded bg-zinc-800 text-zinc-300 font-semibold">
                      {displayedGame.release_year}
                    </span>
                  )}
                  {displayedGame?.genres && displayedGame.genres.length > 0 && (
                    <span className="text-zinc-300">
                      {displayedGame.genres[0]}
                    </span>
                  )}
                  {displayedGame?.platforms && displayedGame.platforms.length > 0 && (
                    <span className="truncate max-w-[140px] text-zinc-500">
                      {displayedGame.platforms.slice(0, 2).join(', ')}
                    </span>
                  )}
                </div>

                {/* Smart Motivation Reason */}
                {smartReason && !isSpinning && (
                  <div className="mt-3.5 inline-flex items-center gap-2 px-3.5 py-1.5 rounded-xl bg-amber-500/10 border border-amber-500/25 text-amber-300 text-xs font-medium animate-in fade-in duration-300">
                    <Lightbulb className="w-3.5 h-3.5 text-amber-400 shrink-0" />
                    <span>{smartReason}</span>
                  </div>
                )}
              </div>
            </div>
          )}
        </div>

        {/* Footer Actions */}
        <div className="p-5 border-t border-zinc-800 bg-zinc-950/70 flex flex-col sm:flex-row items-center justify-between gap-3">
          <button
            onClick={() => spinRoulette()}
            disabled={isSpinning || candidateGames.length === 0}
            className="w-full sm:w-auto flex items-center justify-center gap-2 px-5 py-2.5 rounded-xl bg-zinc-800 hover:bg-zinc-700 disabled:opacity-50 text-zinc-200 text-xs font-bold border border-zinc-700 transition cursor-pointer"
          >
            <RotateCw className={`w-4 h-4 ${isSpinning ? 'animate-spin text-brand-red' : ''}`} />
            <span>{isSpinning ? 'Snurrar hjulet...' : '🎲 Snurra igen'}</span>
          </button>

          {selectedWinner && !isSpinning && (
            <div className="flex items-center gap-2 w-full sm:w-auto">
              {selectedWinner.is_owned ? (
                <>
                  <button
                    onClick={() => {
                      onSelectGame(selectedWinner);
                      onClose();
                    }}
                    className="flex-1 sm:flex-none px-4 py-2.5 rounded-xl bg-zinc-800 hover:bg-zinc-700 text-zinc-200 text-xs font-semibold border border-zinc-700 transition cursor-pointer"
                  >
                    Se detaljer
                  </button>

                  <button
                    onClick={() => handleStartPlaying(selectedWinner)}
                    className="flex-1 sm:flex-none flex items-center justify-center gap-2 px-5 py-2.5 rounded-xl bg-brand-red hover:bg-brand-redPressed text-white text-xs font-bold shadow-lg shadow-brand-red/25 transition transform active:scale-95 cursor-pointer"
                  >
                    <Play className="w-3.5 h-3.5 fill-current" />
                    <span>Börja spela!</span>
                  </button>
                </>
              ) : (
                /* Discovery Actions */
                <div className="flex items-center gap-2 w-full sm:w-auto">
                  {addedGameIds.has(selectedWinner.id) ? (
                    <div className="flex items-center gap-1.5 px-4 py-2.5 rounded-xl bg-emerald-950 border border-emerald-500/40 text-emerald-300 text-xs font-bold">
                      <Check className="w-4 h-4 text-emerald-400" />
                      <span>Tillagd i biblioteket!</span>
                    </div>
                  ) : (
                    <>
                      <button
                        onClick={() =>
                          handleAddDiscoveryGame(selectedWinner, {
                            status: 'notStarted',
                            isOwned: false,
                            isBacklog: false,
                          })
                        }
                        className="flex-1 sm:flex-none flex items-center justify-center gap-1.5 px-3.5 py-2.5 rounded-xl bg-zinc-800 hover:bg-zinc-700 text-zinc-200 text-xs font-semibold border border-zinc-700 transition cursor-pointer"
                      >
                        <BookmarkPlus className="w-3.5 h-3.5" />
                        <span>+ Önskelista</span>
                      </button>

                      <button
                        onClick={() =>
                          handleAddDiscoveryGame(selectedWinner, {
                            status: 'notStarted',
                            isOwned: true,
                            isBacklog: true,
                          })
                        }
                        className="flex-1 sm:flex-none flex items-center justify-center gap-1.5 px-4 py-2.5 rounded-xl bg-amber-500 hover:bg-amber-400 text-zinc-950 text-xs font-bold shadow-lg shadow-amber-500/20 transition transform active:scale-95 cursor-pointer"
                      >
                        <Plus className="w-3.5 h-3.5" />
                        <span>+ Backlog</span>
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
