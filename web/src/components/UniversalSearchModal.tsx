'use client';

import React, { useState, useEffect, useRef, useMemo } from 'react';
import { Game, IGDBSearchResult, PlayStatus } from '@/types/game';
import { resolveGameAlias } from '@/lib/aliasResolver';
import { StatusBadge } from './StatusBadge';
import { inferPlayTypes } from '@/lib/statusHelper';
import {
  Search,
  X,
  Library,
  Globe,
  Newspaper,
  Plus,
  Check,
  Star,
  Gamepad,
  ExternalLink,
  ArrowRight,
  TrendingUp,
  Clock,
  Command,
  Flame,
  Loader2,
  Building2,
} from 'lucide-react';

interface UniversalSearchModalProps {
  isOpen: boolean;
  onClose: () => void;
  games: Game[];
  onSelectGame: (game: Game) => void;
  onAddGame: (game: Game) => void;
  onOpenCompany?: (companyId: number, companyName: string, role: 'developer' | 'publisher') => void;
}

interface NewsItem {
  id: string;
  title: string;
  source: string;
  link: string;
  published: string;
  image?: string | null;
  summary?: string;
  category?: string;
}

const TRENDING_SEARCHES = [
  'Grand Theft Auto VI',
  'Ghost of Yōtei',
  'Elden Ring',
  'Monster Hunter Wilds',
  'Metroid Prime 4',
  'Fable',
  'The Witcher',
];

