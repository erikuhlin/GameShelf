'use client';

import React from 'react';
import { Game } from '@/types/game';
import { StatusBadge } from './StatusBadge';
import { Star, Gamepad, Clock, CheckSquare } from 'lucide-react';

interface GridViewProps {
  games: Game[];
  onSelectGame: (game: Game) => void;
}

export function GridView({ games, onSelectGame }: GridViewProps) {
  if (games.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-24 text-center px-4">
        <div className="w-16 h-16 rounded-2xl bg-zinc-900 border border-zinc-800 flex items-center justify-center text-zinc-600 mb-4">
          <Gamepad className="w-8 h-8" />
        </div>
        <h3 className="text-lg font-semibold text-zinc-300">Inga spel hittades</h3>
        <p className="text-sm text-zinc-500 max-w-sm mt-1">
          Lägg till ditt första spel genom att söka i IGDB.
        </p>
      </div>
    );
  }

  return (
    <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-5 pb-16">
      {games.map((game) => {
        const completedTodos = game.todos?.filter((t) => t.isDone).length || 0;
        const totalTodos = game.todos?.length || 0;

        return (
          <div
            key={game.id}
            onClick={() => onSelectGame(game)}
            className="group cursor-pointer flex flex-col bg-zinc-900/60 border border-zinc-800/80 hover:border-zinc-700 rounded-xl overflow-hidden shadow-md hover:shadow-xl hover:shadow-brand-red/5 transition duration-200"
          >
            {/* Cover Art */}
            <div className="relative w-full aspect-[3/4] bg-zinc-800 overflow-hidden">
              {game.cover_url ? (
                <img
                  src={game.cover_url}
                  alt={game.title}
                  className="w-full h-full object-cover group-hover:scale-105 transition duration-300"
                  loading="lazy"
                />
              ) : (
                <div className="w-full h-full flex flex-col items-center justify-center p-4 text-center bg-zinc-800">
                  <Gamepad className="w-10 h-10 text-zinc-600 mb-2" />
                  <span className="text-xs text-zinc-400 font-medium line-clamp-2">
                    {game.title}
                  </span>
                </div>
              )}

              {/* Status Badge in Corner */}
              <div className="absolute top-2 left-2">
                <StatusBadge status={game.status} size="sm" />
              </div>

              {/* Rating badge */}
              {game.rating && (
                <div className="absolute top-2 right-2 flex items-center gap-1 px-2 py-0.5 rounded-md bg-black/80 backdrop-blur-md text-amber-400 text-xs font-bold border border-amber-500/30">
                  <Star className="w-3 h-3 fill-current" />
                  <span>{game.rating}/10</span>
                </div>
              )}

              {/* Todos progress badge if has todos */}
              {totalTodos > 0 && (
                <div className="absolute bottom-2 right-2 flex items-center gap-1 px-2 py-0.5 rounded bg-black/75 backdrop-blur-md text-zinc-300 text-xs border border-zinc-700">
                  <CheckSquare className="w-3 h-3 text-emerald-400" />
                  <span>
                    {completedTodos}/{totalTodos}
                  </span>
                </div>
              )}
            </div>

            {/* Content Details */}
            <div className="p-3 flex flex-col flex-1 justify-between gap-2">
              <div>
                <h3 className="font-semibold text-sm text-zinc-100 group-hover:text-brand-red transition line-clamp-1">
                  {game.title}
                </h3>
                <div className="flex items-center gap-2 mt-1 text-xs text-zinc-400">
                  {game.release_year && <span>{game.release_year}</span>}
                  {game.platforms && game.platforms.length > 0 && (
                    <>
                      <span>•</span>
                      <span className="truncate">{game.platforms[0]}</span>
                    </>
                  )}
                </div>
              </div>

              {game.estimated_hours && (
                <div className="flex items-center gap-1 text-[11px] text-zinc-400">
                  <Clock className="w-3 h-3" />
                  <span>ca {game.estimated_hours}h</span>
                </div>
              )}
            </div>
          </div>
        );
      })}
    </div>
  );
}
