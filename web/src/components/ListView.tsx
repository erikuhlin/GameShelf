'use client';

import React from 'react';
import { Game } from '@/types/game';
import { StatusBadge } from './StatusBadge';
import { Star, Gamepad, Clock, CheckSquare } from 'lucide-react';

interface ListViewProps {
  games: Game[];
  onSelectGame: (game: Game) => void;
}

export function ListView({ games, onSelectGame }: ListViewProps) {
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
    <div className="overflow-x-auto rounded-xl border border-zinc-800 bg-zinc-900/40 mb-16">
      <table className="w-full text-left text-sm text-zinc-300">
        <thead className="bg-zinc-900/90 text-xs uppercase tracking-wider text-zinc-400 border-b border-zinc-800">
          <tr>
            <th className="py-3 px-4 w-14">Omslag</th>
            <th className="py-3 px-4">Titel</th>
            <th className="py-3 px-4 hidden md:table-cell">Plattform</th>
            <th className="py-3 px-4 hidden sm:table-cell">År</th>
            <th className="py-3 px-4">Status</th>
            <th className="py-3 px-4 text-center">Betyg</th>
            <th className="py-3 px-4 hidden lg:table-cell">Speltid</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-zinc-800/60">
          {games.map((game) => (
            <tr
              key={game.id}
              onClick={() => onSelectGame(game)}
              className="cursor-pointer hover:bg-zinc-800/50 transition group"
            >
              {/* Cover thumbnail */}
              <td className="py-2.5 px-4">
                <div className="w-10 h-13 rounded overflow-hidden bg-zinc-800 border border-zinc-700 flex-shrink-0 aspect-[3/4]">
                  {game.cover_url ? (
                    <img
                      src={game.cover_url}
                      alt={game.title}
                      className="w-full h-full object-cover"
                      loading="lazy"
                    />
                  ) : (
                    <div className="w-full h-full flex items-center justify-center">
                      <Gamepad className="w-4 h-4 text-zinc-600" />
                    </div>
                  )}
                </div>
              </td>

              {/* Title & Developer */}
              <td className="py-2.5 px-4 font-medium text-zinc-100 group-hover:text-brand-red transition">
                <div>{game.title}</div>
                {game.developers && game.developers.length > 0 && (
                  <div className="text-xs text-zinc-500 font-normal">{game.developers[0]}</div>
                )}
              </td>

              {/* Platform */}
              <td className="py-2.5 px-4 text-zinc-400 hidden md:table-cell text-xs">
                {game.platforms && game.platforms.length > 0 ? (
                  <div className="flex flex-wrap gap-1 max-w-[200px]">
                    {game.platforms.slice(0, 2).map((p) => (
                      <span
                        key={p}
                        className="px-1.5 py-0.5 rounded bg-zinc-800 text-zinc-300 text-[11px] border border-zinc-700"
                      >
                        {p}
                      </span>
                    ))}
                    {game.platforms.length > 2 && (
                      <span className="text-zinc-500 text-[11px]">
                        +{game.platforms.length - 2}
                      </span>
                    )}
                  </div>
                ) : (
                  '—'
                )}
              </td>

              {/* Release Year */}
              <td className="py-2.5 px-4 text-zinc-400 hidden sm:table-cell text-xs">
                {game.release_year || '—'}
              </td>

              {/* Status */}
              <td className="py-2.5 px-4">
                <StatusBadge game={game} size="sm" />
              </td>

              {/* Rating */}
              <td className="py-2.5 px-4 text-center">
                {game.rating ? (
                  <div className="inline-flex items-center gap-1 text-amber-400 font-bold text-xs bg-amber-950/40 border border-amber-500/30 px-2 py-0.5 rounded">
                    <Star className="w-3 h-3 fill-current" />
                    <span>{game.rating}</span>
                  </div>
                ) : (
                  <span className="text-zinc-600 text-xs">—</span>
                )}
              </td>

              {/* Playtime */}
              <td className="py-2.5 px-4 text-zinc-400 hidden lg:table-cell text-xs">
                {game.estimated_hours ? (
                  <div className="flex items-center gap-1">
                    <Clock className="w-3.5 h-3.5 text-zinc-500" />
                    <span>ca {game.estimated_hours}h</span>
                  </div>
                ) : (
                  '—'
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
