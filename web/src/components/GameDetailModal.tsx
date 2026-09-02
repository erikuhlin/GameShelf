'use client';

import React, { useState, useEffect } from 'react';
import { Game, GameCollection, PlayStatus, PLAY_STATUSES, GameTodoItem, GamePlayType } from '@/types/game';
import { supabase } from '@/lib/supabase';
import { StatusBadge } from './StatusBadge';
import { ReleaseCountdown } from './ReleaseCountdown';
import { getStatusDisplayTitle, inferPlayTypes } from '@/lib/statusHelper';
import {
  X,
  Star,
  Trash2,
  Check,
  Plus,
  Clock,
  Gamepad,
  Bookmark,
  Sparkles,
  Calendar,
  Save,
  Image as ImageIcon,
  BookOpen,
  Timer,
  Building2,
  Layers,
  Video,
  ExternalLink,
  ChevronRight,
  ShieldCheck,
  Share2,
  Target,
} from 'lucide-react';
import { GameShareModal } from './GameShareModal';

interface GameDetailModalProps {
  game: Game | null;
  isOpen: boolean;
  onClose: () => void;
  onUpdateGame: (updated: Game) => void;
  onDeleteGame: (id: string) => void;
  collections: GameCollection[];
  onToggleCollection: (gameId: string, collectionId: string) => void;
  onCreateCollection?: (name: string, gameId: string) => Promise<void> | void;
  onOpenCompany?: (companyId: number, companyName: string, role: 'developer' | 'publisher') => void;
  isTargetGoal?: boolean;
  onToggleTargetGoal?: (gameId: string) => void;
}

interface RemoteDetails {
  summary?: string;
  storyline?: string;
  screenshots?: Array<{ id: number; url: string; fullUrl: string }>;
  artworks?: Array<{ id: number; url: string; fullUrl: string }>;
  developers?: string[];
  publishers?: string[];
  developerCompanies?: Array<{ id: number; name: string }>;
  publisherCompanies?: Array<{ id: number; name: string }>;
  gameModes?: string[];
  themes?: string[];
  videos?: Array<{ name: string; videoId: string }>;
  similarGames?: Array<{
    id: number;
    title: string;
    coverUrl?: string | null;
    releaseYear?: number | null;
    rating?: number | null;
  }>;
  timeToBeat?: {
    mainStory: number | null;
    mainExtra: number | null;
    completionist: number | null;
  } | null;
}

