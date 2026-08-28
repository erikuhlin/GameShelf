'use client';

import React, { useState, useEffect } from 'react';
import { Game, GameCollection, PlayStatus, PLAY_STATUSES, GameTodoItem } from '@/types/game';
import { supabase } from '@/lib/supabase';
import { StatusBadge } from './StatusBadge';
import { ReleaseCountdown } from './ReleaseCountdown';
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
} from 'lucide-react';

interface GameDetailModalProps {
  game: Game | null;
  isOpen: boolean;
  onClose: () => void;
  onUpdateGame: (updated: Game) => void;
  onDeleteGame: (id: string) => void;
  collections: GameCollection[];
  onToggleCollection: (gameId: string, collectionId: string) => void;
}

export function GameDetailModal({
  game,
  isOpen,
  onClose,
  onUpdateGame,
  onDeleteGame,
  collections,
  onToggleCollection,
}: GameDetailModalProps) {
  if (!isOpen || !game) return null;

  const [status, setStatus] = useState<PlayStatus>(game.status);
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

  // Återställ formulärstate när ett nytt spel öppnas
  useEffect(() => {
    if (game) {
      setStatus(game.status);
      setRating(game.rating || null);
      setIsOwned(game.is_owned);
      setEstimatedHours(game.estimated_hours ?? '');
      setNotes(game.notes || '');
      setTodos(game.todos || []);
      setLiveReleaseDate(game.first_release_date || null);
    }
  }, [game?.id]);

  // Hämta exakt releasedatum från IGDB om det saknas på det lokala spelet
  useEffect(() => {
    if (game.first_release_date) {
      setLiveReleaseDate(game.first_release_date);
      return;
    }

    if (game.igdb_id) {
      fetch(`/api/igdb/games/${game.igdb_id}`)
        .then((res) => res.json())
        .then((data) => {
          const fetchedDate = data?.game?.first_release_date;
          if (fetchedDate) {
            setLiveReleaseDate(fetchedDate);
            supabase
              .from('user_games')
              .update({ first_release_date: fetchedDate })
              .eq('id', game.id);
          }
        })
        .catch(() => {});
    } else if (game.title) {
      fetch(`/api/igdb/search?q=${encodeURIComponent(game.title)}`)
        .then((res) => res.json())
        .then((data) => {
          const match = data?.results?.[0] || data?.games?.[0];
          if (match?.first_release_date) {
            setLiveReleaseDate(match.first_release_date);
            supabase
              .from('user_games')
              .update({
                first_release_date: match.first_release_date,
                igdb_id: match.id || null,
              })
              .eq('id', game.id);
          }
        })
        .catch(() => {});
    }
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

  const handleSave = async () => {
    setIsSaving(true);
    try {
      const updatedData = {
        status,
        rating: rating || null,
        is_owned: isOwned,
        estimated_hours: estimatedHours !== '' ? Number(estimatedHours) : null,
        notes,
        todos,
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

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm animate-in fade-in duration-200">
      <div className="bg-[#16181f] border border-zinc-800 rounded-2xl w-full max-w-4xl max-h-[90vh] flex flex-col shadow-2xl overflow-hidden">
        {/* Header / Backdrop Banner */}
        <div className="relative p-6 border-b border-zinc-800 bg-gradient-to-r from-zinc-900 to-zinc-950 flex items-start justify-between">
          <div className="flex gap-5 items-start">
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
            <div className="flex-1">
              <div className="flex items-center gap-2 mb-1">
                <StatusBadge status={status} size="sm" />
                {game.igdb_rating && (
                  <span className="text-xs px-2 py-0.5 rounded bg-zinc-800 text-amber-300 border border-zinc-700 flex items-center gap-1 font-semibold">
                    <Sparkles className="w-3 h-3 text-amber-400" />
                    IGDB {game.igdb_rating}/10
                  </span>
                )}
              </div>

              <h2 className="text-xl sm:text-2xl font-bold text-white tracking-tight">
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
                {game.developers && game.developers.length > 0 && (
                  <>
                    <span>•</span>
                    <span className="text-zinc-300">{game.developers.join(', ')}</span>
                  </>
                )}
              </div>

              {game.platforms && game.platforms.length > 0 && (
                <div className="flex flex-wrap gap-1 mt-2.5">
                  {game.platforms.map((p) => (
                    <span
                      key={p}
                      className="px-2 py-0.5 rounded text-[11px] bg-zinc-800 text-zinc-300 border border-zinc-700/60"
                    >
                      {p}
                    </span>
                  ))}
                </div>
              )}
            </div>
          </div>

          <button
            onClick={onClose}
            className="p-2 rounded-lg bg-zinc-800/80 hover:bg-zinc-700 text-zinc-400 hover:text-white transition"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Modal Body */}
        <div className="flex-1 overflow-y-auto p-6 space-y-6">
          {/* Release Countdown for upcoming games */}
          <ReleaseCountdown
            firstReleaseDate={liveReleaseDate}
            releaseYear={game.release_year}
          />

          {/* Controls: Status & Rating */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            {/* Status Picker */}
            <div className="bg-zinc-900/60 border border-zinc-800 p-4 rounded-xl">
              <label className="block text-xs font-semibold text-zinc-400 uppercase tracking-wider mb-2">
                Spelstatus
              </label>
              <select
                value={status}
                onChange={(e) => setStatus(e.target.value as PlayStatus)}
                className="w-full bg-zinc-950 border border-zinc-700 text-zinc-100 rounded-lg px-3 py-2 text-sm focus:outline-none focus:border-brand-red"
              >
                {PLAY_STATUSES.map((s) => (
                  <option key={s} value={s}>
                    {s}
                  </option>
                ))}
              </select>
            </div>

            {/* Rating Selector (1-10) */}
            <div className="bg-zinc-900/60 border border-zinc-800 p-4 rounded-xl">
              <div className="flex items-center justify-between mb-2">
                <label className="block text-xs font-semibold text-zinc-400 uppercase tracking-wider">
                  Mitt betyg
                </label>
                {rating && (
                  <button
                    onClick={() => setRating(null)}
                    className="text-[11px] text-zinc-500 hover:text-zinc-300"
                  >
                    Rensa
                  </button>
                )}
              </div>
              <div className="flex items-center gap-1.5 flex-wrap">
                {[1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map((num) => (
                  <button
                    key={num}
                    type="button"
                    onClick={() => setRating(rating === num ? null : num)}
                    className={`w-7 h-7 rounded-lg text-xs font-bold transition ${
                      rating === num
                        ? 'bg-amber-500 text-black shadow-md shadow-amber-500/20'
                        : 'bg-zinc-800 text-zinc-300 hover:bg-zinc-700'
                    }`}
                  >
                    {num}
                  </button>
                ))}
              </div>
            </div>
          </div>

          {/* Details: Ownership & Playtime */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            {/* Ownership Toggle */}
            <div className="bg-zinc-900/60 border border-zinc-800 p-4 rounded-xl flex items-center justify-between">
              <div>
                <span className="block text-sm font-semibold text-zinc-200">
                  I ägo / aktiv samling
                </span>
                <span className="text-xs text-zinc-500">
                  Slå av om detta är ett spelminne / tidigare ägt spel
                </span>
              </div>
              <button
                type="button"
                onClick={() => setIsOwned(!isOwned)}
                className={`w-12 h-6 flex items-center rounded-full p-1 transition duration-300 ${
                  isOwned ? 'bg-brand-red' : 'bg-zinc-700'
                }`}
              >
                <div
                  className={`bg-white w-4 h-4 rounded-full shadow-md transform transition duration-300 ${
                    isOwned ? 'translate-x-6' : 'translate-x-0'
                  }`}
                />
              </button>
            </div>

            {/* Estimated Hours */}
            <div className="bg-zinc-900/60 border border-zinc-800 p-4 rounded-xl flex items-center justify-between">
              <div>
                <span className="block text-sm font-semibold text-zinc-200">
                  Uppskattad speltid
                </span>
                <span className="text-xs text-zinc-500">Antal timmar att klara</span>
              </div>
              <div className="flex items-center gap-1.5">
                <input
                  type="number"
                  min="0"
                  value={estimatedHours}
                  onChange={(e) => setEstimatedHours(e.target.value)}
                  placeholder="—"
                  className="w-16 bg-zinc-950 border border-zinc-700 rounded-lg px-2.5 py-1.5 text-sm text-center text-zinc-100 focus:outline-none focus:border-brand-red"
                />
                <span className="text-xs text-zinc-400">timmar</span>
              </div>
            </div>
          </div>

          {/* Collections Membership */}
          {collections.length > 0 && (
            <div className="bg-zinc-900/60 border border-zinc-800 p-4 rounded-xl">
              <label className="block text-xs font-semibold text-zinc-400 uppercase tracking-wider mb-2.5">
                Mina samlingar
              </label>
              <div className="flex flex-wrap gap-2">
                {collections.map((c) => {
                  const isInCollection = c.game_ids?.includes(game.id);
                  return (
                    <button
                      key={c.id}
                      type="button"
                      onClick={() => onToggleCollection(game.id, c.id)}
                      className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium border transition ${
                        isInCollection
                          ? 'bg-brand-red/20 border-brand-red text-rose-300'
                          : 'bg-zinc-800/80 border-zinc-700 text-zinc-400 hover:text-zinc-200'
                      }`}
                    >
                      <Bookmark
                        className={`w-3.5 h-3.5 ${isInCollection ? 'fill-current' : ''}`}
                      />
                      <span>{c.name}</span>
                    </button>
                  );
                })}
              </div>
            </div>
          )}

          {/* Notes */}
          <div className="bg-zinc-900/60 border border-zinc-800 p-4 rounded-xl">
            <label className="block text-xs font-semibold text-zinc-400 uppercase tracking-wider mb-2">
              Personliga anteckningar & tankar
            </label>
            <textarea
              rows={3}
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder="Skriv dina tankar, minnen eller recension här..."
              className="w-full bg-zinc-950 border border-zinc-700 rounded-xl p-3 text-sm text-zinc-100 placeholder-zinc-500 focus:outline-none focus:border-brand-red"
            />
          </div>

          {/* To-Do List */}
          <div className="bg-zinc-900/60 border border-zinc-800 p-4 rounded-xl">
            <div className="flex items-center justify-between mb-3">
              <label className="block text-xs font-semibold text-zinc-400 uppercase tracking-wider">
                Mål & Att-göra-lista ({todos.filter((t) => t.isDone).length}/{todos.length})
              </label>
            </div>

            {/* Existing Todos */}
            <div className="space-y-2 mb-3">
              {todos.map((todo) => (
                <div
                  key={todo.id}
                  className="flex items-center justify-between p-2.5 rounded-lg bg-zinc-950/80 border border-zinc-800/80"
                >
                  <button
                    type="button"
                    onClick={() => handleToggleTodo(todo.id)}
                    className="flex items-center gap-2.5 text-left flex-1"
                  >
                    <div
                      className={`w-4 h-4 rounded border flex items-center justify-center transition ${
                        todo.isDone
                          ? 'bg-emerald-600 border-emerald-500 text-white'
                          : 'border-zinc-600 bg-zinc-900'
                      }`}
                    >
                      {todo.isDone && <Check className="w-3 h-3 stroke-[3]" />}
                    </div>
                    <span
                      className={`text-sm ${
                        todo.isDone ? 'line-through text-zinc-500' : 'text-zinc-200'
                      }`}
                    >
                      {todo.title}
                    </span>
                  </button>

                  <button
                    type="button"
                    onClick={() => handleDeleteTodo(todo.id)}
                    className="text-zinc-500 hover:text-red-400 p-1 transition"
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                </div>
              ))}
            </div>

            {/* Add Todo Input */}
            <form onSubmit={handleAddTodo} className="flex gap-2">
              <input
                type="text"
                value={newTodoTitle}
                onChange={(e) => setNewTodoTitle(e.target.value)}
                placeholder="Nytt delmål (t.ex. klara alla sidequests)..."
                className="flex-1 bg-zinc-950 border border-zinc-700 rounded-lg px-3 py-1.5 text-sm text-zinc-100 placeholder-zinc-500 focus:outline-none focus:border-brand-red"
              />
              <button
                type="submit"
                className="px-3 py-1.5 bg-zinc-800 hover:bg-zinc-700 text-zinc-200 rounded-lg text-xs font-semibold flex items-center gap-1 transition"
              >
                <Plus className="w-3.5 h-3.5" />
                Lägg till
              </button>
            </form>
          </div>
        </div>

        {/* Footer: Delete and Save buttons */}
        <div className="p-4 sm:px-6 border-t border-zinc-800 bg-zinc-950 flex items-center justify-between">
          {showDeleteConfirm ? (
            <div className="flex items-center gap-2">
              <span className="text-xs text-red-400">Är du säker?</span>
              <button
                onClick={handleDelete}
                className="px-3 py-1.5 rounded-lg bg-red-600 hover:bg-red-700 text-white text-xs font-semibold transition"
              >
                Ja, ta bort
              </button>
              <button
                onClick={() => setShowDeleteConfirm(false)}
                className="px-3 py-1.5 rounded-lg bg-zinc-800 text-zinc-300 text-xs transition"
              >
                Avbryt
              </button>
            </div>
          ) : (
            <button
              onClick={() => setShowDeleteConfirm(true)}
              className="flex items-center gap-1.5 px-3 py-2 rounded-lg text-xs font-medium text-zinc-500 hover:text-red-400 hover:bg-red-950/30 transition"
            >
              <Trash2 className="w-4 h-4" />
              <span>Ta bort från bibliotek</span>
            </button>
          )}

          <div className="flex items-center gap-3">
            <button
              onClick={onClose}
              className="px-4 py-2 text-xs font-medium text-zinc-400 hover:text-zinc-200 transition"
            >
              Avbryt
            </button>
            <button
              onClick={handleSave}
              disabled={isSaving}
              className="flex items-center gap-1.5 px-5 py-2 rounded-xl bg-brand-red hover:bg-brand-redPressed text-white text-xs font-semibold shadow-lg shadow-brand-red/20 transition transform active:scale-95"
            >
              <Save className="w-4 h-4" />
              <span>{isSaving ? 'Sparar...' : 'Spara ändringar'}</span>
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
