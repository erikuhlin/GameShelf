'use client';

import React, { useState, useEffect, useMemo } from 'react';
import {
  Game,
  GameCollection,
  PlayStatus,
  PLAY_STATUSES,
  GameTodoItem,
  GamePlayType,
  GameStoryProgress,
} from '@/types/game';
import { supabase } from '@/lib/supabase';
import { StatusBadge } from './StatusBadge';
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
  Heart,
  Pencil,
  Info,
  Trophy,
  Map as MapIcon,
  MessageSquare,
  ArrowRight,
  CheckCircle2,
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
  collectionName?: string | null;
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

const STORY_MILESTONES: Array<{ id: GameStoryProgress; label: string; line1: string; line2: string }> = [
  { id: 'justStarted', label: 'Precis börjat', line1: 'Precis', line2: 'börjat' },
  { id: 'midway', label: 'Mitt i det', line1: 'Mitt i', line2: 'det' },
  { id: 'nearEnd', label: 'Närmar mig slutet', line1: 'Närmar mig', line2: 'slutet' },
  { id: 'completed', label: 'Klar', line1: 'Klar', line2: '' },
];

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

  const isOwned = game.is_owned === true;
  const [activeTab, setActiveTab] = useState<'myPlay' | 'facts'>(isOwned ? 'myPlay' : 'facts');

  // Formulär & speldata state
  const [status, setStatus] = useState<PlayStatus>(game.status);
  const [isBacklog, setIsBacklog] = useState<boolean>(game.is_backlog ?? false);
  const [completedYear, setCompletedYear] = useState<number | null>(game.completed_year ?? null);
  const [playTypes, setPlayTypes] = useState<GamePlayType[]>(
    game.play_types && game.play_types.length > 0
      ? game.play_types
      : inferPlayTypes({ title: game.title, genres: game.genres })
  );
  const [rating, setRating] = useState<number | null>(game.rating || null);
  const [notes, setNotes] = useState<string>(game.notes || '');
  const [todos, setTodos] = useState<GameTodoItem[]>(game.todos || []);
  const [newTodoTitle, setNewTodoTitle] = useState('');

  // Spelframsteg state
  const [hoursPlayed, setHoursPlayed] = useState<number>(game.hours_played ?? 0);
  const [storyProgress, setStoryProgress] = useState<GameStoryProgress | null>(
    game.story_progress ?? (game.status === 'completed' ? 'completed' : 'justStarted')
  );
  const [progressNote, setProgressNote] = useState<string>(game.progress_note || '');
  const [noteUpdatedAt, setNoteUpdatedAt] = useState<string | null>(game.note_updated_at || null);

  // Edit states
  const [isEditingHours, setIsEditingHours] = useState(false);
  const [manualHoursInput, setManualHoursInput] = useState('');
  const [isEditingProgressNote, setIsEditingProgressNote] = useState(false);
  const [progressNoteDraft, setProgressNoteDraft] = useState('');

  // Modal / UI states
  const [showMovePicker, setShowMovePicker] = useState(false);
  const [showCollectionPicker, setShowCollectionPicker] = useState(false);
  const [newCollectionName, setNewCollectionName] = useState('');
  const [isCreatingCollection, setIsCreatingCollection] = useState(false);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [isExpandedSummary, setIsExpandedSummary] = useState(false);
  const [isShareModalOpen, setIsShareModalOpen] = useState(false);
  const [activeLightboxImg, setActiveLightboxImg] = useState<string | null>(null);

  // Remote data state
  const [remoteDetails, setRemoteDetails] = useState<RemoteDetails | null>(null);
  const [isLoadingDetails, setIsLoadingDetails] = useState(false);
  const [liveReleaseDate, setLiveReleaseDate] = useState<number | null>(
    game.first_release_date || null
  );

  // Återställ state vid spelbyte
  useEffect(() => {
    if (game) {
      setActiveTab(game.is_owned ? 'myPlay' : 'facts');
      setStatus(game.status);
      setIsBacklog(game.is_backlog ?? false);
      setCompletedYear(game.completed_year ?? null);
      setPlayTypes(
        game.play_types && game.play_types.length > 0
          ? game.play_types
          : inferPlayTypes({ title: game.title, genres: game.genres })
      );
      setRating(game.rating || null);
      setNotes(game.notes || '');
      setTodos(game.todos || []);
      setHoursPlayed(game.hours_played ?? 0);
      setStoryProgress(
        game.story_progress ?? (game.status === 'completed' ? 'completed' : 'justStarted')
      );
      setProgressNote(game.progress_note || '');
      setNoteUpdatedAt(game.note_updated_at || null);
      setLiveReleaseDate(game.first_release_date || null);
      setRemoteDetails(null);
      setIsEditingHours(false);
      setIsEditingProgressNote(false);
      setShowMovePicker(false);
      setShowCollectionPicker(false);
    }
  }, [game?.id]);

  // Hämta utökad IGDB-information
  useEffect(() => {
    if (!game) return;
    let isMounted = true;

    async function loadDetails() {
      setIsLoadingDetails(true);
      try {
        let igdbId: number | null = game?.igdb_id ? Number(game.igdb_id) : null;
        let detailsData: any = null;
        let date: number | null = game?.first_release_date || null;

        if (igdbId) {
          const res = await fetch(`/api/igdb/games/${igdbId}`);
          if (res.ok) {
            const data = await res.json();
            detailsData = data?.game;
            if (detailsData?.first_release_date) {
              date = detailsData.first_release_date;
            }
          }
        }

        if (!detailsData && game?.title) {
          const res = await fetch(`/api/igdb/search?q=${encodeURIComponent(game.title)}`);
          if (res.ok) {
            const data = await res.json();
            const results = data?.results || data?.games || [];
            if (results.length > 0) {
              const best = results[0];
              igdbId = best.id;
              date = best.first_release_date || date;
              const fullRes = await fetch(`/api/igdb/games/${best.id}`);
              if (fullRes.ok) {
                const fullData = await fullRes.json();
                detailsData = fullData?.game;
              }
            }
          }
        }

        if (isMounted && detailsData) {
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
            collectionName: detailsData.collection?.name || null,
            similarGames: detailsData.similarGames || [],
            timeToBeat: detailsData.timeToBeat || null,
          });

          if (date && date !== game?.first_release_date) {
            setLiveReleaseDate(date);
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
  }, [game?.id, game?.igdb_id, game?.title]);

  // Spara ändringar till Supabase och state
  const saveGameUpdates = async (updates: Partial<Game>) => {
    const updatedGame: Game = {
      ...game,
      ...updates,
      updated_at: new Date().toISOString(),
    };

    onUpdateGame(updatedGame);

    try {
      await supabase
        .from('user_games')
        .update(updates)
        .eq('id', game.id);
    } catch (err) {
      console.warn('Failed to persist game updates to Supabase:', err);
    }
  };

  // Statusändring med enkelriktad synk (Status Klar -> storyProgress Klar)
  const handleStatusChange = (newStatus: PlayStatus) => {
    const isPlaying = newStatus === 'playing';
    const isCompleted = newStatus === 'completed';
    const currentYear = new Date().getFullYear();

    setStatus(newStatus);
    if (isPlaying) setIsBacklog(false);

    let nextStoryProgress = storyProgress;
    if (isCompleted) {
      nextStoryProgress = 'completed';
      setStoryProgress('completed');
    }

    const updates: Partial<Game> = {
      status: newStatus,
      is_backlog: isPlaying ? false : isBacklog,
      last_played_date: isPlaying ? game.last_played_date || new Date().toISOString() : game.last_played_date,
      completed_year: isCompleted ? (completedYear || currentYear) : completedYear,
      completed_date: isCompleted ? (game.completed_date || new Date().toISOString()) : game.completed_date,
      story_progress: nextStoryProgress,
    };

    saveGameUpdates(updates);
  };

  // Kvalitativ milstolpeändring (Enkelriktad: ändrar INTE spelets status)
  const handleMilestoneClick = (milestone: GameStoryProgress) => {
    setStoryProgress(milestone);
    saveGameUpdates({ story_progress: milestone });
  };

  // Snabbjustering av speltid (+1h, +5h, -1h)
  const handleAdjustHours = (delta: number) => {
    const nextHours = Math.max(0, Math.round((hoursPlayed + delta) * 10) / 10);
    setHoursPlayed(nextHours);
    saveGameUpdates({
      hours_played: nextHours,
      last_played_date: new Date().toISOString(),
    });
  };

  // Manuell inmatning av speltid (stöd för decimaler som 12.5)
  const handleSaveManualHours = () => {
    const clean = manualHoursInput.replace(',', '.').trim();
    const val = parseFloat(clean);
    if (!isNaN(val) && val >= 0) {
      const rounded = Math.round(val * 10) / 10;
      setHoursPlayed(rounded);
      saveGameUpdates({
        hours_played: rounded,
        last_played_date: new Date().toISOString(),
      });
    }
    setIsEditingHours(false);
  };

  // Spara lägesanteckning (max 140 tecken)
  const handleSaveProgressNote = () => {
    const trimmed = progressNoteDraft.slice(0, 140).trim();
    const nowIso = new Date().toISOString();
    setProgressNote(trimmed);
    setNoteUpdatedAt(nowIso);
    setIsEditingProgressNote(false);
    saveGameUpdates({
      progress_note: trimmed,
      note_updated_at: nowIso,
    });
  };

  // Snabbväljare för Flytta till Biblioteket
  const handleMoveToLibraryChoice = (choice: 'playing' | 'backlog' | 'completed') => {
    const currentYear = new Date().getFullYear();
    const nowIso = new Date().toISOString();

    let newStatus: PlayStatus = 'notStarted';
    let newIsBacklog = false;
    let newCompletedYear: number | null = null;
    let newCompletedDate: string | null = null;
    let newLastPlayed: string | null = null;
    let newStoryProg: GameStoryProgress | null = 'justStarted';

    if (choice === 'playing') {
      newStatus = 'playing';
      newLastPlayed = nowIso;
    } else if (choice === 'backlog') {
      newStatus = 'notStarted';
      newIsBacklog = true;
    } else if (choice === 'completed') {
      newStatus = 'completed';
      newCompletedYear = currentYear;
      newCompletedDate = nowIso;
      newStoryProg = 'completed';
    }

    const updates: Partial<Game> = {
      is_owned: true,
      status: newStatus,
      is_backlog: newIsBacklog,
      completed_year: newCompletedYear,
      completed_date: newCompletedDate,
      last_played_date: newLastPlayed,
      story_progress: newStoryProg,
    };

    saveGameUpdates(updates);
    setShowMovePicker(false);
    setActiveTab('myPlay');
  };

  // Ta bort från biblioteket
  const handleDelete = async () => {
    try {
      await supabase.from('user_games').delete().eq('id', game.id);
      onDeleteGame(game.id);
      onClose();
    } catch (err) {
      console.error('Failed to delete game:', err);
    }
  };

  // Checklista / Todos
  const handleAddTodo = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newTodoTitle.trim()) return;
    const newItem: GameTodoItem = {
      id: crypto.randomUUID(),
      title: newTodoTitle.trim(),
      isDone: false,
    };
    const nextTodos = [...todos, newItem];
    setTodos(nextTodos);
    setNewTodoTitle('');
    saveGameUpdates({ todos: nextTodos });
  };

  const handleToggleTodo = (todoId: string) => {
    const nextTodos = todos.map((t) => (t.id === todoId ? { ...t, isDone: !t.isDone } : t));
    setTodos(nextTodos);
    saveGameUpdates({ todos: nextTodos });
  };

  const handleDeleteTodo = (todoId: string) => {
    const nextTodos = todos.filter((t) => t.id !== todoId);
    setTodos(nextTodos);
    saveGameUpdates({ todos: nextTodos });
  };

  // Spara personliga fritext-anteckningar
  const handleSaveNotes = () => {
    saveGameUpdates({ notes });
  };

  // Hämta endast de samlingar spelet faktiskt tillhör
  const gameBelongsToCollections = useMemo(() => {
    return collections.filter(
      (c) =>
        c.game_ids?.includes(game.id) ||
        (game.igdb_id && c.game_ids?.includes(String(game.igdb_id)))
    );
  }, [collections, game.id, game.igdb_id]);

  // Formatera speltidssiffra
  const hoursDisplay = useMemo(() => {
    if (hoursPlayed === 0) return '0h';
    return hoursPlayed % 1 === 0 ? `${hoursPlayed}h` : `${hoursPlayed.toFixed(1)}h`;
  }, [hoursPlayed]);

  // HLTB data beräkning
  const mainHours = remoteDetails?.timeToBeat?.mainStory || 0;
  const extraHours = remoteDetails?.timeToBeat?.mainExtra || 0;
  const compHours = remoteDetails?.timeToBeat?.completionist || 0;
  const hasHLTB = mainHours > 0 || extraHours > 0 || compHours > 0;
  const maxHLTBHours = Math.max(compHours, extraHours, mainHours);
  const isOverflow = hasHLTB && maxHLTBHours > 0 && hoursPlayed > maxHLTBHours;

  // Formatera relativ tid
  const formatRelativeTime = (isoString: string) => {
    try {
      const diffMs = Date.now() - new Date(isoString).getTime();
      const diffMins = Math.floor(diffMs / 60000);
      if (diffMins < 2) return 'just nu';
      if (diffMins < 60) return `${diffMins} minuter sedan`;
      const diffHours = Math.floor(diffMins / 60);
      if (diffHours < 24) return `${diffHours} timmar sedan`;
      const diffDays = Math.floor(diffHours / 24);
      return `${diffDays} dagar sedan`;
    } catch {
      return '';
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-2 sm:p-4 md:p-6 bg-black/85 backdrop-blur-md overflow-y-auto">
      {/* Lightbox för skärmdumpar */}
      {activeLightboxImg && (
        <div
          className="fixed inset-0 z-60 bg-black/95 flex items-center justify-center p-4 cursor-zoom-out"
          onClick={() => setActiveLightboxImg(null)}
        >
          <img
            src={activeLightboxImg}
            alt="Fullscreen preview"
            className="max-w-full max-h-[90vh] object-contain rounded-xl shadow-2xl border border-zinc-800"
          />
        </div>
      )}

      {/* Flytta till Biblioteket Snabbväljare Modal */}
      {showMovePicker && (
        <div className="fixed inset-0 z-60 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm">
          <div className="bg-zinc-900 border border-zinc-800 rounded-2xl max-w-sm w-full p-5 space-y-4 shadow-2xl animate-in fade-in zoom-in-95 duration-150">
            <div>
              <h3 className="text-base font-bold text-white">Flytta till Biblioteket</h3>
              <p className="text-xs text-zinc-400 mt-1">
                Välj hur du vill lägga till <strong>{game.title}</strong>:
              </p>
            </div>
            <div className="space-y-2">
              <button
                type="button"
                onClick={() => handleMoveToLibraryChoice('playing')}
                className="w-full flex items-center justify-between px-4 py-3 bg-zinc-800/80 hover:bg-zinc-800 text-left rounded-xl transition border border-zinc-700/60 group cursor-pointer"
              >
                <div>
                  <div className="text-sm font-semibold text-white group-hover:text-brand-red flex items-center gap-2">
                    🎮 Börja spela nu
                  </div>
                  <div className="text-xs text-zinc-400 mt-0.5">Sätter status till Spelar nu</div>
                </div>
                <ChevronRight className="w-4 h-4 text-zinc-500 group-hover:text-brand-red transition" />
              </button>

              <button
                type="button"
                onClick={() => handleMoveToLibraryChoice('backlog')}
                className="w-full flex items-center justify-between px-4 py-3 bg-zinc-800/80 hover:bg-zinc-800 text-left rounded-xl transition border border-zinc-700/60 group cursor-pointer"
              >
                <div>
                  <div className="text-sm font-semibold text-white group-hover:text-brand-red flex items-center gap-2">
                    📦 Lägg i Backlog
                  </div>
                  <div className="text-xs text-zinc-400 mt-0.5">Sätter status till Ej påbörjat</div>
                </div>
                <ChevronRight className="w-4 h-4 text-zinc-500 group-hover:text-brand-red transition" />
              </button>

              <button
                type="button"
                onClick={() => handleMoveToLibraryChoice('completed')}
                className="w-full flex items-center justify-between px-4 py-3 bg-zinc-800/80 hover:bg-zinc-800 text-left rounded-xl transition border border-zinc-700/60 group cursor-pointer"
              >
                <div>
                  <div className="text-sm font-semibold text-white group-hover:text-emerald-400 flex items-center gap-2">
                    🏆 Har redan klarat
                  </div>
                  <div className="text-xs text-zinc-400 mt-0.5">Sätter status och milstolpe till Klar</div>
                </div>
                <ChevronRight className="w-4 h-4 text-zinc-500 group-hover:text-emerald-400 transition" />
              </button>
            </div>
            <button
              type="button"
              onClick={() => setShowMovePicker(false)}
              className="w-full py-2 text-xs font-semibold text-zinc-400 hover:text-white transition cursor-pointer"
            >
              Avbryt
            </button>
          </div>
        </div>
      )}

      {/* Samlingshanterare Modal */}
      {showCollectionPicker && (
        <div className="fixed inset-0 z-60 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm">
          <div className="bg-zinc-900 border border-zinc-800 rounded-2xl max-w-md w-full p-5 space-y-4 shadow-2xl animate-in fade-in zoom-in-95 duration-150">
            <div className="flex items-center justify-between border-b border-zinc-800 pb-3">
              <div className="flex items-center gap-2">
                <Bookmark className="w-4 h-4 text-brand-red" />
                <h3 className="text-base font-bold text-white">Hantera samlingar</h3>
              </div>
              <button
                type="button"
                onClick={() => setShowCollectionPicker(false)}
                className="text-zinc-400 hover:text-white cursor-pointer"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <div className="space-y-1.5 max-h-60 overflow-y-auto pr-1">
              {collections.length === 0 ? (
                <p className="text-xs text-zinc-400 py-3 text-center">
                  Du har inte skapat några samlingar än.
                </p>
              ) : (
                collections.map((col) => {
                  const isChecked = Boolean(
                    col.game_ids?.includes(game.id) ||
                      (game.igdb_id && col.game_ids?.includes(String(game.igdb_id)))
                  );
                  return (
                    <button
                      key={col.id}
                      type="button"
                      onClick={() => onToggleCollection(game.id, col.id)}
                      className={`w-full flex items-center justify-between px-3.5 py-2.5 rounded-xl text-sm font-medium transition cursor-pointer ${
                        isChecked
                          ? 'bg-brand-red/15 text-white border border-brand-red/40'
                          : 'bg-zinc-800/60 text-zinc-300 hover:bg-zinc-800 border border-transparent'
                      }`}
                    >
                      <span className="truncate">{col.name}</span>
                      {isChecked ? (
                        <Check className="w-4 h-4 text-brand-red flex-shrink-0" />
                      ) : (
                        <Plus className="w-4 h-4 text-zinc-500 flex-shrink-0" />
                      )}
                    </button>
                  );
                })
              )}
            </div>

            {/* Skapa ny samling inline */}
            <div className="pt-2 border-t border-zinc-800/80">
              {isCreatingCollection ? (
                <div className="space-y-2">
                  <input
                    type="text"
                    value={newCollectionName}
                    onChange={(e) => setNewCollectionName(e.target.value)}
                    placeholder="Namn på samling (t.ex. Nostalgi, Favoriter)..."
                    className="w-full bg-zinc-950 border border-zinc-700 rounded-xl px-3 py-2 text-xs text-white placeholder-zinc-500 focus:outline-none focus:border-brand-red"
                    autoFocus
                  />
                  <div className="flex gap-2">
                    <button
                      type="button"
                      onClick={async () => {
                        if (!newCollectionName.trim()) return;
                        if (onCreateCollection) {
                          await onCreateCollection(newCollectionName.trim(), game.id);
                        }
                        setNewCollectionName('');
                        setIsCreatingCollection(false);
                      }}
                      className="px-3 py-1.5 bg-brand-red hover:bg-red-700 text-white rounded-lg text-xs font-bold transition cursor-pointer"
                    >
                      Skapa & Lägg till
                    </button>
                    <button
                      type="button"
                      onClick={() => setIsCreatingCollection(false)}
                      className="px-3 py-1.5 bg-zinc-800 hover:bg-zinc-700 text-zinc-400 rounded-lg text-xs transition cursor-pointer"
                    >
                      Avbryt
                    </button>
                  </div>
                </div>
              ) : (
                <button
                  type="button"
                  onClick={() => setIsCreatingCollection(true)}
                  className="text-xs text-zinc-400 hover:text-brand-red flex items-center gap-1.5 font-semibold transition cursor-pointer"
                >
                  <Plus className="w-3.5 h-3.5" />
                  <span>Skapa ny samling...</span>
                </button>
              )}
            </div>

            <button
              type="button"
              onClick={() => setShowCollectionPicker(false)}
              className="w-full py-2 bg-zinc-800 hover:bg-zinc-700 text-white text-xs font-bold rounded-xl transition cursor-pointer"
            >
              Klar
            </button>
          </div>
        </div>
      )}

      {/* Huvudmodal */}
      <div className="relative bg-zinc-950 border border-zinc-800/90 rounded-2xl md:rounded-3xl max-w-4xl w-full max-h-[92vh] overflow-y-auto shadow-2xl flex flex-col">
        {/* Top bar */}
        <div className="sticky top-0 z-30 flex items-center justify-between px-4 sm:px-6 py-3.5 bg-zinc-950/90 backdrop-blur-md border-b border-zinc-800/80">
          <button
            type="button"
            onClick={onClose}
            className="p-1.5 rounded-full hover:bg-zinc-800/80 text-zinc-400 hover:text-white transition cursor-pointer"
            title="Stäng"
          >
            <X className="w-5 h-5" />
          </button>

          <div className="flex items-center gap-2">
            {isOwned && onToggleTargetGoal && (
              <button
                type="button"
                onClick={() => onToggleTargetGoal(game.id)}
                className={`p-2 rounded-full transition cursor-pointer ${
                  isTargetGoal
                    ? 'bg-amber-500/20 text-amber-400 border border-amber-500/40'
                    : 'text-zinc-400 hover:text-white hover:bg-zinc-800'
                }`}
                title={isTargetGoal ? 'Aktivt fokusmål' : 'Sätt som fokusmål'}
              >
                <Target className="w-4 h-4" />
              </button>
            )}

            <button
              type="button"
              onClick={() => setIsShareModalOpen(true)}
              className="p-2 rounded-full text-zinc-400 hover:text-white hover:bg-zinc-800 transition cursor-pointer"
              title="Dela spelkort"
            >
              <Share2 className="w-4 h-4" />
            </button>
          </div>
        </div>

        {/* Modal Innehåll */}
        <div className="p-4 sm:p-6 space-y-6">
          {/* Header Info: Omslag + Titel + Metadata */}
          <div className="flex flex-col sm:flex-row gap-5">
            {/* Omslag */}
            <div className="w-28 sm:w-36 flex-shrink-0 mx-auto sm:mx-0">
              <div
                onClick={() => game.cover_url && setActiveLightboxImg(game.cover_url)}
                className="aspect-[3/4] rounded-xl overflow-hidden bg-zinc-900 border border-zinc-800 shadow-lg cursor-pointer group relative"
              >
                {game.cover_url ? (
                  <img
                    src={game.cover_url}
                    alt={game.title}
                    className="w-full h-full object-cover group-hover:scale-105 transition duration-300"
                  />
                ) : (
                  <div className="w-full h-full flex flex-col items-center justify-center p-2 text-zinc-600">
                    <Gamepad className="w-8 h-8 mb-1" />
                    <span className="text-[10px] text-center font-medium">Inget omslag</span>
                  </div>
                )}
              </div>
            </div>

            {/* Titel, betyg & tags */}
            <div className="flex-1 min-w-0 space-y-2.5 text-center sm:text-left">
              <div>
                <h1 className="text-xl sm:text-2xl md:text-3xl font-black text-white tracking-tight leading-tight">
                  {game.title}
                </h1>
                <div className="flex flex-wrap items-center justify-center sm:justify-start gap-2 mt-1.5 text-xs text-zinc-400">
                  {game.release_year && (
                    <span className="font-semibold text-zinc-200">{game.release_year}</span>
                  )}
                  {game.developers && game.developers.length > 0 && (
                    <>
                      <span>·</span>
                      <span className="text-zinc-300">{game.developers.join(', ')}</span>
                    </>
                  )}
                </div>
              </div>

              {/* Betygsbrickor */}
              <div className="flex flex-wrap items-center justify-center sm:justify-start gap-2">
                {game.igdb_rating ? (
                  <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-zinc-900 border border-zinc-800 text-xs font-bold">
                    <span className="text-amber-400">★</span>
                    <span className="text-zinc-200">{Math.round(game.igdb_rating * 10)}%</span>
                    <span className="text-zinc-500 font-normal">Spelare</span>
                  </div>
                ) : null}

                {game.rating ? (
                  <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-zinc-900 border border-amber-500/30 text-xs font-bold text-amber-400">
                    <span>★</span>
                    <span>{game.rating}/10</span>
                    <span className="text-zinc-500 font-normal">Ditt betyg</span>
                  </div>
                ) : null}
              </div>

              {/* Genrer & Singleplayer */}
              <div className="flex flex-wrap items-center justify-center sm:justify-start gap-1.5 pt-1">
                {game.genres?.map((g) => (
                  <span
                    key={g}
                    className="px-2 py-0.5 rounded-md bg-zinc-900 border border-zinc-800/80 text-[11px] font-medium text-zinc-400"
                  >
                    {g}
                  </span>
                ))}
                {playTypes?.map((pt) => (
                  <span
                    key={pt}
                    className="px-2 py-0.5 rounded-md bg-brand-red/10 border border-brand-red/25 text-[11px] font-medium text-brand-red"
                  >
                    👤 {pt === 'singlePlayer' ? 'Single player' : pt === 'multiplayer' ? 'Multiplayer' : pt}
                  </span>
                ))}
              </div>
            </div>
          </div>

          {/* ===== STATE-BASERADE HANDLINGSRADER ===== */}

          {/* 1. Önskelista state: Status-strip + Flytta till Biblioteket */}
          {!isOwned && (
            <div className="space-y-3">
              <div className="flex items-center justify-between px-4 py-3 bg-red-950/20 border border-red-900/40 rounded-xl text-xs">
                <div className="flex items-center gap-2 text-brand-red font-semibold">
                  <Heart className="w-4 h-4 fill-current" />
                  <span>På önskelistan</span>
                </div>
                {game.created_at && (
                  <span className="text-zinc-400 text-[11px]">
                    Tillagd {new Date(game.created_at).toLocaleDateString('sv-SE')}
                  </span>
                )}
              </div>

              <div className="flex gap-2">
                <button
                  type="button"
                  onClick={() => setShowMovePicker(true)}
                  className="flex-1 py-3 px-4 bg-brand-red hover:bg-red-700 text-white font-bold text-sm rounded-xl transition shadow-lg shadow-brand-red/20 flex items-center justify-center gap-2 cursor-pointer"
                >
                  <ArrowRight className="w-4 h-4" />
                  <span>Flytta till Biblioteket</span>
                </button>

                <button
                  type="button"
                  onClick={() => handleDelete()}
                  className="p-3 bg-zinc-900 hover:bg-zinc-800 text-zinc-400 hover:text-brand-red border border-zinc-800 rounded-xl transition cursor-pointer"
                  title="Ta bort från önskelistan"
                >
                  <Heart className="w-5 h-5 fill-current text-brand-red" />
                </button>
              </div>
            </div>
          )}

          {/* 2. I biblioteket: Snabbkontroller + Flikar */}
          {isOwned && (
            <div className="space-y-4">
              {/* Snabbkontroller (Status, Plattform, Betyg) */}
              <div className="flex flex-wrap items-center gap-2.5 p-3 bg-zinc-900/80 border border-zinc-800/80 rounded-xl">
                {/* Status selector */}
                <div className="flex items-center gap-2">
                  <span className="text-xs text-zinc-400 font-medium">Status:</span>
                  <select
                    value={status}
                    onChange={(e) => handleStatusChange(e.target.value as PlayStatus)}
                    className="bg-zinc-950 border border-zinc-700 rounded-lg px-2.5 py-1.5 text-xs font-bold text-white focus:outline-none focus:border-brand-red cursor-pointer"
                  >
                    <option value="playing">🎮 Spelar nu</option>
                    <option value="notStarted">📦 Backlog / Ej påbörjat</option>
                    <option value="paused">⏸️ Pausat</option>
                    <option value="completed">🏆 Klar</option>
                    <option value="abandoned">❌ Avbrutet</option>
                  </select>
                </div>

                {/* Betyg */}
                <div className="flex items-center gap-1.5 ml-auto">
                  <span className="text-xs text-zinc-400 font-medium">Betyg:</span>
                  <select
                    value={rating || ''}
                    onChange={(e) => {
                      const val = e.target.value ? Number(e.target.value) : null;
                      setRating(val);
                      saveGameUpdates({ rating: val });
                    }}
                    className="bg-zinc-950 border border-zinc-700 rounded-lg px-2 py-1.5 text-xs font-bold text-amber-400 focus:outline-none focus:border-brand-red cursor-pointer"
                  >
                    <option value="">Ej betygsatt</option>
                    {[10, 9, 8, 7, 6, 5, 4, 3, 2, 1].map((r) => (
                      <option key={r} value={r}>
                        ★ {r}/10
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              {/* Flikväljare (Mitt Spelande ⇄ Spelfakta & Info) */}
              <div className="flex border-b border-zinc-800/90 gap-6 text-sm font-bold">
                <button
                  type="button"
                  onClick={() => setActiveTab('myPlay')}
                  className={`pb-2.5 transition relative cursor-pointer ${
                    activeTab === 'myPlay'
                      ? 'text-white'
                      : 'text-zinc-500 hover:text-zinc-300'
                  }`}
                >
                  <span>Mitt Spelande</span>
                  {activeTab === 'myPlay' && (
                    <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-brand-red rounded-full" />
                  )}
                </button>

                <button
                  type="button"
                  onClick={() => setActiveTab('facts')}
                  className={`pb-2.5 transition relative cursor-pointer ${
                    activeTab === 'facts'
                      ? 'text-white'
                      : 'text-zinc-500 hover:text-zinc-300'
                  }`}
                >
                  <span>Spelfakta & Info</span>
                  {activeTab === 'facts' && (
                    <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-brand-red rounded-full" />
                  )}
                </button>
              </div>
            </div>
          )}

          {/* ===== FLIK 1: MITT SPELANDE ===== */}
          {isOwned && activeTab === 'myPlay' && (
            <div className="space-y-6">
              {/* Sektion: Spelframsteg */}
              <div className="bg-zinc-900/70 border border-zinc-800/80 rounded-2xl p-4 sm:p-5 space-y-5">
                <div className="flex items-center justify-between border-b border-zinc-800/60 pb-3">
                  <div className="flex items-center gap-2">
                    <Timer className="w-4 h-4 text-brand-red" />
                    <span className="text-xs font-bold text-zinc-300 uppercase tracking-wider">
                      Spelframsteg
                    </span>
                  </div>
                </div>

                {/* 1. Tidsangivelse */}
                {isEditingHours ? (
                  <div className="flex items-center gap-3">
                    <input
                      type="text"
                      inputMode="decimal"
                      value={manualHoursInput}
                      onChange={(e) => setManualHoursInput(e.target.value)}
                      placeholder="0"
                      className="w-24 bg-zinc-950 border border-zinc-700 rounded-xl px-3 py-1.5 text-base font-bold text-white focus:outline-none focus:border-brand-red"
                      autoFocus
                      onKeyDown={(e) => e.key === 'Enter' && handleSaveManualHours()}
                    />
                    <span className="text-sm text-zinc-400">timmar</span>
                    <button
                      type="button"
                      onClick={handleSaveManualHours}
                      className="px-3.5 py-1.5 bg-brand-red hover:bg-red-700 text-white text-xs font-bold rounded-xl transition cursor-pointer"
                    >
                      Klar
                    </button>
                    <button
                      type="button"
                      onClick={() => setIsEditingHours(false)}
                      className="text-xs text-zinc-400 hover:text-white cursor-pointer"
                    >
                      Avbryt
                    </button>
                  </div>
                ) : hoursPlayed === 0 ? (
                  /* Tomt läge: Logga tid knapp */
                  <div className="flex items-center justify-between">
                    <div>
                      <div className="text-xs font-semibold text-zinc-400">Speltid</div>
                      <div className="text-sm text-zinc-500 mt-0.5">Ingen tid loggad</div>
                    </div>
                    <button
                      type="button"
                      onClick={() => {
                        setManualHoursInput('');
                        setIsEditingHours(true);
                      }}
                      className="px-4 py-2 bg-brand-red hover:bg-red-700 text-white text-xs font-bold rounded-xl transition flex items-center gap-1.5 shadow-md shadow-brand-red/15 cursor-pointer"
                    >
                      <Plus className="w-3.5 h-3.5" />
                      <span>Logga tid</span>
                    </button>
                  </div>
                ) : (
                  /* Aktivt läge: Siffra med tap-redigering och snabbknappar */
                  <div className="flex items-center justify-between flex-wrap gap-3">
                    <button
                      type="button"
                      onClick={() => {
                        setManualHoursInput(String(hoursPlayed));
                        setIsEditingHours(true);
                      }}
                      className="flex items-baseline gap-2 group text-left cursor-pointer"
                      title="Klicka för att redigera timmar"
                    >
                      <span className="text-2xl sm:text-3xl font-black text-white group-hover:text-brand-red transition">
                        {hoursDisplay} spelade
                      </span>
                      <Pencil className="w-3.5 h-3.5 text-zinc-500 group-hover:text-brand-red transition" />
                    </button>

                    <div className="flex items-center gap-1.5">
                      <button
                        type="button"
                        onClick={() => handleAdjustHours(-1)}
                        className="px-2.5 py-1.5 bg-zinc-800/80 hover:bg-zinc-800 text-zinc-400 hover:text-white text-xs font-bold rounded-lg border border-zinc-700/60 transition cursor-pointer"
                      >
                        -1h
                      </button>
                      <button
                        type="button"
                        onClick={() => handleAdjustHours(1)}
                        className="px-2.5 py-1.5 bg-zinc-800/80 hover:bg-zinc-800 text-zinc-200 hover:text-white text-xs font-bold rounded-lg border border-zinc-700/60 transition cursor-pointer"
                      >
                        +1h
                      </button>
                      <button
                        type="button"
                        onClick={() => handleAdjustHours(5)}
                        className="px-2.5 py-1.5 bg-brand-red/15 hover:bg-brand-red/25 text-brand-red text-xs font-bold rounded-lg border border-brand-red/30 transition cursor-pointer"
                      >
                        +5h
                      </button>
                    </div>
                  </div>
                )}

                {/* 2. HLTB-referensband */}
                {hasHLTB && (
                  <div className="space-y-3 pt-2">
                    <div className="text-[11px] font-bold text-zinc-500 tracking-wider">
                      REFERENS · HOWLONGTOBEAT
                    </div>
                    <div className="space-y-3">
                      {mainHours > 0 && (
                        <div className="space-y-1.5">
                          <div className="flex items-center justify-between text-xs">
                            <div className="flex items-center gap-2 text-zinc-300 font-medium">
                              <span className="w-6 h-6 rounded-md bg-zinc-800 flex items-center justify-center text-xs">
                                📖
                              </span>
                              <span>Main Story</span>
                            </div>
                            <span className="font-bold text-white">{mainHours} tim</span>
                          </div>
                          {/* Progress bar */}
                          <div className="relative w-full h-1.5 bg-zinc-800 rounded-full overflow-hidden">
                            <div
                              className={`h-full transition-all duration-300 rounded-full ${
                                hoursPlayed >= mainHours ? 'bg-emerald-500' : 'bg-brand-red'
                              }`}
                              style={{
                                width: `${Math.min(100, Math.max(0, (hoursPlayed / mainHours) * 100))}%`,
                              }}
                            />
                          </div>
                        </div>
                      )}

                      {extraHours > 0 && (
                        <div className="space-y-1.5">
                          <div className="flex items-center justify-between text-xs">
                            <div className="flex items-center gap-2 text-zinc-300 font-medium">
                              <span className="w-6 h-6 rounded-md bg-zinc-800 flex items-center justify-center text-xs">
                                ➕
                              </span>
                              <span>Main + Extra</span>
                            </div>
                            <span className="font-bold text-white">{extraHours} tim</span>
                          </div>
                          <div className="relative w-full h-1.5 bg-zinc-800 rounded-full overflow-hidden">
                            <div
                              className={`h-full transition-all duration-300 rounded-full ${
                                hoursPlayed >= extraHours ? 'bg-emerald-500' : 'bg-brand-red'
                              }`}
                              style={{
                                width: `${Math.min(100, Math.max(0, (hoursPlayed / extraHours) * 100))}%`,
                              }}
                            />
                          </div>
                        </div>
                      )}

                      {compHours > 0 && (
                        <div className="space-y-1.5">
                          <div className="flex items-center justify-between text-xs">
                            <div className="flex items-center gap-2 text-zinc-300 font-medium">
                              <span className="w-6 h-6 rounded-md bg-zinc-800 flex items-center justify-center text-xs">
                                🏆
                              </span>
                              <span>Completionist</span>
                            </div>
                            <span className="font-bold text-white">{compHours} tim</span>
                          </div>
                          <div className="relative w-full h-1.5 bg-zinc-800 rounded-full overflow-hidden">
                            <div
                              className={`h-full transition-all duration-300 rounded-full ${
                                hoursPlayed >= compHours ? 'bg-emerald-500' : 'bg-brand-red'
                              }`}
                              style={{
                                width: `${Math.min(100, Math.max(0, (hoursPlayed / compHours) * 100))}%`,
                              }}
                            />
                          </div>
                        </div>
                      )}
                    </div>

                    {isOverflow && (
                      <div className="flex items-center gap-1.5 text-[11px] text-zinc-400 pt-1">
                        <Info className="w-3.5 h-3.5 text-zinc-500" />
                        <span>Du har spelat mer än genomsnittet för 100%-genomgång</span>
                      </div>
                    )}
                  </div>
                )}

                {/* 3. Kvalitativt läge ("Var är du i spelet?") */}
                <div className="space-y-2 pt-1">
                  <div className="text-xs font-bold text-zinc-400">Var är du i spelet?</div>
                  <div className="grid grid-cols-4 gap-2">
                    {STORY_MILESTONES.map((m) => {
                      const isSelected = storyProgress === m.id;
                      return (
                        <button
                          key={m.id}
                          type="button"
                          onClick={() => handleMilestoneClick(m.id)}
                          className={`h-11 rounded-xl text-[11.5px] font-semibold flex flex-col items-center justify-center leading-tight transition cursor-pointer border ${
                            isSelected
                              ? m.id === 'completed'
                                ? 'bg-emerald-600 text-white border-emerald-500 shadow-md shadow-emerald-950'
                                : 'bg-brand-red text-white border-brand-red shadow-md shadow-red-950'
                              : 'bg-zinc-800/80 text-zinc-300 hover:bg-zinc-800 border-zinc-700/50'
                          }`}
                        >
                          <span>{m.line1}</span>
                          {m.line2 && <span>{m.line2}</span>}
                        </button>
                      );
                    })}
                  </div>
                </div>

                {/* 4. Lägesanteckning */}
                <div className="space-y-2 pt-1">
                  <div className="flex items-center justify-between text-xs font-bold text-zinc-400">
                    <span>Lägesanteckning</span>
                    {noteUpdatedAt && (
                      <span className="text-[11px] font-normal text-zinc-500">
                        Uppdaterad {formatRelativeTime(noteUpdatedAt)}
                      </span>
                    )}
                  </div>

                  {isEditingProgressNote ? (
                    <div className="space-y-2">
                      <textarea
                        value={progressNoteDraft}
                        onChange={(e) => setProgressNoteDraft(e.target.value.slice(0, 140))}
                        placeholder="T.ex. På väg till Skellige, nivå 24..."
                        rows={3}
                        className="w-full bg-zinc-950 border border-zinc-700 rounded-xl p-3 text-xs text-white placeholder-zinc-500 focus:outline-none focus:border-brand-red"
                        autoFocus
                      />
                      <div className="flex items-center justify-between">
                        <span className="text-[11px] text-zinc-500">
                          {progressNoteDraft.length}/140
                        </span>
                        <div className="flex gap-2">
                          <button
                            type="button"
                            onClick={() => setIsEditingProgressNote(false)}
                            className="px-3 py-1.5 bg-zinc-800 hover:bg-zinc-700 text-zinc-400 rounded-lg text-xs transition cursor-pointer"
                          >
                            Avbryt
                          </button>
                          <button
                            type="button"
                            onClick={handleSaveProgressNote}
                            className="px-3.5 py-1.5 bg-brand-red hover:bg-red-700 text-white text-xs font-bold rounded-lg transition cursor-pointer"
                          >
                            Spara
                          </button>
                        </div>
                      </div>
                    </div>
                  ) : (
                    <button
                      type="button"
                      onClick={() => {
                        setProgressNoteDraft(progressNote);
                        setIsEditingProgressNote(true);
                      }}
                      className="w-full p-3 bg-zinc-950/80 hover:bg-zinc-900 border border-zinc-800/80 hover:border-zinc-700 rounded-xl text-left transition flex items-start gap-2.5 cursor-pointer group"
                    >
                      <Pencil className="w-3.5 h-3.5 text-brand-red flex-shrink-0 mt-0.5" />
                      {progressNote ? (
                        <span className="text-xs text-zinc-200">{progressNote}</span>
                      ) : (
                        <span className="text-xs text-zinc-500 group-hover:text-zinc-400">
                          Lägg till en lägesanteckning (t.ex. kapitel, quest, mål)...
                        </span>
                      )}
                    </button>
                  )}
                </div>
              </div>

              {/* Sektion: Samlingar (Visar ENDAST samlingar spelet faktiskt tillhör!) */}
              <div className="bg-zinc-900/70 border border-zinc-800/80 rounded-2xl p-4 sm:p-5 space-y-3">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <Bookmark className="w-4 h-4 text-brand-red" />
                    <span className="text-xs font-bold text-zinc-300 uppercase tracking-wider">
                      Samlingar
                    </span>
                  </div>

                  <button
                    type="button"
                    onClick={() => setShowCollectionPicker(true)}
                    className="text-xs font-bold text-brand-red hover:text-red-400 flex items-center gap-1 transition cursor-pointer"
                  >
                    <Plus className="w-3.5 h-3.5" />
                    <span>{gameBelongsToCollections.length > 0 ? 'Hantera' : 'Lägg till'}</span>
                  </button>
                </div>

                {gameBelongsToCollections.length === 0 ? (
                  <div className="flex items-center justify-between py-2 text-xs text-zinc-500">
                    <span>Inga samlingar valda</span>
                    <button
                      type="button"
                      onClick={() => setShowCollectionPicker(true)}
                      className="text-zinc-400 hover:text-white underline text-xs cursor-pointer"
                    >
                      Välj samling
                    </button>
                  </div>
                ) : (
                  <div className="flex flex-wrap gap-2 pt-1">
                    {gameBelongsToCollections.map((col) => (
                      <span
                        key={col.id}
                        className="px-3 py-1.5 rounded-xl text-xs font-semibold bg-zinc-800/90 border border-zinc-700 text-zinc-200 flex items-center gap-1.5"
                      >
                        <Bookmark className="w-3 h-3 text-brand-red" />
                        <span>{col.name}</span>
                      </span>
                    ))}
                  </div>
                )}
              </div>

              {/* Sektion: Anteckningar & Checklista */}
              <div className="bg-zinc-900/70 border border-zinc-800/80 rounded-2xl p-4 sm:p-5 space-y-4">
                <div className="flex items-center justify-between border-b border-zinc-800/60 pb-3">
                  <div className="flex items-center gap-2">
                    <BookOpen className="w-4 h-4 text-brand-red" />
                    <span className="text-xs font-bold text-zinc-300 uppercase tracking-wider">
                      Anteckningar & Checklista
                    </span>
                  </div>
                </div>

                {/* Anteckningar */}
                <div className="space-y-1.5">
                  <label className="text-xs font-medium text-zinc-400">Egna anteckningar</label>
                  <textarea
                    value={notes}
                    onChange={(e) => setNotes(e.target.value)}
                    onBlur={handleSaveNotes}
                    placeholder="Skriv dina tankar om spelet, builds, minnen..."
                    rows={3}
                    className="w-full bg-zinc-950 border border-zinc-800 rounded-xl p-3 text-xs text-white placeholder-zinc-600 focus:outline-none focus:border-brand-red"
                  />
                </div>

                {/* Checklista */}
                <div className="space-y-2 pt-2 border-t border-zinc-800/60">
                  <label className="text-xs font-medium text-zinc-400">Checklista / Mål</label>
                  <form onSubmit={handleAddTodo} className="flex gap-2">
                    <input
                      type="text"
                      value={newTodoTitle}
                      onChange={(e) => setNewTodoTitle(e.target.value)}
                      placeholder="Ny punkt (t.ex. Hitta alla shrine-kistor)..."
                      className="flex-1 bg-zinc-950 border border-zinc-800 rounded-xl px-3 py-1.5 text-xs text-white placeholder-zinc-600 focus:outline-none focus:border-brand-red"
                    />
                    <button
                      type="submit"
                      className="px-3 py-1.5 bg-zinc-800 hover:bg-zinc-700 text-white rounded-xl text-xs font-bold transition cursor-pointer"
                    >
                      Lägg till
                    </button>
                  </form>

                  {todos.length > 0 && (
                    <div className="space-y-1.5 pt-1">
                      {todos.map((t) => (
                        <div
                          key={t.id}
                          className="flex items-center justify-between px-3 py-2 bg-zinc-950/60 border border-zinc-800/80 rounded-xl text-xs"
                        >
                          <button
                            type="button"
                            onClick={() => handleToggleTodo(t.id)}
                            className="flex items-center gap-2 text-left cursor-pointer flex-1 mr-2"
                          >
                            <span
                              className={`w-4 h-4 rounded flex items-center justify-center border transition ${
                                t.isDone
                                  ? 'bg-emerald-500 border-emerald-500 text-black'
                                  : 'border-zinc-700 bg-zinc-900'
                              }`}
                            >
                              {t.isDone && <Check className="w-3 h-3" />}
                            </span>
                            <span
                              className={
                                t.isDone ? 'line-through text-zinc-500' : 'text-zinc-200 font-medium'
                              }
                            >
                              {t.title}
                            </span>
                          </button>
                          <button
                            type="button"
                            onClick={() => handleDeleteTodo(t.id)}
                            className="text-zinc-600 hover:text-red-400 p-1 cursor-pointer"
                          >
                            <X className="w-3.5 h-3.5" />
                          </button>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              </div>

              {/* Sektion: Ta bort spel */}
              <div className="pt-2">
                {showDeleteConfirm ? (
                  <div className="p-4 bg-red-950/30 border border-red-900/50 rounded-2xl space-y-3">
                    <p className="text-xs text-red-200">
                      Är du säker på att du vill ta bort <strong>{game.title}</strong> från ditt
                      bibliotek?
                    </p>
                    <div className="flex gap-2">
                      <button
                        type="button"
                        onClick={handleDelete}
                        className="px-4 py-2 bg-red-600 hover:bg-red-700 text-white font-bold text-xs rounded-xl transition cursor-pointer"
                      >
                        Ja, ta bort spelet
                      </button>
                      <button
                        type="button"
                        onClick={() => setShowDeleteConfirm(false)}
                        className="px-4 py-2 bg-zinc-800 hover:bg-zinc-700 text-zinc-300 text-xs rounded-xl transition cursor-pointer"
                      >
                        Avbryt
                      </button>
                    </div>
                  </div>
                ) : (
                  <button
                    type="button"
                    onClick={() => setShowDeleteConfirm(true)}
                    className="w-full py-3 bg-red-950/20 hover:bg-red-950/40 text-red-400 border border-red-900/30 font-semibold text-xs rounded-xl transition flex items-center justify-center gap-2 cursor-pointer"
                  >
                    <Trash2 className="w-4 h-4" />
                    <span>Ta bort från biblioteket</span>
                  </button>
                )}
              </div>
            </div>
          )}

          {/* ===== FLIK 2: SPELFAKTA & INFO ===== */}
          {(!isOwned || activeTab === 'facts') && (
            <div className="space-y-6">
              {/* Om spelet */}
              {(remoteDetails?.summary || game.summary) && (
                <div className="bg-zinc-900/70 border border-zinc-800/80 rounded-2xl p-4 sm:p-5 space-y-2.5">
                  <h3 className="text-xs font-bold text-zinc-300 uppercase tracking-wider">
                    Om spelet
                  </h3>
                  <p
                    className={`text-xs sm:text-sm text-zinc-300 leading-relaxed ${
                      !isExpandedSummary ? 'line-clamp-4' : ''
                    }`}
                  >
                    {remoteDetails?.summary || game.summary}
                  </p>
                  <button
                    type="button"
                    onClick={() => setIsExpandedSummary(!isExpandedSummary)}
                    className="text-xs font-bold text-brand-red hover:underline pt-1 cursor-pointer"
                  >
                    {isExpandedSummary ? 'Visa mindre' : 'Visa mer'}
                  </button>
                </div>
              )}

              {/* Skärmdumpar */}
              {remoteDetails?.screenshots && remoteDetails.screenshots.length > 0 && (
                <div className="space-y-2.5">
                  <h3 className="text-xs font-bold text-zinc-300 uppercase tracking-wider px-1">
                    Skärmdumpar
                  </h3>
                  <div className="flex gap-3 overflow-x-auto pb-2 scrollbar-thin">
                    {remoteDetails.screenshots.map((s) => (
                      <img
                        key={s.id}
                        src={s.url}
                        alt="Screenshot"
                        onClick={() => setActiveLightboxImg(s.fullUrl)}
                        className="w-44 sm:w-56 h-28 sm:h-36 object-cover rounded-xl border border-zinc-800 hover:border-brand-red/60 transition cursor-zoom-in flex-shrink-0 shadow-md"
                      />
                    ))}
                  </div>
                </div>
              )}

              {/* Trailers & videor */}
              {remoteDetails?.videos && remoteDetails.videos.length > 0 && (
                <div className="space-y-2.5">
                  <h3 className="text-xs font-bold text-zinc-300 uppercase tracking-wider px-1">
                    Trailers & videor
                  </h3>
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    {remoteDetails.videos.slice(0, 2).map((v) => (
                      <div
                        key={v.videoId}
                        className="relative aspect-video rounded-xl overflow-hidden bg-black border border-zinc-800 shadow-md"
                      >
                        <iframe
                          src={`https://www.youtube.com/embed/${v.videoId}`}
                          title={v.name}
                          className="w-full h-full"
                          allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                          allowFullScreen
                        />
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* Speltid (Ren HowLongToBeat-referens) */}
              {hasHLTB && (
                <div className="bg-zinc-900/70 border border-zinc-800/80 rounded-2xl p-4 sm:p-5 space-y-3">
                  <div className="flex items-center justify-between border-b border-zinc-800/60 pb-2.5">
                    <div className="flex items-center gap-2">
                      <Clock className="w-4 h-4 text-brand-red" />
                      <span className="text-xs font-bold text-zinc-300 uppercase tracking-wider">
                        Speltid
                      </span>
                    </div>
                    <span className="text-[11px] text-zinc-500 font-medium">
                      Referens · HowLongToBeat
                    </span>
                  </div>

                  <div className="divide-y divide-zinc-800/60 text-xs">
                    {mainHours > 0 && (
                      <div className="py-2 flex items-center justify-between">
                        <div className="flex items-center gap-2 text-zinc-300">
                          <span>📖</span>
                          <span>Main Story</span>
                        </div>
                        <span className="font-bold text-white">{mainHours} timmar</span>
                      </div>
                    )}
                    {extraHours > 0 && (
                      <div className="py-2 flex items-center justify-between">
                        <div className="flex items-center gap-2 text-zinc-300">
                          <span>➕</span>
                          <span>Main + Extra</span>
                        </div>
                        <span className="font-bold text-white">{extraHours} timmar</span>
                      </div>
                    )}
                    {compHours > 0 && (
                      <div className="py-2 flex items-center justify-between">
                        <div className="flex items-center gap-2 text-zinc-300">
                          <span>🏆</span>
                          <span>Completionist</span>
                        </div>
                        <span className="font-bold text-white">{compHours} timmar</span>
                      </div>
                    )}
                  </div>
                </div>
              )}

              {/* Guider & Resurser */}
              <div className="bg-zinc-900/70 border border-zinc-800/80 rounded-2xl p-4 sm:p-5 space-y-4">
                <div className="flex items-center justify-between border-b border-zinc-800/60 pb-2.5">
                  <div className="flex items-center gap-2">
                    <BookOpen className="w-4 h-4 text-brand-red" />
                    <span className="text-xs font-bold text-zinc-300 uppercase tracking-wider">
                      Guider & Resurser
                    </span>
                  </div>
                </div>

                {/* Genomspelning */}
                <div className="space-y-2">
                  <div className="text-[11px] font-bold text-zinc-500 tracking-wider">
                    GENOMSPELNING
                  </div>
                  <div className="space-y-1.5">
                    <a
                      href={`https://www.google.com/search?q=${encodeURIComponent(game.title + ' walkthrough ign')}`}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="flex items-center justify-between px-3 py-2.5 bg-zinc-950/80 hover:bg-zinc-900 border border-zinc-800/80 rounded-xl text-xs text-zinc-200 transition group cursor-pointer"
                    >
                      <div className="flex items-center gap-2.5">
                        <span className="w-6 h-6 rounded-md bg-red-950/40 text-brand-red flex items-center justify-center text-xs">
                          📖
                        </span>
                        <div>
                          <div className="font-bold text-white group-hover:text-brand-red transition">
                            IGN Walkthrough
                          </div>
                          <div className="text-[11px] text-zinc-500">
                            Komplett guide & kapitelgenomgång
                          </div>
                        </div>
                      </div>
                      <ExternalLink className="w-3.5 h-3.5 text-zinc-500 group-hover:text-brand-red transition" />
                    </a>

                    <a
                      href={`https://www.google.com/search?q=${encodeURIComponent(game.title + ' trophy guide powerpyx')}`}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="flex items-center justify-between px-3 py-2.5 bg-zinc-950/80 hover:bg-zinc-900 border border-zinc-800/80 rounded-xl text-xs text-zinc-200 transition group cursor-pointer"
                    >
                      <div className="flex items-center gap-2.5">
                        <span className="w-6 h-6 rounded-md bg-amber-950/40 text-amber-400 flex items-center justify-center text-xs">
                          🏆
                        </span>
                        <div>
                          <div className="font-bold text-white group-hover:text-amber-400 transition">
                            PowerPyx Trophy Guide
                          </div>
                          <div className="text-[11px] text-zinc-500">
                            Troféer & 100%-genomgång
                          </div>
                        </div>
                      </div>
                      <ExternalLink className="w-3.5 h-3.5 text-zinc-500 group-hover:text-amber-400 transition" />
                    </a>

                    <a
                      href={`https://www.google.com/search?q=${encodeURIComponent(game.title + ' interactive map')}`}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="flex items-center justify-between px-3 py-2.5 bg-zinc-950/80 hover:bg-zinc-900 border border-zinc-800/80 rounded-xl text-xs text-zinc-200 transition group cursor-pointer"
                    >
                      <div className="flex items-center gap-2.5">
                        <span className="w-6 h-6 rounded-md bg-emerald-950/40 text-emerald-400 flex items-center justify-center text-xs">
                          🗺
                        </span>
                        <div>
                          <div className="font-bold text-white group-hover:text-emerald-400 transition">
                            Interaktiv Karta
                          </div>
                          <div className="text-[11px] text-zinc-500">
                            Samlarobjekt, bossar & kartor
                          </div>
                        </div>
                      </div>
                      <ExternalLink className="w-3.5 h-3.5 text-zinc-500 group-hover:text-emerald-400 transition" />
                    </a>
                  </div>
                </div>

                {/* Community */}
                <div className="space-y-2 pt-2 border-t border-zinc-800/60">
                  <div className="text-[11px] font-bold text-zinc-500 tracking-wider">
                    COMMUNITY
                  </div>
                  <a
                    href={`https://www.reddit.com/r/${encodeURIComponent(game.title.replace(/[^a-zA-Z0-9]/g, ''))}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="flex items-center justify-between px-3 py-2.5 bg-zinc-950/80 hover:bg-zinc-900 border border-zinc-800/80 rounded-xl text-xs text-zinc-200 transition group cursor-pointer"
                  >
                    <div className="flex items-center gap-2.5">
                      <span className="w-6 h-6 rounded-md bg-orange-950/40 text-orange-400 flex items-center justify-center text-xs">
                        💬
                      </span>
                      <div>
                        <div className="font-bold text-white group-hover:text-orange-400 transition">
                          Reddit Community
                        </div>
                        <div className="text-[11px] text-zinc-500">Diskussioner, builds & tips</div>
                      </div>
                    </div>
                    <ExternalLink className="w-3.5 h-3.5 text-zinc-500 group-hover:text-orange-400 transition" />
                  </a>
                </div>
              </div>

              {/* Relaterat (Spelserie / Liknande spel) */}
              <div className="bg-zinc-900/70 border border-zinc-800/80 rounded-2xl p-4 sm:p-5 space-y-4">
                <div className="flex items-center justify-between border-b border-zinc-800/60 pb-2.5">
                  <div className="flex items-center gap-2">
                    <Layers className="w-4 h-4 text-brand-red" />
                    <span className="text-xs font-bold text-zinc-300 uppercase tracking-wider">
                      Relaterat
                    </span>
                  </div>
                </div>

                {/* Spelserie vs Fristående titel */}
                {remoteDetails?.collectionName ? (
                  <div className="p-3 bg-zinc-950/80 border border-zinc-800/80 rounded-xl space-y-1">
                    <div className="text-[11px] font-bold text-brand-red uppercase tracking-wider">
                      Spelserie
                    </div>
                    <div className="text-sm font-bold text-white">
                      {remoteDetails.collectionName}
                    </div>
                  </div>
                ) : (
                  <div className="p-3 bg-zinc-950/80 border border-zinc-800/80 rounded-xl space-y-1">
                    <div className="text-xs font-bold text-zinc-300">Fristående titel</div>
                    <div className="text-[11px] text-zinc-500">
                      Inga ytterligare expansioner eller serietitlar listade på IGDB.
                    </div>
                  </div>
                )}

                {/* Liknande spel */}
                {remoteDetails?.similarGames && remoteDetails.similarGames.length > 0 && (
                  <div className="space-y-2 pt-1">
                    <div className="text-[11px] font-bold text-zinc-500 tracking-wider">
                      LIKNANDE SPEL
                    </div>
                    <div className="flex gap-3 overflow-x-auto pb-2 scrollbar-thin">
                      {remoteDetails.similarGames.map((sg) => (
                        <div
                          key={sg.id}
                          className="w-24 sm:w-28 flex-shrink-0 space-y-1.5 group"
                        >
                          <div className="aspect-[3/4] rounded-lg overflow-hidden bg-zinc-900 border border-zinc-800 shadow-sm">
                            {sg.coverUrl ? (
                              <img
                                src={sg.coverUrl}
                                alt={sg.title}
                                className="w-full h-full object-cover group-hover:scale-105 transition"
                              />
                            ) : (
                              <div className="w-full h-full flex items-center justify-center text-zinc-600">
                                <Gamepad className="w-6 h-6" />
                              </div>
                            )}
                          </div>
                          <div className="text-xs font-medium text-zinc-300 line-clamp-1 leading-snug group-hover:text-brand-red transition">
                            {sg.title}
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </div>

              {/* Fakta & Betyg */}
              <div className="bg-zinc-900/70 border border-zinc-800/80 rounded-2xl p-4 sm:p-5 space-y-3">
                <div className="flex items-center justify-between border-b border-zinc-800/60 pb-2.5">
                  <div className="flex items-center gap-2">
                    <Building2 className="w-4 h-4 text-brand-red" />
                    <span className="text-xs font-bold text-zinc-300 uppercase tracking-wider">
                      Fakta & Betyg
                    </span>
                  </div>
                </div>

                <div className="divide-y divide-zinc-800/60 text-xs">
                  {/* Betyg */}
                  <div className="py-2.5 flex items-center justify-between">
                    <span className="text-zinc-500">Betyg</span>
                    <span className="font-semibold text-white">
                      ★ {game.igdb_rating ? `${Math.round(game.igdb_rating * 10)}% spelare` : 'N/A'}
                    </span>
                  </div>

                  {/* Genre */}
                  <div className="py-2.5 flex items-center justify-between">
                    <span className="text-zinc-500">Genre</span>
                    <span className="font-semibold text-white">
                      {game.genres?.join(', ') || 'N/A'}
                    </span>
                  </div>

                  {/* Plattformar */}
                  <div className="py-2.5 flex items-center justify-between">
                    <span className="text-zinc-500">Plattformar</span>
                    <span className="font-semibold text-white text-right max-w-xs truncate">
                      {game.platforms?.join(', ') || 'N/A'}
                    </span>
                  </div>

                  {/* Lanseringsdatum */}
                  <div className="py-2.5 flex items-center justify-between">
                    <span className="text-zinc-500">Lanseringsdatum</span>
                    <span className="font-semibold text-white">
                      {liveReleaseDate
                        ? new Date(liveReleaseDate * 1000).toLocaleDateString('sv-SE', {
                            day: 'numeric',
                            month: 'long',
                            year: 'numeric',
                          })
                        : game.release_year || 'N/A'}
                    </span>
                  </div>

                  {/* Utvecklare */}
                  <div className="py-2.5 flex items-center justify-between">
                    <span className="text-zinc-500">Utvecklare</span>
                    <span className="font-semibold text-right">
                      {remoteDetails?.developerCompanies &&
                      remoteDetails.developerCompanies.length > 0 ? (
                        remoteDetails.developerCompanies.map((c, idx) => (
                          <button
                            key={c.id}
                            type="button"
                            onClick={() => onOpenCompany && onOpenCompany(c.id, c.name, 'developer')}
                            className="text-brand-red hover:underline ml-1 cursor-pointer font-semibold"
                          >
                            {c.name}
                            {idx < remoteDetails.developerCompanies!.length - 1 ? ',' : ''}
                          </button>
                        ))
                      ) : game.developers && game.developers.length > 0 ? (
                        <span className="text-white">{game.developers.join(', ')}</span>
                      ) : (
                        <span className="text-zinc-500">N/A</span>
                      )}
                    </span>
                  </div>

                  {/* Utgivare */}
                  <div className="py-2.5 flex items-center justify-between">
                    <span className="text-zinc-500">Utgivare</span>
                    <span className="font-semibold text-right">
                      {remoteDetails?.publisherCompanies &&
                      remoteDetails.publisherCompanies.length > 0 ? (
                        remoteDetails.publisherCompanies.map((c, idx) => (
                          <button
                            key={c.id}
                            type="button"
                            onClick={() => onOpenCompany && onOpenCompany(c.id, c.name, 'publisher')}
                            className="text-brand-red hover:underline ml-1 cursor-pointer font-semibold"
                          >
                            {c.name}
                            {idx < remoteDetails.publisherCompanies!.length - 1 ? ',' : ''}
                          </button>
                        ))
                      ) : (
                        <span className="text-zinc-500">N/A</span>
                      )}
                    </span>
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Delningsmodal */}
      <GameShareModal
        game={game}
        isOpen={isShareModalOpen}
        onClose={() => setIsShareModalOpen(false)}
      />
    </div>
  );
}