export function UniversalSearchModal({
  isOpen,
  onClose,
  games,
  onSelectGame,
  onAddGame,
  onOpenCompany,
}: UniversalSearchModalProps) {
  const [query, setQuery] = useState('');
  const [igdbResults, setIgdbResults] = useState<IGDBSearchResult[]>([]);
  const [newsResults, setNewsResults] = useState<NewsItem[]>([]);
  const [isLoadingIgdb, setIsLoadingIgdb] = useState(false);
  const [isLoadingNews, setIsLoadingNews] = useState(false);
  const [recentSearches, setRecentSearches] = useState<string[]>([]);
  const [activeTab, setActiveTab] = useState<'all' | 'library' | 'igdb' | 'news'>('all');

  const inputRef = useRef<HTMLInputElement>(null);

  // Ladda senaste sökningar
  useEffect(() => {
    if (typeof window !== 'undefined') {
      try {
        const saved = localStorage.getItem('gameshelf_recent_searches');
        if (saved) setRecentSearches(JSON.parse(saved));
      } catch (e) {}
    }
  }, [isOpen]);

  // Fokusera input när modalen öppnas
  useEffect(() => {
    if (isOpen) {
      setTimeout(() => inputRef.current?.focus(), 50);
    } else {
      setQuery('');
      setIgdbResults([]);
      setNewsResults([]);
    }
  }, [isOpen]);

  // Spara senaste sökningar
  const saveSearchTerm = (term: string) => {
    const trimmed = term.trim();
    if (!trimmed) return;
    const updated = [trimmed, ...recentSearches.filter((s) => s.toLowerCase() !== trimmed.toLowerCase())].slice(0, 6);
    setRecentSearches(updated);
    if (typeof window !== 'undefined') {
      localStorage.setItem('gameshelf_recent_searches', JSON.stringify(updated));
    }
  };

  const removeRecentSearch = (e: React.MouseEvent, term: string) => {
    e.stopPropagation();
    const updated = recentSearches.filter((s) => s !== term);
    setRecentSearches(updated);
    if (typeof window !== 'undefined') {
      localStorage.setItem('gameshelf_recent_searches', JSON.stringify(updated));
    }
  };

  // 1. Lokala biblioteksresultat (realtid med alias-stöd)
  const libraryResults = useMemo(() => {
    if (!query.trim()) return [];
    const q = query.toLowerCase();
    const resolvedQ = resolveGameAlias(query).toLowerCase();
    return games.filter(
      (g) =>
        g.title.toLowerCase().includes(q) ||
        g.title.toLowerCase().includes(resolvedQ) ||
        g.genres.some((genre) => genre.toLowerCase().includes(q) || genre.toLowerCase().includes(resolvedQ)) ||
        g.developers.some((dev) => dev.toLowerCase().includes(q) || dev.toLowerCase().includes(resolvedQ)) ||
        g.platforms.some((p) => p.toLowerCase().includes(q))
    );
  }, [games, query]);

  // 2. IGDB & Nyheter sökning (debounced)
  useEffect(() => {
    if (!query.trim()) {
      setIgdbResults([]);
      setNewsResults([]);
      setIsLoadingIgdb(false);
      setIsLoadingNews(false);
      return;
    }

    const timer = setTimeout(async () => {
      setIsLoadingIgdb(true);
      setIsLoadingNews(true);

      // IGDB fetch
      try {
        const res = await fetch(`/api/igdb/search?q=${encodeURIComponent(query)}&limit=10`);
        const data = await res.json();
        if (data.results) {
          setIgdbResults(data.results);
        }
      } catch (e) {
        console.error('Error in spotlight IGDB search:', e);
      } finally {
        setIsLoadingIgdb(false);
      }

      // News fetch
      try {
        const res = await fetch('/api/news');
        const data = await res.json();
        if (data.news) {
          const q = query.toLowerCase();
          const matchedNews = (data.news as NewsItem[])
            .filter(
              (n) =>
                n.title.toLowerCase().includes(q) ||
                n.source.toLowerCase().includes(q) ||
                (n.summary && n.summary.toLowerCase().includes(q))
            )
            .slice(0, 4);
          setNewsResults(matchedNews);
        }
      } catch (e) {
        console.error('Error in spotlight news search:', e);
      } finally {
        setIsLoadingNews(false);
      }
    }, 280);

    return () => clearTimeout(timer);
  }, [query]);

  // Konvertera IGDB resultat till Game-objekt för lägg till
  const convertIgdbToGame = (igdbGame: IGDBSearchResult): Game => {
    const releaseYear = igdbGame.first_release_date
      ? new Date(igdbGame.first_release_date * 1000).getFullYear()
      : null;
    const platforms = (igdbGame.platforms || []).map((p) => p.name);
    const genres = (igdbGame.genres || []).map((g) => g.name);
    const developers = (igdbGame.involved_companies || [])
      .filter((c) => c.developer)
      .map((c) => c.company.name);
    const ratingScore = igdbGame.total_rating || igdbGame.rating;
    const igdbRating = ratingScore ? Math.round((ratingScore / 10) * 10) / 10 : null;

    return {
      id: crypto.randomUUID(),
      title: igdbGame.name,
      cover_url: igdbGame.cover?.url || null,
      platforms,
      release_year: releaseYear,
      first_release_date: igdbGame.first_release_date || null,
      genres,
      developers,
      status: 'notStarted',
      rating: null,
      igdb_rating: igdbRating,
      igdb_id: igdbGame.id,
      estimated_hours: null,
      is_owned: false,
      is_backlog: false,
      play_types: inferPlayTypes({ title: igdbGame.name, genres }),
      notes: '',
      todos: [],
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };
  };

  const isGameInLibrary = (igdbId?: number | null, title?: string) => {
    return games.some(
      (g) =>
        (igdbId && g.igdb_id === igdbId) ||
        (title && g.title.toLowerCase() === title.toLowerCase())
    );
  };

  if (!isOpen) return null;

  return (
    <div
      className="fixed inset-0 z-50 flex items-start justify-center p-3 sm:p-6 sm:pt-20 bg-black/80 backdrop-blur-md animate-in fade-in duration-150"
      onClick={onClose}
    >
      <div
        className="w-full max-w-2xl bg-[#111216] border border-zinc-800/90 rounded-3xl shadow-2xl overflow-hidden flex flex-col max-h-[85vh] animate-in zoom-in-95 duration-150"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Search Input Bar */}
        <div className="relative flex items-center px-4 sm:px-6 py-4 border-b border-zinc-800/90 bg-zinc-950/60">
          <Search className="w-5 h-5 text-zinc-400 shrink-0 mr-3" />
          <input
            ref={inputRef}
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Escape') onClose();
              if (e.key === 'Enter' && query.trim()) saveSearchTerm(query);
            }}
            placeholder="Sök bland dina spel, upptäck på IGDB, eller hitta nyheter..."
            className="w-full bg-transparent text-sm sm:text-base text-zinc-100 placeholder-zinc-500 focus:outline-none"
          />
          {query ? (
            <button
              onClick={() => {
                setQuery('');
                inputRef.current?.focus();
              }}
              className="p-1 text-zinc-500 hover:text-zinc-200 transition"
            >
              <X className="w-4 h-4" />
            </button>
          ) : (
            <div className="hidden sm:flex items-center gap-1 px-2 py-0.5 rounded-lg bg-zinc-900 border border-zinc-800 text-[11px] font-medium text-zinc-400">
              <span>ESC</span>
            </div>
          )}
        </div>

        {/* Source Filter Pills (if query is active) */}
        {query.trim() && (
          <div className="flex items-center gap-1.5 px-4 sm:px-6 py-2.5 border-b border-zinc-800/60 bg-zinc-900/30 overflow-x-auto scrollbar-none">
            <button
              onClick={() => setActiveTab('all')}
              className={`px-3 py-1 rounded-xl text-xs font-semibold transition ${
                activeTab === 'all'
                  ? 'bg-white text-zinc-950 shadow-sm'
                  : 'text-zinc-400 hover:text-zinc-200'
              }`}
            >
              Alla resultat
            </button>
            <button
              onClick={() => setActiveTab('library')}
              className={`flex items-center gap-1.5 px-3 py-1 rounded-xl text-xs font-semibold transition ${
                activeTab === 'library'
                  ? 'bg-white text-zinc-950 shadow-sm'
                  : 'text-zinc-400 hover:text-zinc-200'
              }`}
            >
              <Library className="w-3.5 h-3.5" />
              <span>Mina spel ({libraryResults.length})</span>
            </button>
            <button
              onClick={() => setActiveTab('igdb')}
              className={`flex items-center gap-1.5 px-3 py-1 rounded-xl text-xs font-semibold transition ${
                activeTab === 'igdb'
                  ? 'bg-white text-zinc-950 shadow-sm'
                  : 'text-zinc-400 hover:text-zinc-200'
              }`}
            >
              <Globe className="w-3.5 h-3.5" />
              <span>IGDB ({igdbResults.length})</span>
            </button>
            {newsResults.length > 0 && (
              <button
                onClick={() => setActiveTab('news')}
                className={`flex items-center gap-1.5 px-3 py-1 rounded-xl text-xs font-semibold transition ${
                  activeTab === 'news'
                    ? 'bg-white text-zinc-950 shadow-sm'
                    : 'text-zinc-400 hover:text-zinc-200'
                }`}
              >
                <Newspaper className="w-3.5 h-3.5" />
                <span>Nyheter ({newsResults.length})</span>
              </button>
            )}
          </div>
        )}

        {/* Results Container */}
        <div className="flex-1 overflow-y-auto p-4 sm:p-6 space-y-6 scrollbar-thin scrollbar-thumb-zinc-800">
          {!query.trim() ? (
            /* Empty State: Recent & Trending */
            <div className="space-y-6">
              {recentSearches.length > 0 && (
                <div>
                  <div className="flex items-center justify-between text-xs font-bold text-zinc-400 uppercase tracking-wider mb-2.5">
                    <div className="flex items-center gap-1.5">
                      <Clock className="w-3.5 h-3.5" />
                      <span>Senaste sökningar</span>
                    </div>
                  </div>
                  <div className="flex flex-wrap gap-2">
                    {recentSearches.map((term) => (
                      <button
                        key={term}
                        onClick={() => {
                          setQuery(term);
                          saveSearchTerm(term);
                        }}
                        className="group flex items-center gap-2 px-3 py-1.5 rounded-xl bg-zinc-900/90 border border-zinc-800 text-xs text-zinc-300 hover:text-white hover:border-zinc-700 transition"
                      >
                        <span>{term}</span>
                        <X
                          className="w-3 h-3 text-zinc-500 group-hover:text-zinc-300 transition"
                          onClick={(e) => removeRecentSearch(e, term)}
                        />
                      </button>
                    ))}
                  </div>
                </div>
              )}

              <div>
                <div className="flex items-center gap-1.5 text-xs font-bold text-zinc-400 uppercase tracking-wider mb-2.5">
                  <Flame className="w-3.5 h-3.5 text-brand-red" />
                  <span>Populära sökningar just nu</span>
                </div>
                <div className="flex flex-wrap gap-2">
                  {TRENDING_SEARCHES.map((term) => (
                    <button
                      key={term}
                      onClick={() => {
                        setQuery(term);
                        saveSearchTerm(term);
                      }}
                      className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-zinc-900/60 border border-zinc-800/80 text-xs text-zinc-300 hover:text-white hover:border-brand-red/50 hover:bg-brand-red/10 transition"
                    >
                      <TrendingUp className="w-3 h-3 text-brand-red" />
                      <span>{term}</span>
                    </button>
                  ))}
                </div>
              </div>
            </div>
          ) : (
            /* Search Results Sections */
            <div className="space-y-6">
              {/* 1. Ditt bibliotek */}
              {(activeTab === 'all' || activeTab === 'library') && libraryResults.length > 0 && (
                <div>
                  <div className="flex items-center gap-2 text-xs font-bold text-zinc-400 uppercase tracking-wider mb-3">
                    <Library className="w-3.5 h-3.5 text-emerald-400" />
                    <span>I ditt bibliotek ({libraryResults.length})</span>
                  </div>

                  <div className="space-y-2">
                    {libraryResults.map((game) => (
                      <div
                        key={game.id}
                        onClick={() => {
                          saveSearchTerm(query);
                          onSelectGame(game);
                          onClose();
                        }}
                        className="flex items-center justify-between p-2.5 sm:p-3 rounded-2xl bg-zinc-900/60 border border-zinc-800/80 hover:border-zinc-700 hover:bg-zinc-900 cursor-pointer group transition"
                      >
                        <div className="flex items-center gap-3 min-w-0">
                          <div className="w-10 h-14 rounded-xl overflow-hidden bg-zinc-950 shrink-0 border border-zinc-800">
                            {game.cover_url ? (
                              <img
                                src={game.cover_url}
                                alt={game.title}
                                className="w-full h-full object-cover group-hover:scale-105 transition"
                              />
                            ) : (
                              <div className="w-full h-full flex items-center justify-center">
                                <Gamepad className="w-4 h-4 text-zinc-600" />
                              </div>
                            )}
                          </div>
                          <div className="min-w-0">
                            <h4 className="text-sm font-bold text-zinc-100 group-hover:text-red-400 transition truncate">
                              {game.title}
                            </h4>
                            <div className="flex items-center gap-2 mt-1">
                              <StatusBadge game={game} />
                              {game.rating && (
                                <span className="text-[11px] text-amber-400 font-semibold">
                                  ⭐ {game.rating}/10
                                </span>
                              )}
                              {game.release_year && (
                                <span className="text-[11px] text-zinc-500">
                                  {game.release_year}
                                </span>
                              )}
                            </div>
                          </div>
                        </div>

                        <ArrowRight className="w-4 h-4 text-zinc-500 group-hover:text-white transition shrink-0 ml-2" />
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* Studio & Utgivare snabbåtkomst */}
              {query.trim().length >= 2 && onOpenCompany && (
                <div className="bg-zinc-900/60 border border-zinc-800/80 rounded-2xl p-3 sm:p-4 hover:border-brand-red/40 transition">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-3 min-w-0">
                      <div className="w-10 h-10 rounded-xl bg-brand-red/10 border border-brand-red/20 flex items-center justify-center text-brand-red shrink-0">
                        <Building2 className="w-5 h-5" />
                      </div>
                      <div className="min-w-0">
                        <div className="text-[11px] font-bold text-zinc-400 uppercase tracking-wider">
                          Utforska Studio & Utgivare
                        </div>
                        <div className="text-sm font-bold text-white truncate">
                          "{query.trim()}"
                        </div>
                      </div>
                    </div>
                    <button
                      type="button"
                      onClick={() => {
                        saveSearchTerm(query.trim());
                        onClose();
                        onOpenCompany(0, query.trim(), 'developer');
                      }}
                      className="px-3.5 py-1.5 rounded-xl bg-brand-red hover:bg-red-700 text-white text-xs font-bold transition flex items-center gap-1.5 shadow-lg shadow-brand-red/20 cursor-pointer shrink-0 ml-3"
                    >
                      <span>Öppna studio</span>
                      <ArrowRight className="w-3.5 h-3.5" />
                    </button>
                  </div>
                </div>
              )}

              {/* 2. IGDB Upptäck nya spel */}
              {(activeTab === 'all' || activeTab === 'igdb') && (
                <div>
                  <div className="flex items-center justify-between text-xs font-bold text-zinc-400 uppercase tracking-wider mb-3">
                    <div className="flex items-center gap-2">
                      <Globe className="w-3.5 h-3.5 text-brand-red" />
                      <span>Hitta på IGDB</span>
                    </div>
                    {isLoadingIgdb && (
                      <div className="flex items-center gap-1 text-[11px] text-zinc-500">
                        <Loader2 className="w-3 h-3 animate-spin text-brand-red" />
                        <span>Söker...</span>
                      </div>
                    )}
                  </div>

                  {igdbResults.length > 0 ? (
                    <div className="space-y-2">
                      {igdbResults.map((game) => {
                        const inLibrary = isGameInLibrary(game.id, game.name);
                        return (
                          <div
                            key={game.id}
                            className="flex items-center justify-between p-2.5 sm:p-3 rounded-2xl bg-zinc-900/60 border border-zinc-800/80 hover:border-zinc-700 transition"
                          >
                            <div
                              onClick={() => {
                                saveSearchTerm(query);
                                const gameObj = convertIgdbToGame(game);
                                onSelectGame(gameObj);
                                onClose();
                              }}
                              className="flex items-center gap-3 min-w-0 cursor-pointer flex-1"
                            >
                              <div className="w-10 h-14 rounded-xl overflow-hidden bg-zinc-950 shrink-0 border border-zinc-800">
                                {game.cover?.url ? (
                                  <img
                                    src={game.cover.url}
                                    alt={game.name}
                                    className="w-full h-full object-cover"
                                  />
                                ) : (
                                  <div className="w-full h-full flex items-center justify-center">
                                    <Gamepad className="w-4 h-4 text-zinc-600" />
                                  </div>
                                )}
                              </div>
                              <div className="min-w-0">
                                <h4 className="text-sm font-bold text-zinc-100 hover:text-red-400 transition truncate">
                                  {game.name}
                                </h4>
                                <p className="text-[11px] text-zinc-400 mt-0.5 truncate">
                                  {game.first_release_date
                                    ? new Date(game.first_release_date * 1000).getFullYear()
                                    : 'TBA'}{' '}
                                  • {game.genres?.[0]?.name || 'Spel'}
                                </p>
                              </div>
                            </div>

                            <button
                              onClick={() => {
                                saveSearchTerm(query);
                                const gameObj = convertIgdbToGame(game);
                                onAddGame(gameObj);
                              }}
                              disabled={inLibrary}
                              className={`ml-3 px-3 py-1.5 rounded-xl text-xs font-semibold flex items-center gap-1 transition shrink-0 ${
                                inLibrary
                                  ? 'bg-zinc-800/60 text-zinc-400 border border-zinc-700/50 cursor-default'
                                  : 'bg-zinc-800 hover:bg-brand-red text-zinc-200 hover:text-white border border-zinc-700 hover:border-brand-red'
                              }`}
                            >
                              {inLibrary ? (
                                <>
                                  <Check className="w-3.5 h-3.5 text-emerald-400" />
                                  <span className="hidden sm:inline">I samling</span>
                                </>
                              ) : (
                                <>
                                  <Plus className="w-3.5 h-3.5" />
                                  <span>Lägg till</span>
                                </>
                              )}
                            </button>
                          </div>
                        );
                      })}
                    </div>
                  ) : (
                    !isLoadingIgdb && (
                      <p className="text-xs text-zinc-500 py-3 text-center">
                        Inga nya spel hittades på IGDB för &ldquo;{query}&rdquo;.
                      </p>
                    )
                  )}
                </div>
              )}

              {/* 3. Spelnyheter */}
              {(activeTab === 'all' || activeTab === 'news') && newsResults.length > 0 && (
                <div>
                  <div className="flex items-center gap-2 text-xs font-bold text-zinc-400 uppercase tracking-wider mb-3">
                    <Newspaper className="w-3.5 h-3.5 text-rose-400" />
                    <span>Nyheter & Artiklar ({newsResults.length})</span>
                  </div>

                  <div className="space-y-2">
                    {newsResults.map((item) => (
                      <a
                        key={item.id}
                        href={item.link}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="flex items-center justify-between p-3 rounded-2xl bg-zinc-900/60 border border-zinc-800/80 hover:border-zinc-700 hover:bg-zinc-900 transition group"
                      >
                        <div className="min-w-0 pr-3">
                          <div className="flex items-center gap-2 text-[10px] text-zinc-500 mb-1">
                            <span className="font-bold text-zinc-300">{item.source}</span>
                            <span>•</span>
                            <span>{new Date(item.published).toLocaleDateString('sv-SE')}</span>
                          </div>
                          <h5 className="text-xs sm:text-sm font-semibold text-zinc-100 group-hover:text-red-400 transition line-clamp-1">
                            {item.title}
                          </h5>
                        </div>

                        <ExternalLink className="w-4 h-4 text-zinc-500 group-hover:text-white transition shrink-0" />
                      </a>
                    ))}
                  </div>
                </div>
              )}

              {/* Inga resultat alls */}
              {!isLoadingIgdb &&
                !isLoadingNews &&
                libraryResults.length === 0 &&
                igdbResults.length === 0 &&
                newsResults.length === 0 && (
                  <div className="text-center py-12 text-zinc-500">
                    <Search className="w-8 h-8 mx-auto mb-2 opacity-50" />
                    <p className="text-sm font-medium">Inga träffar för &ldquo;{query}&rdquo;</p>
                    <p className="text-xs text-zinc-600 mt-1">
                      Prova att söka på en annan titel, utvecklare eller konsol.
                    </p>
                  </div>
                )}
            </div>
          )}
        </div>

        {/* Footer with Keyboard Hints */}
        <div className="px-6 py-3 border-t border-zinc-800/80 bg-zinc-950/60 flex items-center justify-between text-[11px] text-zinc-500">
          <div className="flex items-center gap-3">
            <span className="flex items-center gap-1">
              <kbd className="px-1.5 py-0.5 rounded bg-zinc-900 border border-zinc-800 text-zinc-300 font-mono text-[10px]">
                ESC
              </kbd>{' '}
              Stäng
            </span>
            <span className="hidden sm:inline-flex items-center gap-1">
              <kbd className="px-1.5 py-0.5 rounded bg-zinc-900 border border-zinc-800 text-zinc-300 font-mono text-[10px]">
                ⌘K
              </kbd>{' '}
              Öppna spotlight
            </span>
          </div>

          <div className="text-[11px] text-zinc-500">
            <span>Gameshelf Spotlight</span>
          </div>
        </div>
      </div>
    </div>
  );
}
