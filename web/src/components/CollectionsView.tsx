'use client';

import React, { useState } from 'react';
import { GameCollection, Game } from '@/types/game';
import { supabase } from '@/lib/supabase';
import { StatusBadge } from './StatusBadge';
import {
  FolderKanban,
  Plus,
  Trash2,
  ArrowLeft,
  Gamepad,
  Star,
  Search,
} from 'lucide-react';

interface CollectionsViewProps {
  collections: GameCollection[];
  games: Game[];
  onCreateCollection: (col: GameCollection) => void;
  onDeleteCollection: (id: string) => void;
  onSelectGame: (game: Game) => void;
}

export function CollectionsView({
  collections,
  games,
  onCreateCollection,
  onDeleteCollection,
  onSelectGame,
}: CollectionsViewProps) {
  const [selectedCollectionId, setSelectedCollectionId] = useState<string | null>(null);
  const [isCreating, setIsCreating] = useState(false);
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');

  const activeCollection = collections.find((c) => c.id === selectedCollectionId);

  const collectionGames = React.useMemo(() => {
    if (!activeCollection) return [];
    const idSet = new Set(activeCollection.game_ids || []);
    return games.filter((g) => idSet.has(g.id));
  }, [activeCollection, games]);

  const filteredCollectionGames = React.useMemo(() => {
    if (!searchQuery.trim()) return collectionGames;
    const q = searchQuery.toLowerCase();
    return collectionGames.filter(
      (g) =>
        g.title.toLowerCase().includes(q) ||
        g.developers?.some((d) => d.toLowerCase().includes(q)) ||
        g.platforms?.some((p) => p.toLowerCase().includes(q))
    );
  }, [collectionGames, searchQuery]);

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim()) return;

    setIsSubmitting(true);
    try {
      const payload = {
        name: name.trim(),
        description: description.trim(),
        game_ids: [],
      };

      const { data, error } = await supabase
        .from('collections')
        .insert([payload])
        .select()
        .single();

      if (error) {
        console.error('Failed to create collection:', error);
        const fallback: GameCollection = {
          id: crypto.randomUUID(),
          ...payload,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        };
        onCreateCollection(fallback);
      } else if (data) {
        onCreateCollection(data as GameCollection);
      }

      setName('');
      setDescription('');
      setIsCreating(false);
    } catch (err) {
      console.error('Error creating collection:', err);
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDelete = async (colId: string, e: React.MouseEvent) => {
    e.stopPropagation();
    if (!confirm('Är du säker på att du vill ta bort denna samling?')) return;

    try {
      await supabase.from('collections').delete().eq('id', colId);
      onDeleteCollection(colId);
      if (selectedCollectionId === colId) {
        setSelectedCollectionId(null);
      }
    } catch (err) {
      console.error('Error deleting collection:', err);
    }
  };

  // Om en specifik samling är vald: visa dess innehåll
  if (activeCollection) {
    return (
      <div className="space-y-6 pb-16 animate-in fade-in duration-200">
        {/* Top bar with back button */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 p-5 rounded-2xl bg-zinc-900/60 border border-zinc-800">
          <div className="flex items-start gap-4">
            <button
              onClick={() => setSelectedCollectionId(null)}
              className="p-2.5 rounded-xl bg-zinc-800 hover:bg-zinc-700 text-zinc-300 hover:text-white border border-zinc-700 transition flex items-center gap-1.5 text-xs font-semibold"
            >
              <ArrowLeft className="w-4 h-4" />
              <span>Alla samlingar</span>
            </button>

            <div>
              <div className="flex items-center gap-2.5">
                <h2 className="text-xl font-bold text-white">{activeCollection.name}</h2>
                <span className="text-xs px-2.5 py-0.5 rounded-full bg-brand-red/20 text-brand-red border border-brand-red/40 font-semibold">
                  {collectionGames.length} {collectionGames.length === 1 ? 'spel' : 'spel'}
                </span>
              </div>
              {activeCollection.description && (
                <p className="text-xs text-zinc-400 mt-1 max-w-xl">
                  {activeCollection.description}
                </p>
              )}
            </div>
          </div>

          {/* Search inside collection */}
          <div className="relative min-w-[200px]">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-500" />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Filtrera i samlingen..."
              className="w-full pl-9 pr-4 py-2 text-xs bg-zinc-950/80 border border-zinc-800 rounded-xl text-zinc-100 placeholder-zinc-500 focus:outline-none focus:border-brand-red transition"
            />
          </div>
        </div>

        {/* Collection Games Grid */}
        {filteredCollectionGames.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-20 text-center px-4 rounded-2xl border border-dashed border-zinc-800 bg-zinc-950/40">
            <div className="w-14 h-14 rounded-2xl bg-zinc-900 border border-zinc-800 flex items-center justify-center text-zinc-600 mb-3">
              <Gamepad className="w-7 h-7" />
            </div>
            <h3 className="text-base font-semibold text-zinc-300">Inga spel i denna samling än</h3>
            <p className="text-xs text-zinc-500 max-w-sm mt-1">
              Öppna ett spel i biblioteket och välj att lägga till det i "{activeCollection.name}".
            </p>
          </div>
        ) : (
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-5">
            {filteredCollectionGames.map((game) => (
              <div
                key={game.id}
                onClick={() => onSelectGame(game)}
                className="group cursor-pointer flex flex-col bg-zinc-900/60 border border-zinc-800/80 hover:border-zinc-700 rounded-xl overflow-hidden shadow-md hover:shadow-xl transition duration-200"
              >
                <div className="relative w-full aspect-[3/4] bg-zinc-800 overflow-hidden">
                  {game.cover_url ? (
                    <img
                      src={game.cover_url}
                      alt={game.title}
                      className="w-full h-full object-cover group-hover:scale-105 transition duration-300"
                      loading="lazy"
                    />
                  ) : (
                    <div className="w-full h-full flex flex-col items-center justify-center p-3 text-center bg-zinc-800">
                      <Gamepad className="w-8 h-8 text-zinc-600 mb-2" />
                      <span className="text-xs text-zinc-400 font-medium line-clamp-2">
                        {game.title}
                      </span>
                    </div>
                  )}

                  <div className="absolute top-2 left-2">
                    <StatusBadge status={game.status} size="sm" />
                  </div>

                  {game.rating && (
                    <div className="absolute top-2 right-2 flex items-center gap-1 px-1.5 py-0.5 rounded-md bg-black/80 backdrop-blur-md text-amber-400 text-xs font-bold border border-amber-500/30">
                      <Star className="w-3 h-3 fill-current" />
                      <span>{game.rating}</span>
                    </div>
                  )}
                </div>

                <div className="p-3">
                  <h3 className="font-semibold text-xs text-zinc-100 group-hover:text-brand-red transition line-clamp-1">
                    {game.title}
                  </h3>
                  <p className="text-[11px] text-zinc-500 mt-0.5 truncate">
                    {game.platforms?.join(', ') || 'Okänd plattform'}
                  </p>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    );
  }

  // Översikt över alla samlingar
  return (
    <div className="space-y-8 pb-16 animate-in fade-in duration-200">
      {/* Header & Create Button */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2.5">
            <h2 className="text-2xl font-bold text-white tracking-tight">Samlingar</h2>
            <span className="text-xs px-2.5 py-0.5 rounded-full bg-zinc-800 text-zinc-400 border border-zinc-700">
              {collections.length} {collections.length === 1 ? 'samling' : 'samlingar'}
            </span>
          </div>
          <p className="text-xs text-zinc-400 mt-1">
            Skapa egna temalistor som Favoriter, Spelminnen, Backlog eller Co-op
          </p>
        </div>

        <button
          onClick={() => setIsCreating(!isCreating)}
          className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-brand-red hover:bg-brand-redPressed text-white text-xs font-semibold shadow-lg shadow-brand-red/20 transition self-start sm:self-auto"
        >
          <Plus className="w-4 h-4" />
          <span>{isCreating ? 'Avbryt' : 'Ny samling'}</span>
        </button>
      </div>

      {/* Inline Create Collection Box */}
      {isCreating && (
        <form
          onSubmit={handleCreate}
          className="p-5 rounded-2xl bg-zinc-900/80 border border-zinc-700/80 space-y-4 max-w-xl shadow-xl animate-in slide-in-from-top-2 duration-200"
        >
          <h3 className="text-sm font-bold text-white flex items-center gap-2">
            <FolderKanban className="w-4 h-4 text-brand-red" />
            <span>Skapa en ny samling</span>
          </h3>

          <div className="space-y-3">
            <div>
              <label className="block text-xs font-medium text-zinc-400 mb-1">Namn på samlingen *</label>
              <input
                type="text"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="T.ex. Mina 10/10 favoriter, Nintendo-nostalgi, RPG-pärlor..."
                className="w-full bg-zinc-950 border border-zinc-700 rounded-xl px-3.5 py-2.5 text-sm text-zinc-100 placeholder-zinc-500 focus:outline-none focus:border-brand-red transition"
                autoFocus
              />
            </div>

            <div>
              <label className="block text-xs font-medium text-zinc-400 mb-1">Beskrivning (valfritt)</label>
              <input
                type="text"
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                placeholder="Kort beskrivning av vad samlingen innehåller..."
                className="w-full bg-zinc-950 border border-zinc-700 rounded-xl px-3.5 py-2.5 text-xs text-zinc-100 placeholder-zinc-500 focus:outline-none focus:border-brand-red transition"
              />
            </div>
          </div>

          <div className="flex items-center gap-2 pt-1">
            <button
              type="submit"
              disabled={isSubmitting || !name.trim()}
              className="px-4 py-2 bg-brand-red hover:bg-brand-redPressed disabled:bg-zinc-800 text-white rounded-xl text-xs font-semibold transition"
            >
              {isSubmitting ? 'Skapar...' : 'Spara samling'}
            </button>
            <button
              type="button"
              onClick={() => setIsCreating(false)}
              className="px-4 py-2 bg-zinc-800 hover:bg-zinc-700 text-zinc-300 rounded-xl text-xs font-medium transition"
            >
              Avbryt
            </button>
          </div>
        </form>
      )}

      {/* Collections Grid */}
      {collections.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-24 text-center px-4 rounded-2xl border border-dashed border-zinc-800 bg-zinc-950/40">
          <div className="w-16 h-16 rounded-2xl bg-zinc-900 border border-zinc-800 flex items-center justify-center text-zinc-600 mb-4">
            <FolderKanban className="w-8 h-8 text-brand-red" />
          </div>
          <h3 className="text-lg font-semibold text-zinc-200 mb-1">Inga samlingar skapade ännu</h3>
          <p className="text-xs text-zinc-400 max-w-sm mb-5">
            Skapa din första samling för att gruppera dina spel efter genre, minnen eller favoriter.
          </p>
          <button
            onClick={() => setIsCreating(true)}
            className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-brand-red hover:bg-brand-redPressed text-white text-xs font-semibold transition shadow-md"
          >
            <Plus className="w-4 h-4" />
            <span>Skapa samling nu</span>
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
          {collections.map((col) => {
            const colGames = games.filter((g) => col.game_ids?.includes(g.id));
            const previewCovers = colGames.slice(0, 4);

            return (
              <div
                key={col.id}
                onClick={() => setSelectedCollectionId(col.id)}
                className="group cursor-pointer flex flex-col bg-zinc-900/60 hover:bg-zinc-900 border border-zinc-800 hover:border-zinc-700 rounded-2xl overflow-hidden shadow-lg hover:shadow-2xl transition duration-200"
              >
                {/* Collage preview of covers */}
                <div className="relative h-44 bg-zinc-950 border-b border-zinc-800/80 overflow-hidden flex items-center justify-center p-3">
                  {previewCovers.length > 0 ? (
                    <div className="flex items-center justify-center -space-x-8 group-hover:-space-x-6 transition-all duration-300">
                      {previewCovers.map((g, idx) => (
                        <div
                          key={g.id}
                          className="w-24 aspect-[3/4] rounded-lg overflow-hidden border-2 border-zinc-900 shadow-2xl transform transition duration-300"
                          style={{
                            transform: `rotate(${idx === 0 ? '-6deg' : idx === 1 ? '2deg' : idx === 2 ? '8deg' : '0deg'}) scale(${idx === 1 ? '1.05' : '1'})`,
                            zIndex: 10 - idx,
                          }}
                        >
                          {g.cover_url ? (
                            <img src={g.cover_url} alt={g.title} className="w-full h-full object-cover" />
                          ) : (
                            <div className="w-full h-full bg-zinc-800 flex items-center justify-center p-2 text-center text-[10px] text-zinc-400">
                              {g.title}
                            </div>
                          )}
                        </div>
                      ))}
                    </div>
                  ) : (
                    <div className="flex flex-col items-center justify-center text-zinc-600">
                      <FolderKanban className="w-10 h-10 mb-2 opacity-50" />
                      <span className="text-xs">Tom samling</span>
                    </div>
                  )}

                  {/* Top corner count badge */}
                  <div className="absolute top-3 right-3 px-2.5 py-1 rounded-full bg-black/75 backdrop-blur-md border border-zinc-700/60 text-xs font-semibold text-zinc-300">
                    {col.game_ids?.length || 0} spel
                  </div>
                </div>

                {/* Info & Action */}
                <div className="p-4 flex-1 flex flex-col justify-between">
                  <div>
                    <h3 className="text-base font-bold text-zinc-100 group-hover:text-brand-red transition">
                      {col.name}
                    </h3>
                    <p className="text-xs text-zinc-400 mt-1 line-clamp-2 min-h-[32px]">
                      {col.description || 'Ingen beskrivning.'}
                    </p>
                  </div>

                  <div className="flex items-center justify-between pt-4 mt-2 border-t border-zinc-800/60">
                    <span className="text-xs text-brand-red font-medium group-hover:underline">
                      Öppna samling →
                    </span>

                    <button
                      type="button"
                      onClick={(e) => handleDelete(col.id, e)}
                      className="p-1.5 rounded-lg text-zinc-500 hover:text-red-400 hover:bg-red-950/40 transition"
                      title="Ta bort samling"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
