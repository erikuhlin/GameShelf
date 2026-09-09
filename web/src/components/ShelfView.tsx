'use client';

import React from 'react';
import { Game } from '@/types/game';
import { StatusBadge } from './StatusBadge';
import { Star, Gamepad } from 'lucide-react';

interface ShelfViewProps {
  games: Game[];
  onSelectGame: (game: Game) => void;
}

export function ShelfView({ games, onSelectGame }: ShelfViewProps) {
  // Dela in samlingen i hyllrader (t.ex. 6 spel per hyllplan) så inget spel dupliceras
  const shelfRows = React.useMemo(() => {
    const rows: Game[][] = [];
    const chunkSize = 6;
    for (let i = 0; i < games.length; i += chunkSize) {
      rows.push(games.slice(i, i + chunkSize));
    }
    return rows;
  }, [games]);

  if (games.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-24 text-center px-4">
        <div className="w-16 h-16 rounded-2xl bg-zinc-900 border border-zinc-800 flex items-center justify-center text-zinc-600 mb-4">
          <Gamepad className="w-8 h-8" />
        </div>
        <h3 className="text-lg font-semibold text-zinc-300">Hyllan är tom</h3>
        <p className="text-sm text-zinc-500 max-w-sm mt-1">
          Inga spel matchar din sökning eller filter. Klicka på "Lägg till spel" för att söka i IGDB.
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-10 pb-16">
      {shelfRows.map((rowGames, rowIndex) => (
        <section key={`shelf-row-${rowIndex}`} className="relative">
          {/* Games on Shelf */}
          <div className="relative">
            <div className="flex items-end gap-3.5 sm:gap-5 overflow-x-auto pb-4 pt-4 sm:pt-6 px-2 sm:px-4 scrollbar-none">
              {rowGames.map((game) => (
                <div
                  key={game.id}
                  onClick={() => onSelectGame(game)}
                  className="w-28 sm:w-36 flex-shrink-0 cursor-pointer group flex flex-col items-center"
                >
                  {/* Game Box Art */}
                  <div className="relative w-full aspect-[3/4] rounded-lg overflow-hidden game-spine bg-zinc-800 border border-zinc-700/60 shadow-xl group-hover:border-zinc-500 transition duration-300">
                    {game.cover_url ? (
                      <img
                        src={game.cover_url}
                        alt={game.title}
                        className="w-full h-full object-cover group-hover:scale-105 transition duration-300"
                        loading="lazy"
                      />
                    ) : (
                      <div className="w-full h-full flex flex-col items-center justify-center p-3 text-center bg-gradient-to-b from-zinc-800 to-zinc-900">
                        <Gamepad className="w-8 h-8 text-zinc-600 mb-2" />
                        <span className="text-xs font-semibold text-zinc-300 line-clamp-3">
                          {game.title}
                        </span>
                      </div>
                    )}

                    {/* User Rating badge */}
                    {game.rating && (
                      <div className="absolute top-2 right-2 flex items-center gap-0.5 px-1.5 py-0.5 rounded bg-black/75 backdrop-blur-md text-amber-400 text-[10px] sm:text-[11px] font-bold border border-amber-500/30">
                        <Star className="w-2.5 h-2.5 fill-current" />
                        <span>{game.rating}</span>
                      </div>
                    )}

                    {/* Önskelista / Backlog märkning */}
                    {!game.is_owned ? (
                      <div className="absolute top-2 left-2 px-2 py-0.5 rounded-md bg-purple-950/90 backdrop-blur-md text-purple-300 text-[9px] sm:text-[10px] font-bold border border-purple-500/50 shadow-sm flex items-center gap-1">
                        <span>Önskelista</span>
                      </div>
                    ) : game.is_backlog ? (
                      <div className="absolute top-2 left-2 px-2 py-0.5 rounded-md bg-blue-950/90 backdrop-blur-md text-blue-300 text-[9px] sm:text-[10px] font-bold border border-blue-500/50 shadow-sm flex items-center gap-1">
                        <span>Backlog</span>
                      </div>
                    ) : null}
                  </div>

                  {/* Title & Platform label */}
                  <div className="w-full mt-2 sm:mt-2.5 text-center px-1">
                    <h4 className="text-xs sm:text-sm font-semibold text-zinc-200 group-hover:text-brand-red transition text-center line-clamp-2 min-h-[2.25rem] leading-tight">
                      {game.title}
                    </h4>
                    <p className="text-[10px] sm:text-xs text-zinc-500 truncate mt-0.5">
                      {game.platforms?.join(', ') || 'Okänd'}
                    </p>
                  </div>
                </div>
              ))}
            </div>

            {/* Wooden Shelf Plank Base */}
            <div className="w-full h-4 shelf-plank rounded-sm relative -mt-3 z-10"></div>
          </div>
        </section>
      ))}
    </div>
  );
}
