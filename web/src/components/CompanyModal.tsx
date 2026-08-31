'use client';

import React, { useState, useEffect, useMemo } from 'react';
import {
  X,
  Building2,
  Calendar,
  Globe,
  Star,
  Plus,
  Check,
  Search,
  ArrowUpDown,
  Library,
  Layers,
  Sparkles,
} from 'lucide-react';
import { Game } from '@/types/game';
import { StatusBadge } from './StatusBadge';

interface CompanyGameItem {
  id: number;
  name: string;
  summary: string;
  coverUrl: string | null;
  firstReleaseDate: number | null;
  releaseYear: number | null;
  totalRating: number | null;
  genres: string[];
  platforms: string[];
  isDeveloper: boolean;
  isPublisher: boolean;
}

interface CompanyData {
  id: number;
  name: string;
  description: string;
  logoUrl: string | null;
  startDate: number | null;
  country: number | null;
  developedCount: number;
  publishedCount: number;
}

interface CompanyModalProps {
  companyId?: number | null;
  companyName?: string;
  role?: 'developer' | 'publisher' | 'company';
  isOpen: boolean;
  onClose: () => void;
  libraryGames: Game[];
  onAddGame: (game: {
    title: string;
    igdbId: number;
    coverUrl?: string | null;
    releaseYear?: number | null;
    genres: string[];
    developers: string[];
    platforms: string[];
  }) => void;
  onSelectGame?: (igdbId: number) => void;
}

