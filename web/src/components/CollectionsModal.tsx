'use client';

import React, { useState } from 'react';
import { GameCollection, Game } from '@/types/game';
import { supabase } from '@/lib/supabase';
import { X, Plus, FolderKanban, Trash2, Check, Bookmark } from 'lucide-react';

interface CollectionsModalProps {
  isOpen: boolean;
  onClose: () => void;
  collections: GameCollection[];
  games: Game[];
  onCreateCollection: (col: GameCollection) => void;
  onDeleteCollection: (id: string) => void;
  selectedCollectionId: string | null;
  onSelectCollection: (id: string | null) => void;
}

export function CollectionsModal({
  isOpen,
  onClose,
  collections,
  games,
  onCreateCollection,
  onDeleteCollection,
  selectedCollectionId,
  onSelectCollection,
}: CollectionsModalProps) {
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [isCreating, setIsCreating] = useState(false);

  if (!isOpen) return null;

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim()) return;

    setIsCreating(true);
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
        // Fallback
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
    } catch (err) {
      console.error('Error creating collection:', err);
    } finally {
      setIsCreating(false);
    }
  };

  const handleDelete = async (colId: string) => {
    try {
      await supabase.from('collections').delete().eq('id', colId);
      onDeleteCollection(colId);
      if (selectedCollectionId === colId) {
        onSelectCollection(null);
      }
    } catch (err) {
      console.error('Error deleting collection:', err);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm animate-in fade-in duration-200">
      <div className="bg-[#16181f] border border-zinc-800 rounded-2xl w-full max-w-xl max-h-[85vh] flex flex-col shadow-2xl overflow-hidden">
        {/* Header */}
        <div className="p-5 border-b border-zinc-800 flex items-center justify-between">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-lg bg-zinc-800 border border-zinc-700 flex items-center justify-center text-zinc-300">
              <FolderKanban className="w-4 h-4" />
            </div>
            <div>
              <h3 className="font-bold text-white text-base">Mina Samlingar</h3>
              <p className="text-xs text-zinc-400">Organisera dina spel i anpassade listor</p>
            </div>
          </div>

          <button
            onClick={onClose}
            className="p-1.5 rounded-lg bg-zinc-800/80 hover:bg-zinc-700 text-zinc-400 hover:text-white transition"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto p-5 space-y-6">
          {/* Create new collection form */}
          <form onSubmit={handleCreate} className="p-4 rounded-xl bg-zinc-900/60 border border-zinc-800 space-y-3">
            <h4 className="text-xs font-semibold uppercase tracking-wider text-zinc-400">
              Skapa ny samling
            </h4>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Namn på samlingen (t.ex. Nostalgi, Coop-favoriter)..."
              className="w-full bg-zinc-950 border border-zinc-700 rounded-lg px-3 py-2 text-sm text-zinc-100 placeholder-zinc-500 focus:outline-none focus:border-brand-red"
            />
            <input
              type="text"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="Kort beskrivning (valfritt)..."
              className="w-full bg-zinc-950 border border-zinc-700 rounded-lg px-3 py-2 text-xs text-zinc-100 placeholder-zinc-500 focus:outline-none focus:border-brand-red"
            />
            <button
              type="submit"
              disabled={isCreating || !name.trim()}
              className="w-full py-2 bg-brand-red hover:bg-brand-redPressed disabled:bg-zinc-800 text-white rounded-lg text-xs font-semibold flex items-center justify-center gap-1.5 transition"
            >
              <Plus className="w-3.5 h-3.5" />
              <span>{isCreating ? 'Skapar...' : 'Skapa samling'}</span>
            </button>
          </form>

          {/* Collection list */}
          <div>
            <h4 className="text-xs font-semibold uppercase tracking-wider text-zinc-400 mb-3">
              Befintliga samlingar ({collections.length})
            </h4>

            {collections.length === 0 ? (
              <p className="text-xs text-zinc-500 py-4 text-center">
                Du har inga samlingar ännu.
              </p>
            ) : (
              <div className="space-y-2">
                {collections.map((col) => {
                  const gameCount = col.game_ids?.length || 0;
                  const isSelected = selectedCollectionId === col.id;

                  return (
                    <div
                      key={col.id}
                      className={`flex items-center justify-between p-3 rounded-xl border transition ${
                        isSelected
                          ? 'bg-brand-red/10 border-brand-red/50 text-white'
                          : 'bg-zinc-900/60 border-zinc-800 text-zinc-300 hover:bg-zinc-900'
                      }`}
                    >
                      <div
                        onClick={() => {
                          onSelectCollection(isSelected ? null : col.id);
                          onClose();
                        }}
                        className="flex-1 cursor-pointer"
                      >
                        <div className="flex items-center gap-2">
                          <Bookmark
                            className={`w-4 h-4 ${
                              isSelected ? 'text-brand-red fill-brand-red' : 'text-zinc-500'
                            }`}
                          />
                          <span className="font-semibold text-sm">{col.name}</span>
                          <span className="text-xs px-2 py-0.5 rounded-full bg-zinc-800 text-zinc-400 border border-zinc-700">
                            {gameCount} {gameCount === 1 ? 'spel' : 'spel'}
                          </span>
                        </div>
                        {col.description && (
                          <p className="text-xs text-zinc-500 mt-1 pl-6">
                            {col.description}
                          </p>
                        )}
                      </div>

                      <div className="flex items-center gap-1.5 ml-3">
                        <button
                          type="button"
                          onClick={() => handleDelete(col.id)}
                          className="p-1.5 rounded-lg text-zinc-500 hover:text-red-400 hover:bg-red-950/30 transition"
                          title="Ta bort samling"
                        >
                          <Trash2 className="w-3.5 h-3.5" />
                        </button>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
