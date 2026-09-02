'use client';

import React, { useState, useEffect } from 'react';
import { Game, IGDBSearchResult, PlayStatus } from '@/types/game';
import { supabase } from '@/lib/supabase';
import { inferPlayTypes } from '@/lib/statusHelper';
import { Search, X, Loader2, Plus, Check, Star, Gamepad, Calendar } from 'lucide-react';

interface AddGameModalProps {
  isOpen: boolean;
  onClose: () => void;
  onGameAdded: (newGame: Game) => void;
  existingGames: Game[];
}

const INITIAL_OPTIONS = [
  { id: 'backlog', label: 'I min Backlog', status: 'notStarted' as PlayStatus, isBacklog: true, isOwned: true },
  { id: 'playing', label: 'Spelar nu', status: 'playing' as PlayStatus, isBacklog: false, isOwned: true },
  { id: 'notStarted', label: 'Inte påbörjat', status: 'notStarted' as PlayStatus, isBacklog: false, isOwned: true },
  { id: 'completed', label: 'Genomspelat', status: 'completed' as PlayStatus, isBacklog: false, isOwned: true },
  { id: 'wishlist', label: 'Önskelista', status: 'notStarted' as PlayStatus, isBacklog: false, isOwned: false },
] as const;

export function AddGameModal({
  isOpen,
  onClose,
  onGameAdded,
  existingGames,
}: AddGameModalProps) {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<IGDBSearchResult[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [addingId, setAddingId] = useState<number | null>(null);
  const [initialChoice, setInitialChoice] = useState<string>('backlog');
  const [completedYear, setCompletedYear] = useState<number | null>(new Date().getFullYear());
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  // Debounced IGDB search
  useEffect(() => {
    if (!query.trim()) {
      setResults([]);
      setIsLoading(false);
      return;
    }

    const timer = setTimeout(async () => {
      setIsLoading(true);
      setErrorMessage(null);
      try {
        const res = await fetch(`/api/igdb/search?q=${encodeURIComponent(query)}`);
        const data = await res.json();
        if (res.ok) {
          setResults(data.results || []);
        } else {
          setErrorMessage(data.error || 'Kunde inte söka i IGDB');
        }
      } catch (err: any) {
        setErrorMessage('Nätverksfel vid sökning');
      } finally {
        setIsLoading(false);
      }
    }, 400);

    return () => clearTimeout(timer);
  }, [query]);

  if (!isOpen) return null;

  const handleAddGame = async (igdbGame: IGDBSearchResult) => {
    setAddingId(igdbGame.id);
    setErrorMessage(null);
    try {
      const releaseYear = (igdbGame as any).releaseYear || (igdbGame.first_release_date ? new Date(igdbGame.first_release_date * 1000).getFullYear() : null);
      const platforms = (igdbGame.platforms || []).map((p) => p.name);
      const genres = (igdbGame.genres || []).map((g) => g.name);
      const developers = (igdbGame.involved_companies || [])
        .filter((c) => c.developer)
        .map((c) => c.company.name);

      const ratingScore = igdbGame.total_rating || igdbGame.rating;
      const igdbRating = ratingScore ? Math.round((ratingScore / 10) * 10) / 10 : null;

      const pairedUserId = typeof window !== 'undefined' ? localStorage.getItem('gameshelf_paired_user_id') : null;
      const choice = INITIAL_OPTIONS.find((o) => o.id === initialChoice) || INITIAL_OPTIONS[0];
      const playTypes = inferPlayTypes({ title: igdbGame.name, genres });

      const newGamePayload = {
        user_id: pairedUserId,
        title: igdbGame.name,
        platforms,
        release_year: releaseYear,
        genres,
        developers: developers.length > 0 ? developers : [],
        status: choice.status,
        rating: null,
        igdb_rating: igdbRating,
        cover_url: igdbGame.cover?.url || null,
        igdb_id: igdbGame.id,
        first_release_date: igdbGame.first_release_date || null,
        estimated_hours: null,
        is_owned: choice.isOwned,
        is_backlog: choice.isBacklog,
        play_types: playTypes,
        notes: '',
        todos: [],
        completed_year: choice.status === 'completed' ? completedYear : null,
        completed_date: choice.status === 'completed' && completedYear ? new Date().toISOString() : null,
      };

      const { data, error } = await supabase
        .from('user_games')
        .insert([newGamePayload])
        .select()
        .single();

      if (error) {
        console.error('Supabase error inserting game:', error);
        // Fallback for offline/local simulation if table insertion fails
        const fallbackGame: Game = {
          id: crypto.randomUUID(),
          ...newGamePayload,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        } as any;
        onGameAdded(fallbackGame);
      } else if (data) {
        onGameAdded(data as Game);
      }
    } catch (err: any) {
      console.error('Error in handleAddGame:', err);
      setErrorMessage('Kunde inte lägga till spelet');
    } finally {
      setAddingId(null);
    }
  };

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md animate-in fade-in duration-150"
      onClick={onClose}
    >
      <div
        className="w-full max-w-3xl bg-[#111216] border border-zinc-800/90 rounded-2xl shadow-2xl overflow-hidden flex flex-col max-h-[90vh] animate-in zoom-in-95 duration-150"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Modal Header */}
        <div className="p-4 sm:p-6 border-b border-zinc-800 flex items-center justify-between">
          <div>
            <h2 className="text-xl font-bold text-white flex items-center gap-2">
              <span>Lägg till spel i samlingen</span>
              <span className="text-xs px-2 py-0.5 rounded bg-zinc-800 text-zinc-400 font-normal border border-zinc-700">
                IGDB API
              </span>
            </h2>
            <p className="text-xs text-zinc-400 mt-1">
              Sök bland hundratusentals spel och lägg direkt till i din samling.
            </p>
          </div>
          <button
            onClick={onClose}
            className="p-2 rounded-lg bg-zinc-800/80 hover:bg-zinc-700 text-zinc-400 hover:text-white transition"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Search Bar & Default Status Selector */}
        <div className="p-4 sm:px-6 bg-zinc-900/50 border-b border-zinc-800 flex flex-col sm:flex-row gap-3 items-center">
          <div className="relative flex-1 w-full">
            <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-500" />
            <input
              type="text"
              autoFocus
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Sök speltitel (t.ex. Elden Ring, Mario, Cyberpunk)..."
              className="w-full pl-10 pr-4 py-2.5 bg-zinc-950 border border-zinc-700 rounded-xl text-zinc-100 placeholder-zinc-500 focus:outline-none focus:border-brand-red text-sm"
            />
            {isLoading && (
              <Loader2 className="absolute right-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-400 animate-spin" />
            )}
          </div>

          <div className="flex items-center gap-2 w-full sm:w-auto">
            <span className="text-xs text-zinc-400 whitespace-nowrap">Lägg till som:</span>
            <select
              value={initialChoice}
              onChange={(e) => setInitialChoice(e.target.value)}
              className="bg-zinc-950 border border-zinc-700 text-zinc-200 text-xs rounded-xl px-3 py-2.5 focus:outline-none focus:border-brand-red flex-1 sm:flex-none"
            >
              {INITIAL_OPTIONS.map((opt) => (
                <option key={opt.id} value={opt.id}>
                  {opt.label}
                </option>
              ))}
            </select>

            {initialChoice === 'completed' && (
              <select
                value={completedYear ?? ''}
                onChange={(e) => setCompletedYear(e.target.value === '' ? null : Number(e.target.value))}
                className="bg-zinc-950 border border-zinc-700 text-zinc-200 text-xs rounded-xl px-2.5 py-2.5 focus:outline-none focus:border-brand-red cursor-pointer"
                title="Klarat år (lämna tomt om du är osäker, endast i år räknas mot årets spelmål)"
              >
                <option value="">År: Ej angivet</option>
                <option value={new Date().getFullYear()}>{new Date().getFullYear()} (I år)</option>
                {Array.from({ length: 15 }, (_, i) => new Date().getFullYear() - 1 - i).map((y) => (
                  <option key={y} value={y}>{y}</option>
                ))}
              </select>
            )}
          </div>
        </div>

        {/* Results Container */}
        <div className="flex-1 overflow-y-auto p-4 sm:p-6 space-y-3">
          {errorMessage && (
            <div className="p-3 bg-red-950/40 border border-red-800/60 rounded-xl text-red-300 text-xs">
              {errorMessage}
            </div>
          )}

          {!query && (
            <div className="text-center py-16 text-zinc-500 text-sm">
              <Gamepad className="w-12 h-12 mx-auto mb-3 text-zinc-700" />
              Skriv en speltitel ovan för att söka i IGDB.
            </div>
          )}

          {query && !isLoading && results.length === 0 && !errorMessage && (
            <div className="text-center py-16 text-zinc-500 text-sm">
              Inga resultat hittades för "{query}". Prova med en annan sökterm.
            </div>
          )}

          {results.map((game) => {
            const isAlreadyAdded = existingGames.some(
              (g) => g.igdb_id === game.id || g.title.toLowerCase() === game.name.toLowerCase()
            );
            const isAdding = addingId === game.id;
            const releaseYear = game.first_release_date
              ? new Date(game.first_release_date * 1000).getFullYear()
              : null;
            const developer = game.involved_companies?.find((c) => c.developer)?.company?.name;

            return (
              <div
                key={game.id}
                className="flex items-center gap-4 p-3.5 rounded-xl bg-zinc-900/60 hover:bg-zinc-900 border border-zinc-800/80 transition"
              >
                {/* Cover Thumbnail */}
                <div className="w-14 h-18 rounded-lg overflow-hidden bg-zinc-800 border border-zinc-700/60 flex-shrink-0 aspect-[3/4]">
                  {game.cover?.url ? (
                    <img
                      src={game.cover.url}
                      alt={game.name}
                      className="w-full h-full object-cover"
                    />
                  ) : (
                    <div className="w-full h-full flex items-center justify-center">
                      <Gamepad className="w-5 h-5 text-zinc-600" />
                    </div>
                  )}
                </div>

                {/* Details */}
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2">
                    <h4 className="font-semibold text-zinc-100 text-sm truncate">{game.name}</h4>
                    {releaseYear && (
                      <span className="text-xs text-zinc-400 flex items-center gap-1">
                        <Calendar className="w-3 h-3 text-zinc-500" />
                        {releaseYear}
                      </span>
                    )}
                  </div>

                  <div className="flex flex-wrap items-center gap-2 mt-1 text-xs text-zinc-400">
                    {developer && <span className="text-zinc-400">{developer}</span>}
                    {game.platforms && game.platforms.length > 0 && (
                      <span className="text-zinc-500 truncate max-w-[200px]">
                        • {game.platforms.map((p) => p.name).join(', ')}
                      </span>
                    )}
                  </div>

                  {game.genres && game.genres.length > 0 && (
                    <div className="flex flex-wrap gap-1 mt-1.5">
                      {game.genres.slice(0, 3).map((genre) => (
                        <span
                          key={genre.id}
                          className="px-1.5 py-0.5 rounded text-[10px] bg-zinc-800 text-zinc-400 border border-zinc-700/50"
                        >
                          {genre.name}
                        </span>
                      ))}
                    </div>
                  )}
                </div>

                {/* Add Button / Added Indicator */}
                <div className="flex-shrink-0">
                  {isAlreadyAdded ? (
                    <span className="inline-flex items-center gap-1 px-3 py-1.5 rounded-lg bg-zinc-800 text-emerald-400 text-xs font-medium border border-zinc-700">
                      <Check className="w-3.5 h-3.5" />
                      I biblioteket
                    </span>
                  ) : (
                    <button
                      onClick={() => handleAddGame(game)}
                      disabled={isAdding}
                      className="inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-lg bg-brand-red hover:bg-brand-redPressed disabled:bg-zinc-800 text-white text-xs font-semibold shadow-md shadow-brand-red/20 transition transform active:scale-95"
                    >
                      {isAdding ? (
                        <Loader2 className="w-3.5 h-3.5 animate-spin" />
                      ) : (
                        <Plus className="w-3.5 h-3.5" />
                      )}
                      <span>Lägg till</span>
                    </button>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