export function GameDetailModal({
  game,
  isOpen,
  onClose,
  onUpdateGame,
  onDeleteGame,
  collections,
  onToggleCollection,
  onCreateCollection,
  onOpenCompany,
  isTargetGoal,
  onToggleTargetGoal,
}: GameDetailModalProps) {
  if (!isOpen || !game) return null;

  const [status, setStatus] = useState<PlayStatus>(game.status);
  const [isBacklog, setIsBacklog] = useState<boolean>(game.is_backlog ?? false);
  const [completedYear, setCompletedYear] = useState<number | null>(game.completed_year ?? null);
  const [playTypes, setPlayTypes] = useState<GamePlayType[]>(
    game.play_types && game.play_types.length > 0
      ? game.play_types
      : inferPlayTypes({ title: game.title, genres: game.genres })
  );
  const [rating, setRating] = useState<number | null>(game.rating || null);
  const [isOwned, setIsOwned] = useState<boolean>(game.is_owned);
  const [estimatedHours, setEstimatedHours] = useState<number | string>(
    game.estimated_hours ?? ''
  );
  const [notes, setNotes] = useState<string>(game.notes || '');
  const [todos, setTodos] = useState<GameTodoItem[]>(game.todos || []);
  const [newTodoTitle, setNewTodoTitle] = useState('');
  const [isSaving, setIsSaving] = useState(false);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [liveReleaseDate, setLiveReleaseDate] = useState<number | null>(
    game.first_release_date || null
  );
  const [remoteDetails, setRemoteDetails] = useState<RemoteDetails | null>(null);
  const [isLoadingDetails, setIsLoadingDetails] = useState(false);
  const [activeLightboxImg, setActiveLightboxImg] = useState<string | null>(null);
  const [isShareModalOpen, setIsShareModalOpen] = useState(false);

  // Samlingsskapare state
  const [isCreatingCollection, setIsCreatingCollection] = useState(false);
  const [newCollectionName, setNewCollectionName] = useState('');
  const [isSubmittingCollection, setIsSubmittingCollection] = useState(false);

  // Återställ formulärstate när ett nytt spel öppnas
  useEffect(() => {
    if (game) {
      setStatus(game.status);
      setIsBacklog(game.is_backlog ?? false);
      setCompletedYear(game.completed_year ?? null);
      setPlayTypes(
        game.play_types && game.play_types.length > 0
          ? game.play_types
          : inferPlayTypes({ title: game.title, genres: game.genres })
      );
      setRating(game.rating || null);
      setIsOwned(game.is_owned);
      setEstimatedHours(game.estimated_hours ?? '');
      setNotes(game.notes || '');
      setTodos(game.todos || []);
      setLiveReleaseDate(game.first_release_date || null);
      setRemoteDetails(null);
      setIsCreatingCollection(false);
      setNewCollectionName('');
    }
  }, [game?.id]);

  // Hämta utökad IGDB-information och exakt releasedatum
  useEffect(() => {
    if (!game) return;

    const currentGame = game;
    let isMounted = true;
    const currentYear = new Date().getFullYear();

    async function loadDetails() {
      setIsLoadingDetails(true);
      try {
        let date: number | null = currentGame.first_release_date || null;
        let igdbId: number | null = currentGame.igdb_id ? Number(currentGame.igdb_id) : null;
        let detailsData: any = null;

        if (igdbId) {
          const res = await fetch(`/api/igdb/games/${igdbId}`);
          if (res.ok) {
            const data = await res.json();
            const fetchedGame = data?.game;
            const fetchedDate = fetchedGame?.first_release_date || null;
            const fetchedYear = fetchedDate
              ? new Date(fetchedDate * 1000).getFullYear()
              : fetchedGame?.release_year;

            // Om spelet är tänkt som kommande men ID:t pekar på ett gammalt spel (t.ex. Fable 2004)
            if (
              currentGame.release_year &&
              currentGame.release_year >= currentYear &&
              fetchedYear &&
              fetchedYear < currentYear
            ) {
              date = null;
              igdbId = null;
            } else {
              date = fetchedDate || date;
              detailsData = fetchedGame;
            }
          }
        }

        if ((!detailsData || !date) && currentGame.title) {
          const res = await fetch(`/api/igdb/search?q=${encodeURIComponent(currentGame.title)}`);
          if (res.ok) {
            const data = await res.json();
            const results = data?.results || data?.games || [];
            const targetTitle = currentGame.title.toLowerCase().trim();

            // 1. Exakt titel och samma år
            let bestMatch = currentGame.release_year
              ? results.find((r: any) => {
                  const y = r.first_release_date
                    ? new Date(r.first_release_date * 1000).getFullYear()
                    : r.release_year;
                  return r.name?.toLowerCase().trim() === targetTitle && y === currentGame.release_year;
                })
              : null;

            // 2. Om spelet är kommande (>= currentYear), hitta match med framtida år
            if (!bestMatch && currentGame.release_year && currentGame.release_year >= currentYear) {
              bestMatch = results.find((r: any) => {
                const y = r.first_release_date
                  ? new Date(r.first_release_date * 1000).getFullYear()
                  : r.release_year;
                return r.name?.toLowerCase().trim() === targetTitle && y && y >= currentYear;
              });
            }

            // 3. Exakt titelmatch
            if (!bestMatch) {
              bestMatch = results.find((r: any) => r.name?.toLowerCase().trim() === targetTitle);
            }

            // 4. Prefix match
            if (!bestMatch) {
              bestMatch = results.find((r: any) => r.name?.toLowerCase().trim().startsWith(targetTitle));
            }

            if (!bestMatch && results.length > 0) {
              bestMatch = results[0];
            }

            if (bestMatch?.id) {
              igdbId = bestMatch.id;
              if (bestMatch.first_release_date) {
                date = bestMatch.first_release_date;
              }
              // Hämta fullständiga detaljer för den hittade matchen
              const fullRes = await fetch(`/api/igdb/games/${bestMatch.id}`);
              if (fullRes.ok) {
                const fullData = await fullRes.json();
                if (fullData?.game) {
                  detailsData = fullData.game;
                  if (fullData.game.first_release_date) {
                    date = fullData.game.first_release_date;
                  }
                }
              }
            }
          }
        }

        if (isMounted) {
          if (detailsData) {
            setRemoteDetails({
              summary: detailsData.summary || detailsData.storyline || '',
              storyline: detailsData.storyline || '',
              screenshots: detailsData.screenshots || [],
              artworks: detailsData.artworks || [],
              developers: detailsData.developers || [],
              publishers: detailsData.publishers || [],
              developerCompanies: detailsData.developerCompanies || [],
              publisherCompanies: detailsData.publisherCompanies || [],
              gameModes: detailsData.gameModes || [],
              themes: detailsData.themes || [],
              videos: detailsData.videos || [],
              similarGames: detailsData.similarGames || [],
              timeToBeat: detailsData.timeToBeat || null,
            });
          }

          if (date) {
            setLiveReleaseDate(date);
            onUpdateGame({
              ...currentGame,
              first_release_date: date,
              ...(igdbId ? { igdb_id: igdbId } : {}),
            });

            supabase
              .from('user_games')
              .update({
                first_release_date: date,
                ...(igdbId ? { igdb_id: igdbId } : {}),
              })
              .eq('id', currentGame.id)
              .then(() => {});
          }
        }
      } catch (err) {
        console.error('Error fetching extended IGDB details:', err);
      } finally {
        if (isMounted) setIsLoadingDetails(false);
      }
    }

    loadDetails();

    return () => {
      isMounted = false;
    };
  }, [game.id, game.igdb_id, game.first_release_date, game.title]);

  const handleAddTodo = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newTodoTitle.trim()) return;

    const newItem: GameTodoItem = {
      id: crypto.randomUUID(),
      title: newTodoTitle.trim(),
      isDone: false,
    };

    setTodos([...todos, newItem]);
    setNewTodoTitle('');
  };

  const handleToggleTodo = (todoId: string) => {
    setTodos(
      todos.map((t) => (t.id === todoId ? { ...t, isDone: !t.isDone } : t))
    );
  };

  const handleDeleteTodo = (todoId: string) => {
    setTodos(todos.filter((t) => t.id !== todoId));
  };

  const handleCreateCollection = async () => {
    const trimmed = newCollectionName.trim();
    if (!trimmed) return;
    setIsSubmittingCollection(true);
    try {
      if (onCreateCollection) {
        await onCreateCollection(trimmed, game.id);
      }
      setNewCollectionName('');
      setIsCreatingCollection(false);
    } catch (e) {
      console.error('Failed to create collection:', e);
    } finally {
      setIsSubmittingCollection(false);
    }
  };

  const handleSave = async () => {
    setIsSaving(true);
    try {
      const shouldClearBacklog = status === 'playing';
      const finalBacklog = shouldClearBacklog ? false : isBacklog;
      const lastPlayed =
        status === 'playing'
          ? game.last_played_date || new Date().toISOString()
          : game.last_played_date;
      const isCompleted = status === 'completed';
      const finalCompletedYear = isCompleted ? completedYear : null;
      const finalCompletedDate = isCompleted
        ? (completedYear ? (game.completed_date || new Date().toISOString()) : null)
        : null;

      const updatedData = {
        status,
        rating: rating || null,
        is_owned: isOwned,
        estimated_hours: estimatedHours !== '' ? Number(estimatedHours) : null,
        notes,
        todos,
        is_backlog: finalBacklog,
        play_types: playTypes,
        last_played_date: lastPlayed,
        completed_year: finalCompletedYear,
        completed_date: finalCompletedDate,
      };

      const { error } = await supabase
        .from('user_games')
        .update(updatedData)
        .eq('id', game.id);

      if (error) {
        console.error('Supabase update failed:', error);
      }

      const mergedGame: Game = {
        ...game,
        ...updatedData,
        updated_at: new Date().toISOString(),
      };

      onUpdateGame(mergedGame);
      onClose();
    } catch (err) {
      console.error('Error saving game changes:', err);
    } finally {
      setIsSaving(false);
    }
  };

  const handleDelete = async () => {
    try {
      const { error } = await supabase.from('user_games').delete().eq('id', game.id);
      if (error) console.error('Supabase delete error:', error);
      onDeleteGame(game.id);
      onClose();
    } catch (err) {
      console.error('Error deleting game:', err);
    }
  };

  const displayDevelopers =
    remoteDetails?.developers && remoteDetails.developers.length > 0
      ? remoteDetails.developers
      : game.developers || [];

  const displayPublishers = remoteDetails?.publishers || [];
  const displaySummary = remoteDetails?.summary || game.summary || '';
  const displayScreenshots = remoteDetails?.screenshots || [];
  const displayVideos = remoteDetails?.videos || [];
  const displaySimilar = remoteDetails?.similarGames || [];
  const displayTTB = remoteDetails?.timeToBeat;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-black/85 backdrop-blur-md animate-in fade-in duration-200">
      <div className="bg-[#121318] border border-zinc-800/90 rounded-2xl w-full max-w-4xl max-h-[92vh] flex flex-col shadow-2xl overflow-hidden">
        {/* Header / Backdrop Banner */}
        <div className="relative p-5 sm:p-6 border-b border-zinc-800/80 bg-gradient-to-r from-zinc-900 via-zinc-900/90 to-zinc-950 flex items-start justify-between">
          <div className="flex gap-4 sm:gap-6 items-start">
            {/* Cover art */}
            <div className="w-24 sm:w-28 aspect-[3/4] rounded-xl overflow-hidden bg-zinc-800 border border-zinc-700/80 shadow-xl flex-shrink-0">
              {game.cover_url ? (
                <img
                  src={game.cover_url}
                  alt={game.title}
                  className="w-full h-full object-cover"
                />
              ) : (
                <div className="w-full h-full flex items-center justify-center">
                  <Gamepad className="w-8 h-8 text-zinc-600" />
                </div>
              )}
            </div>

            {/* Title & basic meta */}
            <div className="flex-1 min-w-0">
              <div className="flex flex-wrap items-center gap-2 mb-1.5">
                <StatusBadge
                  status={status}
                  isMultiplayer={
                    playTypes.includes('multiplayer') ||
                    playTypes.includes('ongoing') ||
                    playTypes.includes('coOp')
                  }
                  game={{ ...game, is_backlog: isBacklog }}
                  size="sm"
                />
                {game.igdb_rating && (
                  <span className="text-xs px-2 py-0.5 rounded-md bg-zinc-800/90 text-amber-300 border border-zinc-700/80 flex items-center gap-1 font-semibold">
                    <Sparkles className="w-3 h-3 text-amber-400" />
                    IGDB {(Math.round(Number(game.igdb_rating) * 10) / 10).toFixed(1)}/10
                  </span>
                )}
              </div>

              <h2 className="text-xl sm:text-2xl font-bold text-white tracking-tight leading-snug">
                {game.title}
              </h2>

              <div className="flex flex-wrap items-center gap-2 mt-2 text-xs text-zinc-400">
                {liveReleaseDate ? (
                  <span className="flex items-center gap-1 font-semibold text-zinc-200">
                    <Calendar className="w-3.5 h-3.5 text-red-400" />
                    {new Date(liveReleaseDate * 1000).toLocaleDateString('sv-SE', {
                      year: 'numeric',
                      month: 'short',
                      day: 'numeric',
                    })}
                  </span>
                ) : game.release_year ? (
                  <span className="flex items-center gap-1">
                    <Calendar className="w-3.5 h-3.5 text-zinc-500" />
                    {game.release_year}
                  </span>
                ) : null}

                {displayDevelopers.length > 0 && (
                  <>
                    <span>•</span>
                    <div className="inline-flex items-center gap-1.5 flex-wrap">
                      {displayDevelopers.map((devName, i) => {
                        const compObj = remoteDetails?.developerCompanies?.find((c) => c.name === devName);
                        return (
                          <button
                            key={i}
                            type="button"
                            onClick={() => onOpenCompany?.(compObj?.id || 0, devName, 'developer')}
                            className="inline-flex items-center gap-1 text-red-400 hover:text-red-300 font-semibold transition hover:underline cursor-pointer"
                            title={`Visa alla spel från ${devName}`}
                          >
                            <Building2 className="w-3.5 h-3.5 text-red-500" />
                            <span>{devName}</span>
                            <span className="text-[10px] text-zinc-500">→</span>
                          </button>
                        );
                      })}
                    </div>
                  </>
                )}
              </div>

              {game.platforms && game.platforms.length > 0 && (
                <div className="flex flex-wrap gap-1.5 mt-3">
                  {game.platforms.map((p) => (
                    <span
                      key={p}
                      className="px-2 py-0.5 rounded text-[11px] font-medium bg-zinc-800/80 text-zinc-300 border border-zinc-700/60"
                    >
                      {p}
                    </span>
                  ))}
                </div>
              )}
            </div>
          </div>

          <div className="flex items-center gap-2 flex-shrink-0 ml-3">
            {onToggleTargetGoal && (
              <button
                type="button"
                onClick={() => onToggleTargetGoal(game.id)}
                className={`p-2 rounded-xl transition flex items-center gap-1.5 text-xs font-bold border shadow-sm cursor-pointer ${
                  isTargetGoal
                    ? 'bg-amber-500/20 border-amber-500/80 text-amber-400 hover:bg-amber-500/30'
                    : 'bg-zinc-800/80 hover:bg-zinc-700 text-zinc-300 hover:text-white border-zinc-700/60'
                }`}
                title={isTargetGoal ? 'Ta bort som spelmål' : 'Sätt som aktivt fokusmål'}
              >
                <Target className={`w-4 h-4 ${isTargetGoal ? 'text-amber-400 fill-amber-400/20' : 'text-zinc-400'}`} />
                <span className="hidden sm:inline">{isTargetGoal ? 'Aktivt Mål 🎯' : 'Spelmål 🎯'}</span>
              </button>
            )}
            <button
              onClick={() => setIsShareModalOpen(true)}
              className="p-2 rounded-xl bg-zinc-800/80 hover:bg-zinc-700 text-zinc-200 hover:text-white transition flex items-center gap-1.5 text-xs font-bold border border-zinc-700/60 shadow-sm cursor-pointer"
              title="Dela spelkort som bild eller länk"
            >
              <Share2 className="w-4 h-4 text-red-500" />
              <span className="hidden sm:inline">Dela</span>
            </button>
            <button
              onClick={onClose}
              className="p-2 rounded-xl bg-zinc-800/80 hover:bg-zinc-700 text-zinc-400 hover:text-white transition flex-shrink-0"
              aria-label="Stäng"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        {/* Modal Body */}
        <div className="flex-1 overflow-y-auto p-5 sm:p-6 space-y-6">
          {/* 1. Release Countdown for upcoming games */}
          <ReleaseCountdown
            firstReleaseDate={liveReleaseDate}
            releaseYear={game.release_year}
          />

          {/* 2. Controls: Status & Rating */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            {/* Status Picker & Backlog */}
            <div className="bg-zinc-900/70 border border-zinc-800 p-4 rounded-xl flex flex-col justify-between">
              <div>
                <label className="block text-xs font-bold text-zinc-400 uppercase tracking-wider mb-2">
                  Spelstatus
                </label>
                <select
                  value={status}
                  onChange={(e) => {
                    const newStatus = e.target.value as PlayStatus;
                    setStatus(newStatus);
                    if (newStatus === 'playing') {
                      setIsBacklog(false);
                    }
                    if (newStatus === 'completed' && completedYear === null) {
                      setCompletedYear(new Date().getFullYear());
                    }
                  }}
                  className="w-full bg-zinc-950 border border-zinc-700 text-zinc-100 rounded-lg px-3 py-2 text-sm focus:outline-none focus:border-red-500 font-medium"
                >
                  {PLAY_STATUSES.map((s) => (
                    <option key={s} value={s}>
                      {getStatusDisplayTitle(
                        s,
                        playTypes.includes('multiplayer') ||
                          playTypes.includes('ongoing') ||
                          playTypes.includes('coOp')
                      )}
                    </option>
                  ))}
                </select>
              </div>

              {/* Backlog Toggle */}
              <div className="mt-3 pt-3 border-t border-zinc-800 flex items-center justify-between">
                <div>
                  <span className="text-xs font-semibold text-zinc-200 block">
                    Planerar att spela (Backlog)
                  </span>
                  <span className="text-[11px] text-zinc-500">
                    Markerar spelet som del av din backlog
                  </span>
                </div>
                <input
                  type="checkbox"
                  checked={isBacklog}
                  onChange={(e) => setIsBacklog(e.target.checked)}
                  className="w-4 h-4 rounded accent-blue-600 bg-zinc-950 border-zinc-700 cursor-pointer"
                />
              </div>

              {/* Klarat år (Spelmål) */}
              {status === 'completed' && (
                <div className="mt-3 pt-3 border-t border-zinc-800 flex items-center justify-between">
                  <div>
                    <span className="text-xs font-semibold text-zinc-200 block">
                      Klarat år (Spelmål)
                    </span>
                    <span className="text-[11px] text-zinc-500">
                      Endast aktuellt år räknas till årets mål
                    </span>
                  </div>
                  <select
                    value={completedYear ?? ''}
                    onChange={(e) => {
                      const val = e.target.value;
                      setCompletedYear(val === '' ? null : Number(val));
                    }}
                    className="bg-zinc-950 border border-zinc-700 text-zinc-100 rounded-lg px-2.5 py-1.5 text-xs font-medium focus:outline-none focus:border-amber-500 cursor-pointer"
                  >
                    <option value="">Ej angivet (Lämna tomt)</option>
                    <option value={new Date().getFullYear()}>{new Date().getFullYear()} (I år)</option>
                    {Array.from({ length: 15 }, (_, i) => new Date().getFullYear() - 1 - i).map((y) => (
                      <option key={y} value={y}>{y}</option>
                    ))}
                  </select>
                </div>
              )}
            </div>

            {/* Rating Selector (1-10) */}
            <div className="bg-zinc-900/70 border border-zinc-800 p-4 rounded-xl">
              <div className="flex items-center justify-between mb-2">
                <label className="block text-xs font-bold text-zinc-400 uppercase tracking-wider">
                  Mitt betyg
                </label>
                {rating && (
                  <button
                    onClick={() => setRating(null)}
                    className="text-xs text-zinc-500 hover:text-red-400 transition"
                  >
                    Rensa
                  </button>
                )}
              </div>
              <div className="flex items-center gap-1.5 overflow-x-auto pb-1">
                {[1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map((num) => (
                  <button
                    key={num}
                    onClick={() => setRating(rating === num ? null : num)}
                    className={`flex-1 py-1.5 text-xs font-bold rounded-lg border transition ${
                      rating && rating >= num
                        ? 'bg-amber-500/20 border-amber-500 text-amber-300'
                        : 'bg-zinc-950 border-zinc-800 text-zinc-400 hover:border-zinc-700 hover:text-zinc-200'
                    }`}
                  >
                    {num}
                  </button>
                ))}
              </div>
            </div>
          </div>

          {/* 3. Extra Local Details: Owned & Estimated Time */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div className="bg-zinc-900/70 border border-zinc-800 p-4 rounded-xl flex items-center justify-between">
              <div>
                <span className="block text-sm font-semibold text-zinc-200">
                  Äger spelet
                </span>
                <span className="text-xs text-zinc-500">
                  Markerad som fysisk eller digital utgåva i din ägo
                </span>
              </div>
              <input
                type="checkbox"
                checked={isOwned}
                onChange={(e) => setIsOwned(e.target.checked)}
                className="w-5 h-5 rounded accent-red-600 bg-zinc-950 border-zinc-700 cursor-pointer"
              />
            </div>

            <div className="bg-zinc-900/70 border border-zinc-800 p-4 rounded-xl">
              <label className="block text-xs font-bold text-zinc-400 uppercase tracking-wider mb-2">
                Uppskattad speltid (timmar)
              </label>
              <div className="relative">
                <input
                  type="number"
                  value={estimatedHours}
                  onChange={(e) => setEstimatedHours(e.target.value)}
                  placeholder="t.ex. 25"
                  className="w-full bg-zinc-950 border border-zinc-700 text-zinc-100 rounded-lg px-3 py-2 pl-8 text-sm focus:outline-none focus:border-red-500"
                />
                <Clock className="w-4 h-4 text-zinc-500 absolute left-2.5 top-2.5" />
              </div>
            </div>
          </div>

          {/* 3b. Speltyper */}
          <div className="bg-zinc-900/70 border border-zinc-800 p-4 rounded-xl">
            <div className="flex items-center justify-between mb-2">
              <label className="block text-xs font-bold text-zinc-400 uppercase tracking-wider">
                Speltyp
              </label>
              <span className="text-[11px] text-zinc-500">
                Styr dynamiska statustitlar och framsteg
              </span>
            </div>
            <div className="flex flex-wrap gap-2">
              {(
                [
                  { id: 'singlePlayer', label: 'Singleplayer' },
                  { id: 'multiplayer', label: 'Multiplayer' },
                  { id: 'coOp', label: 'Co-op' },
                  { id: 'ongoing', label: 'Ongoing / Live-service' },
                ] as const
              ).map((item) => {
                const active = playTypes.includes(item.id);
                return (
                  <button
                    key={item.id}
                    type="button"
                    onClick={() => {
                      if (active) {
                        if (playTypes.length > 1) {
                          setPlayTypes(playTypes.filter((t) => t !== item.id));
                        }
                      } else {
                        setPlayTypes([...playTypes, item.id]);
                      }
                    }}
                    className={`px-3 py-1.5 text-xs font-semibold rounded-lg border transition ${
                      active
                        ? 'bg-red-500/20 border-red-500 text-red-300'
                        : 'bg-zinc-950 border-zinc-800 text-zinc-400 hover:border-zinc-700 hover:text-zinc-200'
                    }`}
                  >
                    {active ? '✓ ' : ''}
                    {item.label}
                  </button>
                );
              })}
            </div>
          </div>

          {/* 4. Skärmdumpar & Bildgalleri */}
          {displayScreenshots.length > 0 && (
            <div className="bg-zinc-900/60 border border-zinc-800 p-5 rounded-2xl space-y-3">
              <div className="flex items-center gap-2 text-sm font-bold text-zinc-200 uppercase tracking-wider">
                <ImageIcon className="w-4 h-4 text-red-500" />
                <span>Skärmdumpar</span>
              </div>
              <div className="flex gap-3 overflow-x-auto pb-2 scrollbar-thin scrollbar-thumb-zinc-700">
                {displayScreenshots.map((img, idx) => (
                  <div
                    key={img.id || idx}
                    onClick={() => setActiveLightboxImg(img.fullUrl || img.url)}
                    className="relative flex-shrink-0 w-60 sm:w-72 aspect-video rounded-xl overflow-hidden bg-zinc-950 border border-zinc-800 hover:border-zinc-600 cursor-pointer group shadow-md"
                  >
                    <img
                      src={img.url}
                      alt={`Skärmdump ${idx + 1}`}
                      className="w-full h-full object-cover group-hover:scale-105 transition duration-300"
                      loading="lazy"
                    />
                    <div className="absolute inset-0 bg-black/30 opacity-0 group-hover:opacity-100 transition flex items-center justify-center text-white text-xs font-semibold">
                      Klicka för fullskärm
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* 5. Om spelet (Handling / Synopsis) */}
          {displaySummary && (
            <div className="bg-zinc-900/60 border border-zinc-800 p-5 rounded-2xl space-y-2.5">
              <div className="flex items-center gap-2 text-sm font-bold text-zinc-200 uppercase tracking-wider">
                <BookOpen className="w-4 h-4 text-red-500" />
                <span>Om spelet</span>
              </div>
              <p className="text-sm text-zinc-300 leading-relaxed whitespace-pre-line">
                {displaySummary}
              </p>
              {remoteDetails?.storyline && remoteDetails.storyline !== displaySummary && (
                <div className="mt-3 pt-3 border-t border-zinc-800/80">
                  <span className="block text-xs font-bold text-zinc-400 uppercase tracking-wider mb-1">
                    Berättelse
                  </span>
                  <p className="text-sm text-zinc-300 leading-relaxed">
                    {remoteDetails.storyline}
                  </p>
                </div>
              )}
            </div>
          )}

          {/* 6. Speltid (HowLongToBeat) */}
          {displayTTB && (displayTTB.mainStory || displayTTB.mainExtra || displayTTB.completionist) && (
            <div className="bg-zinc-900/60 border border-zinc-800 p-5 rounded-2xl space-y-3">
              <div className="flex items-center gap-2 text-sm font-bold text-zinc-200 uppercase tracking-wider">
                <Timer className="w-4 h-4 text-red-500" />
                <span>Speltid (HowLongToBeat)</span>
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                {displayTTB.mainStory && (
                  <div className="bg-zinc-950/80 border border-zinc-800/80 rounded-xl p-3 text-center">
                    <span className="text-xs text-zinc-400 font-semibold block mb-1">
                      🎯 Huvudstory
                    </span>
                    <span className="text-xl font-bold text-white font-mono">
                      {displayTTB.mainStory} h
                    </span>
                  </div>
                )}
                {displayTTB.mainExtra && (
                  <div className="bg-zinc-950/80 border border-zinc-800/80 rounded-xl p-3 text-center">
                    <span className="text-xs text-zinc-400 font-semibold block mb-1">
                      ⚔️ Story + Extra
                    </span>
                    <span className="text-xl font-bold text-white font-mono">
                      {displayTTB.mainExtra} h
                    </span>
                  </div>
                )}
                {displayTTB.completionist && (
                  <div className="bg-zinc-950/80 border border-zinc-800/80 rounded-xl p-3 text-center">
                    <span className="text-xs text-zinc-400 font-semibold block mb-1">
                      🏆 100% / Allt
                    </span>
                    <span className="text-xl font-bold text-white font-mono">
                      {displayTTB.completionist} h
                    </span>
                  </div>
                )}
              </div>
            </div>
          )}

          {/* 7. Studio & Utgivare */}
          {(displayDevelopers.length > 0 || displayPublishers.length > 0) && (
            <div className="bg-zinc-900/60 border border-zinc-800 p-5 rounded-2xl space-y-3">
              <div className="flex items-center gap-2 text-sm font-bold text-zinc-200 uppercase tracking-wider">
                <Building2 className="w-4 h-4 text-red-500" />
                <span>Studio & Utgivare</span>
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                {displayDevelopers.length > 0 && (
                  <div className="bg-zinc-950/80 border border-zinc-800/80 rounded-xl p-3.5">
                    <span className="text-xs font-bold text-zinc-400 uppercase tracking-wider block mb-1.5">
                      Utvecklare
                    </span>
                    <div className="flex flex-wrap gap-1.5">
                      {displayDevelopers.map((devName, i) => {
                        const compObj = remoteDetails?.developerCompanies?.find((c) => c.name === devName);
                        return (
                          <button
                            key={i}
                            type="button"
                            onClick={() => onOpenCompany?.(compObj?.id || 0, devName, 'developer')}
                            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-zinc-900 hover:bg-brand-red/20 text-sm font-semibold text-zinc-200 hover:text-white border border-zinc-800 hover:border-brand-red/50 transition group cursor-pointer"
                            title={`Visa alla spel från ${devName}`}
                          >
                            <Building2 className="w-3.5 h-3.5 text-brand-red" />
                            <span>{devName}</span>
                            <span className="text-[11px] text-zinc-500 group-hover:text-brand-red transition">→</span>
                          </button>
                        );
                      })}
                    </div>
                  </div>
                )}
                {displayPublishers.length > 0 && (
                  <div className="bg-zinc-950/80 border border-zinc-800/80 rounded-xl p-3.5">
                    <span className="text-xs font-bold text-zinc-400 uppercase tracking-wider block mb-1.5">
                      Utgivare
                    </span>
                    <div className="flex flex-wrap gap-1.5">
                      {displayPublishers.map((pubName, i) => {
                        const compObj = remoteDetails?.publisherCompanies?.find((c) => c.name === pubName);
                        return (
                          <button
                            key={i}
                            type="button"
                            onClick={() => onOpenCompany?.(compObj?.id || 0, pubName, 'publisher')}
                            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-zinc-900 hover:bg-brand-red/20 text-sm font-semibold text-zinc-200 hover:text-white border border-zinc-800 hover:border-brand-red/50 transition group cursor-pointer"
                            title={`Visa alla spel utgivna av ${pubName}`}
                          >
                            <Building2 className="w-3.5 h-3.5 text-brand-red" />
                            <span>{pubName}</span>
                            <span className="text-[11px] text-zinc-500 group-hover:text-brand-red transition">→</span>
                          </button>
                        );
                      })}
                    </div>
                  </div>
                )}
              </div>
            </div>
          )}

          {/* 8. Spelfakta & Spellägen */}
          {((game.genres && game.genres.length > 0) || (remoteDetails?.gameModes && remoteDetails.gameModes.length > 0) || (remoteDetails?.themes && remoteDetails.themes.length > 0)) && (
            <div className="bg-zinc-900/60 border border-zinc-800 p-5 rounded-2xl space-y-3">
              <div className="flex items-center gap-2 text-sm font-bold text-zinc-200 uppercase tracking-wider">
                <Layers className="w-4 h-4 text-red-500" />
                <span>Fakta & Spellägen</span>
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                {game.genres && game.genres.length > 0 && (
                  <div className="bg-zinc-950/80 border border-zinc-800/80 rounded-xl p-3">
                    <span className="text-xs font-bold text-zinc-400 uppercase tracking-wider block mb-1.5">
                      Genrer
                    </span>
                    <div className="flex flex-wrap gap-1">
                      {game.genres.map((g) => (
                        <span key={g} className="text-xs px-2 py-0.5 rounded bg-zinc-900 text-zinc-300 border border-zinc-800">
                          {g}
                        </span>
                      ))}
                    </div>
                  </div>
                )}
                {remoteDetails?.gameModes && remoteDetails.gameModes.length > 0 && (
                  <div className="bg-zinc-950/80 border border-zinc-800/80 rounded-xl p-3">
                    <span className="text-xs font-bold text-zinc-400 uppercase tracking-wider block mb-1.5">
                      Spellägen
                    </span>
                    <div className="flex flex-wrap gap-1">
                      {remoteDetails.gameModes.map((m) => (
                        <span key={m} className="text-xs px-2 py-0.5 rounded bg-zinc-900 text-zinc-300 border border-zinc-800">
                          {m}
                        </span>
                      ))}
                    </div>
                  </div>
                )}
                {remoteDetails?.themes && remoteDetails.themes.length > 0 && (
                  <div className="bg-zinc-950/80 border border-zinc-800/80 rounded-xl p-3">
                    <span className="text-xs font-bold text-zinc-400 uppercase tracking-wider block mb-1.5">
                      Teman
                    </span>
                    <div className="flex flex-wrap gap-1">
                      {remoteDetails.themes.map((t) => (
                        <span key={t} className="text-xs px-2 py-0.5 rounded bg-zinc-900 text-zinc-300 border border-zinc-800">
                          {t}
                        </span>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            </div>
          )}

          {/* 9. Trailers & Videor */}
          {displayVideos.length > 0 && (
            <div className="bg-zinc-900/60 border border-zinc-800 p-5 rounded-2xl space-y-3">
              <div className="flex items-center gap-2 text-sm font-bold text-zinc-200 uppercase tracking-wider">
                <Video className="w-4 h-4 text-red-500" />
                <span>Trailers & Klipp</span>
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                {displayVideos.slice(0, 2).map((vid) => (
                  <div key={vid.videoId} className="space-y-1.5">
                    <div className="aspect-video w-full rounded-xl overflow-hidden bg-black border border-zinc-800 shadow-md">
                      <iframe
                        src={`https://www.youtube.com/embed/${vid.videoId}`}
                        title={vid.name}
                        allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                        allowFullScreen
                        className="w-full h-full"
                      />
                    </div>
                    <span className="text-xs font-medium text-zinc-400 truncate block">
                      {vid.name}
                    </span>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* 10. Liknande spel */}
          {displaySimilar.length > 0 && (
            <div className="bg-zinc-900/60 border border-zinc-800 p-5 rounded-2xl space-y-3">
              <div className="flex items-center gap-2 text-sm font-bold text-zinc-200 uppercase tracking-wider">
                <Sparkles className="w-4 h-4 text-red-500" />
                <span>Liknande spel</span>
              </div>
              <div className="flex gap-3 overflow-x-auto pb-2 scrollbar-thin scrollbar-thumb-zinc-700">
                {displaySimilar.map((sim) => (
                  <div
                    key={sim.id}
                    className="flex-shrink-0 w-28 sm:w-32 flex flex-col group bg-zinc-950/80 border border-zinc-800 rounded-xl overflow-hidden p-2"
                  >
                    <div className="w-full aspect-[3/4] rounded-lg overflow-hidden bg-zinc-900 mb-2 relative">
                      {sim.coverUrl ? (
                        <img
                          src={sim.coverUrl}
                          alt={sim.title}
                          className="w-full h-full object-cover group-hover:scale-105 transition"
                          loading="lazy"
                        />
                      ) : (
                        <div className="w-full h-full flex items-center justify-center">
                          <Gamepad className="w-6 h-6 text-zinc-600" />
                        </div>
                      )}
                      {sim.rating && (
                        <div className="absolute top-1.5 right-1.5 px-1.5 py-0.5 rounded bg-black/80 text-[10px] font-bold text-amber-400 border border-amber-500/30">
                          {sim.rating}
                        </div>
                      )}
                    </div>
                    <span className="text-xs font-semibold text-zinc-200 line-clamp-1 group-hover:text-red-400 transition">
                      {sim.title}
                    </span>
                    {sim.releaseYear && (
                      <span className="text-[11px] text-zinc-500 font-medium">
                        {sim.releaseYear}
                      </span>
                    )}
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* 11. Samlingar (Collections) */}
          <div className="bg-zinc-900/60 border border-zinc-800 p-5 rounded-2xl space-y-3.5">
            <div className="flex items-center justify-between gap-2">
              <div className="flex items-center gap-2">
                <Bookmark className="w-4 h-4 text-brand-red" />
                <span className="text-xs font-bold text-zinc-300 uppercase tracking-wider">
                  Samlingar
                </span>
              </div>
              <div className="text-xs text-zinc-400">
                {collections.filter(
                  (c) =>
                    c.game_ids?.includes(game.id) ||
                    (game.igdb_id && c.game_ids?.includes(String(game.igdb_id)))
                ).length > 0 ? (
                  <span className="text-emerald-400 font-semibold flex items-center gap-1">
                    <Check className="w-3.5 h-3.5" />
                    I {
                      collections.filter(
                        (c) =>
                          c.game_ids?.includes(game.id) ||
                          (game.igdb_id && c.game_ids?.includes(String(game.igdb_id)))
                      ).length
                    }{' '}
                    {collections.filter(
                      (c) =>
                        c.game_ids?.includes(game.id) ||
                        (game.igdb_id && c.game_ids?.includes(String(game.igdb_id)))
                    ).length === 1
                      ? 'samling'
                      : 'samlingar'}
                  </span>
                ) : (
                  <span className="text-zinc-500">Ingen samling vald</span>
                )}
              </div>
            </div>

            {/* Befintliga samlingar som taggar */}
            {collections.length > 0 ? (
              <div className="flex flex-wrap gap-2 pt-1">
                {collections.map((col) => {
                  const isInCollection = Boolean(
                    col.game_ids?.includes(game.id) ||
                      (game.igdb_id && col.game_ids?.includes(String(game.igdb_id)))
                  );
                  return (
                    <button
                      key={col.id}
                      type="button"
                      onClick={() => onToggleCollection(game.id, col.id)}
                      className={`px-3 py-1.5 rounded-xl text-xs font-semibold border transition flex items-center gap-1.5 cursor-pointer ${
                        isInCollection
                          ? 'bg-brand-red/20 border-brand-red/60 text-white shadow-sm'
                          : 'bg-zinc-950/80 border-zinc-800 text-zinc-400 hover:border-zinc-700 hover:text-zinc-200'
                      }`}
                      title={
                        isInCollection
                          ? `Ta bort från ${col.name}`
                          : `Lägg till i ${col.name}`
                      }
                    >
                      {isInCollection ? (
                        <Check className="w-3.5 h-3.5 text-brand-red" />
                      ) : (
                        <Plus className="w-3.5 h-3.5 text-zinc-500" />
                      )}
                      <span>{col.name}</span>
                    </button>
                  );
                })}
              </div>
            ) : (
              <p className="text-xs text-zinc-500 italic">
                Du har inga samlingar skapade ännu. Skapa en nedan!
              </p>
            )}

            {/* Inline Skapa ny samling */}
            {isCreatingCollection ? (
              <div className="flex items-center gap-2 pt-2 border-t border-zinc-800/80">
                <input
                  type="text"
                  value={newCollectionName}
                  onChange={(e) => setNewCollectionName(e.target.value)}
                  placeholder="Namn på samling (t.ex. 🎃 Halloween, Favoriter)"
                  className="bg-zinc-950 border border-zinc-700 text-zinc-100 px-3 py-1.5 rounded-xl text-xs flex-1 focus:outline-none focus:border-brand-red"
                  autoFocus
                  onKeyDown={(e) => {
                    if (e.key === 'Enter') {
                      e.preventDefault();
                      handleCreateCollection();
                    }
                    if (e.key === 'Escape') {
                      setIsCreatingCollection(false);
                      setNewCollectionName('');
                    }
                  }}
                />
                <button
                  type="button"
                  onClick={handleCreateCollection}
                  disabled={!newCollectionName.trim() || isSubmittingCollection}
                  className="px-3.5 py-1.5 bg-brand-red hover:bg-brand-redPressed text-white rounded-xl text-xs font-semibold disabled:opacity-50 transition cursor-pointer"
                >
                  {isSubmittingCollection ? 'Sparar...' : 'Skapa'}
                </button>
                <button
                  type="button"
                  onClick={() => {
                    setIsCreatingCollection(false);
                    setNewCollectionName('');
                  }}
                  className="px-2.5 py-1.5 bg-zinc-800 text-zinc-400 hover:text-white rounded-xl text-xs transition cursor-pointer"
                >
                  Avbryt
                </button>
              </div>
            ) : (
              <div className="pt-1">
                <button
                  type="button"
                  onClick={() => setIsCreatingCollection(true)}
                  className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-semibold border border-dashed border-zinc-700 text-zinc-400 hover:text-white hover:border-zinc-500 transition cursor-pointer"
                >
                  <Plus className="w-3.5 h-3.5" />
                  <span>Skapa ny samling</span>
                </button>
              </div>
            )}
          </div>

          {/* 12. Notes & Checklist */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
            {/* Notes */}
            <div className="bg-zinc-900/60 border border-zinc-800 p-5 rounded-2xl flex flex-col">
              <label className="block text-xs font-bold text-zinc-400 uppercase tracking-wider mb-2">
                Egna Anteckningar
              </label>
              <textarea
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                placeholder="Skriv dina tankar, minnen eller recension här..."
                rows={4}
                className="w-full flex-1 bg-zinc-950 border border-zinc-800 text-zinc-100 rounded-xl p-3 text-sm focus:outline-none focus:border-red-500 resize-none"
              />
            </div>

            {/* Todo checklist */}
            <div className="bg-zinc-900/60 border border-zinc-800 p-5 rounded-2xl flex flex-col">
              <label className="block text-xs font-bold text-zinc-400 uppercase tracking-wider mb-2">
                Checklista / Mål ({todos.filter((t) => t.isDone).length}/{todos.length})
              </label>

              {/* Todo List */}
              <div className="flex-1 space-y-1.5 max-h-48 overflow-y-auto mb-3 pr-1">
                {todos.length === 0 ? (
                  <p className="text-xs text-zinc-600 italic py-2">
                    Inga mål tillagda än. Lägg till t.ex. "Klara DLC", "Hitta alla collectibles".
                  </p>
                ) : (
                  todos.map((todo) => (
                    <div
                      key={todo.id}
                      className="flex items-center justify-between group p-2 rounded-lg bg-zinc-950/80 border border-zinc-800/80 hover:border-zinc-700"
                    >
                      <button
                        onClick={() => handleToggleTodo(todo.id)}
                        className="flex items-center gap-2.5 text-left flex-1 min-w-0"
                      >
                        <div
                          className={`w-4 h-4 rounded border flex items-center justify-center transition ${
                            todo.isDone
                              ? 'bg-red-600 border-red-600 text-white'
                              : 'border-zinc-600 hover:border-zinc-400'
                          }`}
                        >
                          {todo.isDone && <Check className="w-3 h-3 stroke-[3]" />}
                        </div>
                        <span
                          className={`text-xs truncate ${
                            todo.isDone
                              ? 'line-through text-zinc-500'
                              : 'text-zinc-200 font-medium'
                          }`}
                        >
                          {todo.title}
                        </span>
                      </button>
                      <button
                        onClick={() => handleDeleteTodo(todo.id)}
                        className="opacity-0 group-hover:opacity-100 p-1 text-zinc-500 hover:text-red-400 transition"
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                      </button>
                    </div>
                  ))
                )}
              </div>

              {/* Add Todo input */}
              <form onSubmit={handleAddTodo} className="flex gap-2">
                <input
                  type="text"
                  value={newTodoTitle}
                  onChange={(e) => setNewTodoTitle(e.target.value)}
                  placeholder="Nytt delmål..."
                  className="flex-1 bg-zinc-950 border border-zinc-800 text-zinc-100 rounded-lg px-3 py-1.5 text-xs focus:outline-none focus:border-red-500"
                />
                <button
                  type="submit"
                  disabled={!newTodoTitle.trim()}
                  className="px-3 py-1.5 bg-zinc-800 hover:bg-zinc-700 disabled:opacity-50 text-white text-xs font-semibold rounded-lg transition flex items-center gap-1"
                >
                  <Plus className="w-3.5 h-3.5" />
                  Lägg till
                </button>
              </form>
            </div>
          </div>
        </div>

        {/* Modal Footer */}
        <div className="p-4 sm:p-5 border-t border-zinc-800/80 bg-zinc-950 flex items-center justify-between">
          <div>
            {!showDeleteConfirm ? (
              <button
                onClick={() => setShowDeleteConfirm(true)}
                className="px-3 py-2 text-xs font-semibold text-zinc-500 hover:text-red-400 transition flex items-center gap-1.5"
              >
                <Trash2 className="w-4 h-4" />
                Ta bort från bibliotek
              </button>
            ) : (
              <div className="flex items-center gap-2">
                <span className="text-xs text-red-400 font-semibold">Är du säker?</span>
                <button
                  onClick={handleDelete}
                  className="px-3 py-1.5 bg-red-600 hover:bg-red-700 text-white text-xs font-bold rounded-lg transition"
                >
                  Ja, ta bort
                </button>
                <button
                  onClick={() => setShowDeleteConfirm(false)}
                  className="px-3 py-1.5 bg-zinc-800 hover:bg-zinc-700 text-zinc-300 text-xs font-semibold rounded-lg transition"
                >
                  Avbryt
                </button>
              </div>
            )}
          </div>

          <div className="flex items-center gap-3">
            <button
              onClick={onClose}
              className="px-4 py-2 bg-zinc-900 hover:bg-zinc-800 text-zinc-300 text-sm font-semibold rounded-xl transition"
            >
              Avbryt
            </button>
            <button
              onClick={handleSave}
              disabled={isSaving}
              className="px-5 py-2 bg-red-600 hover:bg-red-500 text-white text-sm font-bold rounded-xl shadow-lg shadow-red-600/20 transition flex items-center gap-1.5"
            >
              {isSaving ? (
                <>Sparar...</>
              ) : (
                <>
                  <Save className="w-4 h-4" />
                  Spara ändringar
                </>
              )}
            </button>
          </div>
        </div>
      </div>

      {/* Lightbox / Fullscreen Image Modal */}
      {activeLightboxImg && (
        <div
          onClick={() => setActiveLightboxImg(null)}
          className="fixed inset-0 z-50 bg-black/95 flex items-center justify-center p-4 cursor-zoom-out animate-in fade-in"
        >
          <button
            onClick={() => setActiveLightboxImg(null)}
            className="absolute top-4 right-4 p-2.5 rounded-full bg-zinc-900/80 text-white hover:bg-zinc-800 transition"
          >
            <X className="w-6 h-6" />
          </button>
          <img
            src={activeLightboxImg}
            alt="Förstorad skärmdump"
            className="max-w-full max-h-[90vh] object-contain rounded-xl shadow-2xl border border-zinc-800"
          />
        </div>
      )}

      {/* Delningskort (Share Card Modal) */}
      <GameShareModal
        isOpen={isShareModalOpen}
        onClose={() => setIsShareModalOpen(false)}
        game={game}
        developer={displayDevelopers[0]}
        releaseDateText={
          liveReleaseDate
            ? new Date(liveReleaseDate * 1000).toLocaleDateString('sv-SE', {
                year: 'numeric',
                month: 'short',
                day: 'numeric',
              })
            : undefined
        }
      />
    </div>
  );
}
