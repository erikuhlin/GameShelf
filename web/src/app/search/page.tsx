'use client';

import React, { useState, useEffect } from 'react';
import Link from 'next/link';
import { supabase } from '@/lib/supabase';
import { PlayStatus, PLAY_STATUSES } from '@/types/game';
import {
  Search as SearchIcon,
  ArrowLeft,
  Loader2,
  Plus,
  Check,
  Star,
  Gamepad2,
  Calendar,
  Sparkles,
} from 'lucide-react';

interface SearchResult {
  id: number;
  title: string;
  release_year?: number | null;
  platforms: string[];
  genres: string[];
  developers: string[];
  cover_url?: string | null;
  igdb_rating?: number | null;
  summary: string;
}

export default function SearchPage() {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<SearchResult[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [addedIds, setAddedIds] = useState<number[]>([]);
  const [addingId, setAddingId] = useState<number | null>(null);
  const [selectedStatus, setSelectedStatus] = useState<PlayStatus>('Backlog');
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  // Fetch already added games to mark them
  useEffect(() => {
    async function loadExisting() {
      const { data } = await supabase.from('user_games').select('igdb_id');
      if (data) {
        const ids = data.map((d: any) => Number(d.igdb_id)).filter(Boolean);
        setAddedIds(ids);
      }
    }
    loadExisting();
  }, []);

  // Debounced search
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
        const res = await fetch(`/api/games/search?q=${encodeURIComponent(query)}`);
        const data = await res.json();
        if (res.ok) {
          setResults(data.results || []);
        } else {
          setErrorMessage(data.error || 'Kunde inte söka i IGDB');
        }
      } catch (err: any) {
        setErrorMessage(err.message || 'Nätverksfel');
      } finally {
        setIsLoading(false);
      }
    }, 350);

    return () => clearTimeout(timer);
  }, [query]);

  const handleAddGame = async (game: SearchResult) => {
    setAddingId(game.id);
    try {
      const payload = {
        id: crypto.randomUUID(),
        title: game.title,
        platforms: game.platforms,
        platform: game.platforms[0] || null,
        release_year: game.release_year,
        genres: game.genres,
        developers: game.developers,
        status: selectedStatus,
        rating: null,
        igdb_rating: game.igdb_rating,
        cover_url: game.cover_url,
        igdb_id: game.id,
        is_owned: selectedStatus !== 'Önskelista',
        notes: '',
        todos: [],
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      };

      const { error } = await supabase.from('user_games').insert([payload]);
      if (error) console.error('Error inserting into user_games:', error);

      if (typeof window !== 'undefined') {
        const cached = localStorage.getItem('gameshelf_local_games');
        const existing = cached ? JSON.parse(cached) : [];
        localStorage.setItem(
          'gameshelf_local_games',
          JSON.stringify([payload, ...existing.filter((g: any) => g.igdb_id !== game.id)])
        );
      }

      setAddedIds((prev) => [...prev, game.id]);
    } catch (err) {
      console.error('Failed to add game:', err);
    } finally {
      setAddingId(null);
    }
  };

  return (
    <div className="min-h-screen bg-[#0d0e12] text-zinc-100 flex flex-col">
      {/* Header */}
      <header className="sticky top-0 z-30 bg-[#0d0e12]/95 backdrop-blur-md border-b border-zinc-800 px-4 lg:px-8 py-4">
        <div className="max-w-5xl mx-auto flex items-center justify-between gap-4">
          <Link
            href="/"
            className="flex items-center gap-2 text-sm font-medium text-zinc-400 hover:text-white transition"
          >
            <ArrowLeft className="w-4 h-4" />
            <span>Tillbaka till biblioteket</span>
          </Link>

          <div className="flex items-center gap-2">
            <span className="text-xs text-zinc-400 hidden sm:inline">Status för nya spel:</span>
            <select
              value={selectedStatus}
              onChange={(e) => setSelectedStatus(e.target.value as PlayStatus)}
              className="bg-zinc-900 border border-zinc-700 text-zinc-200 text-xs rounded-lg px-2.5 py-1.5 focus:outline-none focus:border-brand-red"
            >
              {PLAY_STATUSES.map((status) => (
                <option key={status} value={status}>
                  {status}
                </option>
              ))}
            </select>
          </div>
        </div>
      </header>

      {/* Main Container */}
      <main className="flex-1 max-w-5xl w-full mx-auto px-4 lg:px-8 py-8 space-y-6">
        {/* Search Input Hero */}
        <div className="relative">
          <SearchIcon className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-zinc-500" />
          <input
            type="text"
            autoFocus
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Sök spel via IGDB (t.ex. Mario Wonder, God of War, Cyberpunk)..."
            className="w-full pl-12 pr-12 py-3.5 bg-zinc-900 border border-zinc-700 rounded-2xl text-base text-zinc-100 placeholder-zinc-500 focus:outline-none focus:border-brand-red shadow-lg"
          />
          {isLoading && (
            <Loader2 className="absolute right-4 top-1/2 -translate-y-1/2 w-5 h-5 text-zinc-400 animate-spin" />
          )}
        </div>

        {errorMessage && (
          <div className="p-4 bg-red-950/40 border border-red-800 rounded-xl text-red-300 text-xs">
            {errorMessage}
          </div>
        )}

        {/* Empty state */}
        {!query && (
          <div className="flex flex-col items-center justify-center py-24 text-center">
            <div className="w-16 h-16 rounded-2xl bg-zinc-900 border border-zinc-800 flex items-center justify-center text-zinc-600 mb-4">
              <Gamepad2 className="w-8 h-8" />
            </div>
            <h3 className="text-base font-semibold text-zinc-300">Sök och lägg till nya spel</h3>
            <p className="text-xs text-zinc-500 max-w-sm mt-1">
              Skriv en speltitel ovan för att hämta information, omslag och speltid direkt från IGDB.
            </p>
          </div>
        )}

        {/* Results grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {results.map((game) => {
            const isAdded = addedIds.includes(game.id);
            const isAdding = addingId === game.id;

            return (
              <div
                key={game.id}
                className="flex items-start gap-4 p-4 rounded-xl bg-zinc-900/60 border border-zinc-800/80 hover:border-zinc-700 transition"
              >
                {/* Cover art */}
                <div className="w-20 aspect-[3/4] rounded-lg overflow-hidden bg-zinc-800 border border-zinc-700 flex-shrink-0">
                  {game.cover_url ? (
                    <img
                      src={game.cover_url}
                      alt={game.title}
                      className="w-full h-full object-cover"
                    />
                  ) : (
                    <div className="w-full h-full flex items-center justify-center">
                      <Gamepad2 className="w-6 h-6 text-zinc-600" />
                    </div>
                  )}
                </div>

                {/* Info */}
                <div className="flex-1 min-w-0 flex flex-col justify-between h-full">
                  <div>
                    <div className="flex items-start justify-between gap-2">
                      <h4 className="font-bold text-sm text-zinc-100 truncate">{game.title}</h4>
                      {game.igdb_rating && (
                        <span className="text-[11px] px-1.5 py-0.5 rounded bg-zinc-800 text-amber-300 border border-zinc-700 flex items-center gap-1 font-semibold flex-shrink-0">
                          <Star className="w-2.5 h-2.5 fill-current" />
                          {(Math.round(Number(game.igdb_rating) * 10) / 10).toFixed(1)}
                        </span>
                      )}
                    </div>

                    <div className="flex items-center gap-2 mt-1 text-xs text-zinc-400">
                      {game.release_year && (
                        <span className="flex items-center gap-1">
                          <Calendar className="w-3 h-3 text-zinc-500" />
                          {game.release_year}
                        </span>
                      )}
                      {game.developers && game.developers.length > 0 && (
                        <span className="truncate">• {game.developers[0]}</span>
                      )}
                    </div>

                    {game.platforms && game.platforms.length > 0 && (
                      <p className="text-[11px] text-zinc-500 truncate mt-1">
                        {game.platforms.join(', ')}
                      </p>
                    )}
                  </div>

                  {/* Add button */}
                  <div className="mt-3">
                    {isAdded ? (
                      <span className="inline-flex items-center gap-1 px-3 py-1.5 rounded-lg bg-zinc-800 text-emerald-400 text-xs font-semibold border border-zinc-700">
                        <Check className="w-3.5 h-3.5 stroke-[3]" />
                        I din samling
                      </span>
                    ) : (
                      <button
                        onClick={() => handleAddGame(game)}
                        disabled={isAdding}
                        className="inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-lg bg-brand-red hover:bg-brand-redPressed text-white text-xs font-semibold shadow-md transition transform active:scale-95"
                      >
                        {isAdding ? (
                          <Loader2 className="w-3.5 h-3.5 animate-spin" />
                        ) : (
                          <Plus className="w-3.5 h-3.5" />
                        )}
                        <span>Lägg till ({selectedStatus})</span>
                      </button>
                    )}
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </main>
    </div>
  );
}