export function CompanyModal({
  companyId,
  companyName,
  role = 'company',
  isOpen,
  onClose,
  libraryGames,
  onAddGame,
  onSelectGame,
}: CompanyModalProps) {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [company, setCompany] = useState<CompanyData | null>(null);
  const [games, setGames] = useState<CompanyGameItem[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [sortBy, setSortBy] = useState<'year' | 'rating' | 'name'>('year');

  useEffect(() => {
    if (!isOpen) return;
    const identifier = companyId && companyId > 0 ? String(companyId) : companyName?.trim();
    if (!identifier) return;

    let isMounted = true;
    setLoading(true);
    setError(null);

    fetch(`/api/igdb/companies/${encodeURIComponent(identifier)}`)
      .then((res) => {
        if (!res.ok) throw new Error('Kunde inte läsa in företagsdetaljer');
        return res.json();
      })
      .then((data) => {
        if (isMounted) {
          setCompany(data.company);
          setGames(data.games || []);
          setLoading(false);
        }
      })
      .catch((err) => {
        if (isMounted) {
          setError(err.message || 'Ett fel uppstod vid hämtning');
          setLoading(false);
        }
      });

    return () => {
      isMounted = false;
    };
  }, [isOpen, companyId]);

  // Spel i användarens bibliotek som matchar studion
  const ownedMatchingGames = useMemo(() => {
    const targetName = (company?.name || companyName || '').toLowerCase().trim();
    if (!targetName) return [];

    return libraryGames.filter((g) => {
      // Kolla om spelets ID matchar något av studions IGDB-spel
      if (g.igdb_id && games.some((cg) => cg.id === g.igdb_id)) {
        return true;
      }
      // Eller kolla om utvecklarnamnet matchar
      return (g.developers || []).some((dev) =>
        dev.toLowerCase().includes(targetName) || targetName.includes(dev.toLowerCase())
      );
    });
  }, [libraryGames, games, company, companyName]);

  // Filtrerade och sorterade spel från IGDB-katalogen
  const filteredGames = useMemo(() => {
    let result = [...games];

    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase().trim();
      result = result.filter(
        (g) =>
          g.name.toLowerCase().includes(q) ||
          g.genres.some((gen) => gen.toLowerCase().includes(q)) ||
          g.platforms.some((p) => p.toLowerCase().includes(q))
      );
    }

    if (sortBy === 'year') {
      result.sort((a, b) => (b.releaseYear || 0) - (a.releaseYear || 0));
    } else if (sortBy === 'rating') {
      result.sort((a, b) => (b.totalRating || 0) - (a.totalRating || 0));
    } else if (sortBy === 'name') {
      result.sort((a, b) => a.name.localeCompare(b.name));
    }

    return result;
  }, [games, searchQuery, sortBy]);

  if (!isOpen) return null;

  const displayName = company?.name || companyName || 'Studio';
  const roleLabel =
    role === 'developer' ? 'Utvecklare' : role === 'publisher' ? 'Utgivare' : 'Spelstudio';

  return (
    <div className="fixed inset-0 z-[70] flex items-center justify-center p-4 sm:p-6 bg-black/80 backdrop-blur-md animate-in fade-in duration-200">
      <div className="relative w-full max-w-4xl max-h-[90vh] bg-[#121319] border border-zinc-800 rounded-3xl shadow-2xl flex flex-col overflow-hidden">
        {/* Header bar */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-zinc-800/80 bg-zinc-950/60 shrink-0">
          <div className="flex items-center gap-2.5">
            <Building2 className="w-5 h-5 text-brand-red" />
            <span className="text-xs font-bold uppercase tracking-wider text-zinc-400">
              {roleLabel}
            </span>
          </div>
          <button
            onClick={onClose}
            className="p-2 rounded-xl text-zinc-400 hover:text-white hover:bg-zinc-800 transition"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Scrollable body */}
        <div className="flex-1 overflow-y-auto p-6 space-y-8 custom-scrollbar">
          {loading ? (
            <div className="flex flex-col items-center justify-center py-24 space-y-4">
              <div className="w-8 h-8 border-2 border-brand-red border-t-transparent rounded-full animate-spin" />
              <p className="text-sm font-medium text-zinc-400">Hämtar katalog för {displayName}...</p>
            </div>
          ) : error ? (
            <div className="p-8 text-center bg-rose-950/20 border border-rose-900/40 rounded-2xl">
              <p className="text-sm text-rose-300 mb-4">{error}</p>
              <button
                onClick={onClose}
                className="px-4 py-2 bg-zinc-800 hover:bg-zinc-700 text-white rounded-xl text-xs font-bold"
              >
                Stäng
              </button>
            </div>
          ) : (
            <>
              {/* Studio Hero Profile */}
              <div className="flex flex-col sm:flex-row items-start sm:items-center gap-5 p-6 bg-gradient-to-br from-zinc-900/90 to-zinc-950 border border-zinc-800/80 rounded-2xl">
                {company?.logoUrl ? (
                  <div className="w-20 h-20 rounded-2xl bg-white p-2.5 flex items-center justify-center shadow-lg shrink-0">
                    <img
                      src={company.logoUrl}
                      alt={displayName}
                      className="max-h-full max-w-full object-contain"
                    />
                  </div>
                ) : (
                  <div className="w-20 h-20 rounded-2xl bg-gradient-to-tr from-brand-red to-rose-600 flex items-center justify-center text-white text-2xl font-black shadow-lg shrink-0">
                    {displayName.charAt(0)}
                  </div>
                )}

                <div className="space-y-1.5 flex-1 min-w-0">
                  <div className="flex items-center gap-3 flex-wrap">
                    <h2 className="text-2xl font-black tracking-tight text-white">{displayName}</h2>
                    <span className="px-2.5 py-0.5 rounded-full text-xs font-bold bg-brand-red/15 text-brand-red border border-brand-red/30">
                      {roleLabel}
                    </span>
                  </div>

                  {company?.description && (
                    <p className="text-xs text-zinc-300 line-clamp-3 leading-relaxed">
                      {company.description}
                    </p>
                  )}

                  <div className="flex items-center gap-4 text-xs text-zinc-400 pt-1">
                    {company?.startDate && (
                      <div className="flex items-center gap-1.5">
                        <Calendar className="w-3.5 h-3.5 text-zinc-400" />
                        <span>Grundat {new Date(company.startDate * 1000).getFullYear()}</span>
                      </div>
                    )}
                    <div className="flex items-center gap-1.5">
                      <Layers className="w-3.5 h-3.5 text-zinc-400" />
                      <span>{games.length} spel i katalogen</span>
                    </div>
                  </div>
                </div>
              </div>

              {/* Sektion 1: I ditt bibliotek */}
              {ownedMatchingGames.length > 0 && (
                <div className="space-y-4">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <Library className="w-4 h-4 text-emerald-400" />
                      <h3 className="text-base font-bold text-white">I ditt bibliotek</h3>
                      <span className="px-2 py-0.5 rounded-full bg-emerald-500/15 text-emerald-400 text-xs font-bold">
                        {ownedMatchingGames.length}
                      </span>
                    </div>
                  </div>

                  <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-4">
                    {ownedMatchingGames.map((game) => (
                      <div
                        key={game.id}
                        onClick={() => game.igdb_id && onSelectGame?.(game.igdb_id)}
                        className="group relative bg-zinc-900/70 hover:bg-zinc-800/80 border border-zinc-800 hover:border-zinc-700 rounded-2xl overflow-hidden cursor-pointer transition shadow-sm hover:shadow-lg"
                      >
                        <div className="relative aspect-[3/4] bg-zinc-950 overflow-hidden">
                          {game.cover_url ? (
                            <img
                              src={game.cover_url}
                              alt={game.title}
                              className="w-full h-full object-cover group-hover:scale-105 transition duration-300"
                            />
                          ) : (
                            <div className="w-full h-full flex items-center justify-center p-3 text-center text-xs font-bold text-zinc-400">
                              {game.title}
                            </div>
                          )}

                          <div className="absolute top-2 left-2">
                            <StatusBadge status={game.status} />
                          </div>

                          {game.rating && game.rating > 0 && (
                            <div className="absolute top-2 right-2 px-1.5 py-0.5 rounded-md bg-black/80 backdrop-blur-md text-[11px] font-bold text-amber-400 flex items-center gap-1 border border-amber-500/20">
                              <Star className="w-3 h-3 fill-amber-400 text-amber-400" />
                              <span>{game.rating}/10</span>
                            </div>
                          )}
                        </div>

                        <div className="p-3">
                          <h4 className="text-xs font-bold text-zinc-100 truncate group-hover:text-white">
                            {game.title}
                          </h4>
                          {game.release_year && (
                            <span className="text-[11px] text-zinc-400 font-medium">
                              {game.release_year}
                            </span>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* Sektion 2: Alla spel från studion */}
              <div className="space-y-4">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                  <div className="flex items-center gap-2">
                    <Sparkles className="w-4 h-4 text-brand-red" />
                    <h3 className="text-base font-bold text-white">Alla spel från {displayName}</h3>
                    <span className="px-2 py-0.5 rounded-full bg-zinc-800 text-zinc-400 text-xs font-bold">
                      {filteredGames.length}
                    </span>
                  </div>

                  {/* Sök och sortering */}
                  <div className="flex items-center gap-2">
                    <div className="relative">
                      <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-zinc-400" />
                      <input
                        type="text"
                        placeholder="Filtrera katalog..."
                        value={searchQuery}
                        onChange={(e) => setSearchQuery(e.target.value)}
                        className="pl-8 pr-3 py-1.5 bg-zinc-900 border border-zinc-800 focus:border-zinc-700 rounded-xl text-xs text-white placeholder-zinc-400 outline-none w-40 sm:w-48"
                      />
                    </div>

                    <div className="flex items-center gap-1 bg-zinc-900 border border-zinc-800 rounded-xl p-0.5">
                      <button
                        onClick={() => setSortBy('year')}
                        className={`px-2.5 py-1 rounded-lg text-[11px] font-semibold transition ${
                          sortBy === 'year'
                            ? 'bg-zinc-800 text-white'
                            : 'text-zinc-400 hover:text-zinc-200'
                        }`}
                        title="Sortera efter utgivningsår"
                      >
                        År
                      </button>
                      <button
                        onClick={() => setSortBy('rating')}
                        className={`px-2.5 py-1 rounded-lg text-[11px] font-semibold transition ${
                          sortBy === 'rating'
                            ? 'bg-zinc-800 text-white'
                            : 'text-zinc-400 hover:text-zinc-200'
                        }`}
                        title="Sortera efter betyg"
                      >
                        Betyg
                      </button>
                      <button
                        onClick={() => setSortBy('name')}
                        className={`px-2.5 py-1 rounded-lg text-[11px] font-semibold transition ${
                          sortBy === 'name'
                            ? 'bg-zinc-800 text-white'
                            : 'text-zinc-400 hover:text-zinc-200'
                        }`}
                        title="Sortera alfabetiskt"
                      >
                        Namn
                      </button>
                    </div>
                  </div>
                </div>

                {filteredGames.length === 0 ? (
                  <div className="p-12 text-center bg-zinc-950/40 border border-zinc-800/60 rounded-2xl">
                    <p className="text-sm text-zinc-400">Inga spel matchade din sökning.</p>
                  </div>
                ) : (
                  <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-3.5">
                    {filteredGames.map((g) => {
                      const inLibrary = libraryGames.some((lg) => lg.igdb_id === g.id);

                      return (
                        <div
                          key={g.id}
                          className="group relative bg-zinc-900/60 hover:bg-zinc-800/80 border border-zinc-800 hover:border-zinc-700 rounded-2xl overflow-hidden transition flex flex-col"
                        >
                          {/* Omslag */}
                          <div
                            onClick={() => onSelectGame?.(g.id)}
                            className="relative aspect-[3/4] bg-zinc-950 cursor-pointer overflow-hidden"
                          >
                            {g.coverUrl ? (
                              <img
                                src={g.coverUrl}
                                alt={g.name}
                                className="w-full h-full object-cover group-hover:scale-105 transition duration-300"
                              />
                            ) : (
                              <div className="w-full h-full flex items-center justify-center p-2 text-center text-xs font-bold text-zinc-400">
                                {g.name}
                              </div>
                            )}

                            {/* Betyg */}
                            {g.totalRating && g.totalRating > 0 && (
                              <div className="absolute top-2 right-2 px-1.5 py-0.5 rounded-md bg-black/80 backdrop-blur-md text-[10px] font-bold text-amber-400 flex items-center gap-1 border border-amber-500/20">
                                <Star className="w-2.5 h-2.5 fill-amber-400 text-amber-400" />
                                <span>{Math.round(g.totalRating)}</span>
                              </div>
                            )}

                            {/* Roll-bricka */}
                            {g.isDeveloper && (
                              <div className="absolute bottom-2 left-2 px-1.5 py-0.5 rounded bg-brand-red/90 text-white text-[9px] font-extrabold uppercase tracking-wider">
                                Utvecklare
                              </div>
                            )}
                          </div>

                          {/* Info & Add-knapp */}
                          <div className="p-3 flex-1 flex flex-col justify-between gap-2">
                            <div
                              onClick={() => onSelectGame?.(g.id)}
                              className="cursor-pointer"
                            >
                              <h4 className="text-xs font-bold text-zinc-100 truncate group-hover:text-white">
                                {g.name}
                              </h4>
                              <div className="flex items-center gap-2 text-[11px] text-zinc-400 mt-0.5">
                                {g.releaseYear ? (
                                  <span>{g.releaseYear}</span>
                                ) : (
                                  <span>Kommande</span>
                                )}
                                {g.genres[0] && (
                                  <>
                                    <span>•</span>
                                    <span className="truncate">{g.genres[0]}</span>
                                  </>
                                )}
                              </div>
                            </div>

                            {/* 1-klicks lägg till i biblioteket */}
                            <button
                              onClick={() => {
                                if (!inLibrary) {
                                  onAddGame({
                                    title: g.name,
                                    igdbId: g.id,
                                    coverUrl: g.coverUrl,
                                    releaseYear: g.releaseYear,
                                    genres: g.genres,
                                    developers: [displayName],
                                    platforms: g.platforms,
                                  });
                                }
                              }}
                              disabled={inLibrary}
                              className={`w-full flex items-center justify-center gap-1.5 py-1.5 px-2 rounded-xl text-xs font-bold transition ${
                                inLibrary
                                  ? 'bg-emerald-950/40 text-emerald-400 border border-emerald-800/60 cursor-default'
                                  : 'bg-zinc-800 hover:bg-brand-red text-zinc-200 hover:text-white border border-zinc-700/80 active:scale-95'
                              }`}
                            >
                              {inLibrary ? (
                                <>
                                  <Check className="w-3.5 h-3.5" />
                                  <span>I samlingen</span>
                                </>
                              ) : (
                                <>
                                  <Plus className="w-3.5 h-3.5" />
                                  <span>Lägg till</span>
                                </>
                              )}
                            </button>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
