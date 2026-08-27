'use client';

import React, { useState, useEffect, useMemo } from 'react';
import { Game, GameCollection, PlayStatus, PLAY_STATUSES } from '@/types/game';
import { supabase, mapSupabaseGame, mapSupabaseCollection } from '@/lib/supabase';
import { Header, ViewMode } from '@/components/Header';
import { ShelfView } from '@/components/ShelfView';
import { GridView } from '@/components/GridView';
import { ListView } from '@/components/ListView';
import { CollectionsView } from '@/components/CollectionsView';
import { StatsDashboardView } from '@/components/StatsDashboardView';
import { AddGameModal } from '@/components/AddGameModal';
import { GameDetailModal } from '@/components/GameDetailModal';
import { CollectionsModal } from '@/components/CollectionsModal';
import { PairingModal } from '@/components/PairingModal';
import { GameRouletteModal } from '@/components/GameRouletteModal';
import { StatusBadge } from '@/components/StatusBadge';
import {
  Layers,
  Sparkles,
  TrendingUp,
  Filter,
  CheckCircle2,
  FolderKanban,
  X,
  Smartphone,
} from 'lucide-react';

export default function HomePage() {
  const [games, setGames] = useState<Game[]>([]);
  const [collections, setCollections] = useState<GameCollection[]>([]);
  const [viewMode, setViewMode] = useState<ViewMode>('shelf');
  const [selectedStatus, setSelectedStatus] = useState<PlayStatus | 'Alla'>('Alla');
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCollectionId, setSelectedCollectionId] = useState<string | null>(null);
  const [profileName, setProfileName] = useState<string>('');

  // Modals
  const [isAddModalOpen, setIsAddModalOpen] = useState(false);
  const [isCollectionsModalOpen, setIsCollectionsModalOpen] = useState(false);
  const [isPairingModalOpen, setIsPairingModalOpen] = useState(false);
  const [isRouletteModalOpen, setIsRouletteModalOpen] = useState(false);
  const [selectedGame, setSelectedGame] = useState<Game | null>(null);
  const [isSyncing, setIsSyncing] = useState(false);

  // Fetch games & collections from Supabase (if logged in) or localStorage (if guest)
  const fetchLibrary = async () => {
    setIsSyncing(true);

    let pairedProfile: string | null = null;
    let pairedUserId: string | null = null;

    if (typeof window !== 'undefined') {
      pairedProfile = localStorage.getItem('gameshelf_profile_name');
      pairedUserId = localStorage.getItem('gameshelf_paired_user_id');

      if (pairedProfile) setProfileName(pairedProfile);

      const cachedGames = localStorage.getItem('gameshelf_local_games');
      const cachedCols = localStorage.getItem('gameshelf_local_collections');
      if (cachedGames) {
        try {
          const parsed = JSON.parse(cachedGames);
          if (Array.isArray(parsed)) {
            setGames(parsed);
          }
        } catch (e) {}
      }
      if (cachedCols) {
        try {
          const parsedCols = JSON.parse(cachedCols);
          if (Array.isArray(parsedCols)) {
            setCollections(parsedCols);
          }
        } catch (e) {}
      }
    }

    // Om användaren är i gästläge (ej parkopplad/inloggad), hämta INTE från Supabase
    if (!pairedProfile && !pairedUserId) {
      setIsSyncing(false);
      return;
    }

    try {
      const [gamesRes, colRes] = await Promise.all([
        supabase.from('user_games').select('*').order('created_at', { ascending: false }),
        supabase.from('collections').select('*').order('created_at', { ascending: false }),
      ]);

      if (gamesRes.data) {
        const mapped = gamesRes.data.map(mapSupabaseGame);
        setGames(mapped);
        if (typeof window !== 'undefined') {
          localStorage.setItem('gameshelf_local_games', JSON.stringify(mapped));
        }
      }

      if (colRes.data) {
        const mappedCols = colRes.data.map(mapSupabaseCollection);
        setCollections(mappedCols);
        if (typeof window !== 'undefined') {
          localStorage.setItem('gameshelf_local_collections', JSON.stringify(mappedCols));
        }
      }
    } catch (err) {
      console.warn('Could not fetch from Supabase, using local cache:', err);
    } finally {
      setIsSyncing(false);
    }
  };

  useEffect(() => {
    fetchLibrary();

    // Prenumerera endast på Supabase Realtime om användaren är inloggad
    const isPaired = typeof window !== 'undefined' && !!localStorage.getItem('gameshelf_profile_name');
    if (!isPaired) return;

    // Supabase Realtime Channel for user_games
    const gamesChannel = supabase
      .channel('public:user_games')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'user_games' },
        (payload: any) => {
          if (payload.eventType === 'INSERT') {
            const newGame = mapSupabaseGame(payload.new);
            setGames((prev) => {
              const next = [newGame, ...prev.filter((g) => g.id !== newGame.id)];
              if (typeof window !== 'undefined') {
                localStorage.setItem('gameshelf_local_games', JSON.stringify(next));
              }
              return next;
            });
          } else if (payload.eventType === 'UPDATE') {
            const updated = mapSupabaseGame(payload.new);
            setGames((prev) => {
              const next = prev.map((g) => (g.id === updated.id ? updated : g));
              if (typeof window !== 'undefined') {
                localStorage.setItem('gameshelf_local_games', JSON.stringify(next));
              }
              return next;
            });
            setSelectedGame((current) => (current?.id === updated.id ? updated : current));
          } else if (payload.eventType === 'DELETE') {
            const deletedId = payload.old?.id;
            if (deletedId) {
              setGames((prev) => {
                const next = prev.filter((g) => g.id !== deletedId);
                if (typeof window !== 'undefined') {
                  localStorage.setItem('gameshelf_local_games', JSON.stringify(next));
                }
                return next;
              });
              setSelectedGame((current) => (current?.id === deletedId ? null : current));
            }
          }
        }
      )
      .subscribe();

    const collectionsChannel = supabase
      .channel('public:collections')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'collections' },
        (payload: any) => {
          if (payload.eventType === 'INSERT') {
            const newCol = mapSupabaseCollection(payload.new);
            setCollections((prev) => {
              const next = [newCol, ...prev.filter((c) => c.id !== newCol.id)];
              if (typeof window !== 'undefined') {
                localStorage.setItem('gameshelf_local_collections', JSON.stringify(next));
              }
              return next;
            });
          } else if (payload.eventType === 'UPDATE') {
            const updated = mapSupabaseCollection(payload.new);
            setCollections((prev) => {
              const next = prev.map((c) => (c.id === updated.id ? updated : c));
              if (typeof window !== 'undefined') {
                localStorage.setItem('gameshelf_local_collections', JSON.stringify(next));
              }
              return next;
            });
          } else if (payload.eventType === 'DELETE') {
            const deletedId = payload.old?.id;
            if (deletedId) {
              setCollections((prev) => {
                const next = prev.filter((c) => c.id !== deletedId);
                if (typeof window !== 'undefined') {
                  localStorage.setItem('gameshelf_local_collections', JSON.stringify(next));
                }
                return next;
              });
            }
          }
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(gamesChannel);
      supabase.removeChannel(collectionsChannel);
    };
  }, []);

  // Filtered games
  const filteredGames = useMemo(() => {
    return games.filter((game) => {
      // Status filter
      if (selectedStatus !== 'Alla' && game.status !== selectedStatus) {
        return false;
      }

      // Collection filter
      if (selectedCollectionId) {
        const col = collections.find((c) => c.id === selectedCollectionId);
        if (col && !col.game_ids?.includes(game.id)) {
          return false;
        }
      }

      // Search query
      if (searchQuery.trim()) {
        const q = searchQuery.toLowerCase();
        const matchesTitle = game.title.toLowerCase().includes(q);
        const matchesDev = game.developers?.some((d) => d.toLowerCase().includes(q));
        const matchesPlatform = game.platforms?.some((p) => p.toLowerCase().includes(q));
        const matchesGenre = game.genres?.some((g) => g.toLowerCase().includes(q));
        if (!matchesTitle && !matchesDev && !matchesPlatform && !matchesGenre) {
          return false;
        }
      }

      return true;
    });
  }, [games, selectedStatus, selectedCollectionId, searchQuery, collections]);

  // Status counts for tab pills
  const statusCounts = useMemo(() => {
    const counts: { [k: string]: number } = { Alla: games.length };
    PLAY_STATUSES.forEach((s) => {
      counts[s] = games.filter((g) => g.status === s).length;
    });
    return counts;
  }, [games]);

  // Handlers for game changes
  const handleGameAdded = (newGame: Game) => {
    setGames((prev) => {
      const next = [newGame, ...prev];
      if (typeof window !== 'undefined') {
        localStorage.setItem('gameshelf_local_games', JSON.stringify(next));
      }
      return next;
    });
  };

  const handleUpdateGame = (updatedGame: Game) => {
    setGames((prev) => {
      const next = prev.map((g) => (g.id === updatedGame.id ? updatedGame : g));
      if (typeof window !== 'undefined') {
        localStorage.setItem('gameshelf_local_games', JSON.stringify(next));
      }
      return next;
    });
    setSelectedGame(updatedGame);
  };

  const handleUpdateGameStatus = async (gameId: string, newStatus: PlayStatus) => {
    setGames((prev) => {
      const next = prev.map((g) => (g.id === gameId ? { ...g, status: newStatus } : g));
      if (typeof window !== 'undefined') {
        localStorage.setItem('gameshelf_local_games', JSON.stringify(next));
      }
      return next;
    });

    try {
      await supabase.from('user_games').update({ status: newStatus }).eq('id', gameId);
    } catch (err) {
      console.error('Failed to update game status:', err);
    }
  };

  const handleAddDiscoveryGameToLibrary = async (game: Game) => {
    let pairedUserId: string | null = null;
    if (typeof window !== 'undefined') {
      pairedUserId = localStorage.getItem('gameshelf_paired_user_id');
    }

    const payload = {
      user_id: pairedUserId,
      title: game.title,
      cover_url: game.cover_url || null,
      platforms: game.platforms || [],
      release_year: game.release_year || null,
      genres: game.genres || [],
      developers: game.developers || [],
      status: game.status || 'Önskelista',
      is_owned: game.is_owned || false,
      rating: null,
      igdb_rating: game.igdb_rating || null,
      estimated_hours: null,
      notes: null,
      todos: [],
    };

    try {
      const { data, error } = await supabase
        .from('user_games')
        .insert([payload])
        .select()
        .single();

      if (!error && data) {
        handleGameAdded(mapSupabaseGame(data));
      } else {
        handleGameAdded({
          ...game,
          id: crypto.randomUUID(),
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        });
      }
    } catch (e) {
      handleGameAdded(game);
    }
  };

  const handleDeleteGame = (gameId: string) => {
    setGames((prev) => {
      const next = prev.filter((g) => g.id !== gameId);
      if (typeof window !== 'undefined') {
        localStorage.setItem('gameshelf_local_games', JSON.stringify(next));
      }
      return next;
    });
  };

  const handleToggleCollection = async (gameId: string, colId: string) => {
    const col = collections.find((c) => c.id === colId);
    if (!col) return;

    const currentIds = col.game_ids || [];
    const nextIds = currentIds.includes(gameId)
      ? currentIds.filter((id) => id !== gameId)
      : [...currentIds, gameId];

    const updatedCol = { ...col, game_ids: nextIds };
    setCollections((prev) => prev.map((c) => (c.id === colId ? updatedCol : c)));

    try {
      await supabase.from('collections').update({ game_ids: nextIds }).eq('id', colId);
    } catch (err) {
      console.error('Failed to update collection members:', err);
    }
  };

  const handleLogout = () => {
    if (typeof window !== 'undefined') {
      localStorage.removeItem('gameshelf_profile_name');
      localStorage.removeItem('gameshelf_paired_user_id');
      localStorage.removeItem('gameshelf_local_games');
      localStorage.removeItem('gameshelf_local_collections');
    }
    setProfileName('');
    setGames([]);
    setCollections([]);
    setSelectedCollectionId(null);
  };

  const handlePairedAndMerge = async (userId: string, username?: string) => {
    const user = username?.trim() || (userId ? 'Spelare' : '');
    setProfileName(user);
    if (typeof window !== 'undefined') {
      if (user) localStorage.setItem('gameshelf_profile_name', user);
      if (userId) localStorage.setItem('gameshelf_paired_user_id', userId);
    }

    // Identifiera gästspel som skapats lokalt och migrera dem till användarens konto
    try {
      const { data: dbGames } = await supabase
        .from('user_games')
        .select('title, igdb_id');

      const existingTitles = new Set(
        (dbGames || []).map((g: any) => (g.title || '').trim().toLowerCase())
      );
      const existingIgdbIds = new Set(
        (dbGames || []).map((g: any) => g.igdb_id).filter(Boolean)
      );

      const guestGamesToMigrate = games.filter((localGame) => {
        const titleMatch = existingTitles.has(localGame.title.trim().toLowerCase());
        const igdbMatch = localGame.igdb_id && existingIgdbIds.has(localGame.igdb_id);
        return !titleMatch && !igdbMatch;
      });

      if (guestGamesToMigrate.length > 0) {
        const payloadToInsert = guestGamesToMigrate.map((g) => ({
          user_id: userId,
          title: g.title,
          cover_url: g.cover_url || null,
          platforms: g.platforms || [],
          release_year: g.release_year || null,
          genres: g.genres || [],
          developers: g.developers || [],
          status: g.status || 'Backlog',
          is_owned: g.is_owned ?? true,
          rating: g.rating || null,
          igdb_rating: g.igdb_rating || null,
          estimated_hours: g.estimated_hours || null,
          notes: g.notes || '',
          todos: g.todos || [],
        }));

        await supabase.from('user_games').insert(payloadToInsert);
      }
    } catch (err) {
      console.error('Error merging guest games during pairing:', err);
    }

    await fetchLibrary();
  };

  const activeCollection = collections.find((c) => c.id === selectedCollectionId);

  return (
    <div className="min-h-screen bg-[#0d0e12] text-zinc-100 flex flex-col">
      {/* Navigation Header */}
      <Header
        viewMode={viewMode}
        onViewModeChange={setViewMode}
        onOpenAddModal={() => setIsAddModalOpen(true)}
        onOpenCollectionsModal={() => setIsCollectionsModalOpen(true)}
        onOpenPairingModal={() => setIsPairingModalOpen(true)}
        onOpenRouletteModal={() => setIsRouletteModalOpen(true)}
        onLogout={handleLogout}
        searchQuery={searchQuery}
        onSearchChange={setSearchQuery}
        selectedCollectionId={selectedCollectionId}
        onSelectCollection={setSelectedCollectionId}
        collections={collections}
        isSyncing={isSyncing}
        totalGames={games.length}
        profileName={profileName}
      />

      {/* Main Content Area */}
      <main className="flex-1 max-w-7xl w-full mx-auto px-4 lg:px-8 py-6 space-y-6">
        {/* Guest Mode Banner */}
        {!profileName && (
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 p-4 rounded-2xl bg-gradient-to-r from-emerald-950/70 via-emerald-900/30 to-zinc-900/80 border border-emerald-500/40 shadow-lg animate-in fade-in duration-200">
            <div className="flex items-center gap-3">
              <div className="w-9 h-9 rounded-xl bg-emerald-500/20 border border-emerald-500/40 flex items-center justify-center text-emerald-400 shrink-0">
                <Smartphone className="w-5 h-5" />
              </div>
              <div>
                <h4 className="text-xs sm:text-sm font-bold text-white flex items-center gap-2">
                  <span>Gästläge aktivt</span>
                  <span className="text-[10px] px-2 py-0.5 rounded-full bg-emerald-500/20 text-emerald-300 font-semibold border border-emerald-500/30">
                    Lokal webbläsare
                  </span>
                </h4>
                <p className="text-[11px] text-zinc-300 mt-0.5">
                  Spel du lägger till sparas lokalt. När du loggar in med iPhone synkas de automatiskt över till ditt konto!
                </p>
              </div>
            </div>

            <button
              onClick={() => setIsPairingModalOpen(true)}
              className="flex items-center justify-center gap-1.5 px-4 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold shadow-md transition whitespace-nowrap self-start sm:self-auto"
            >
              <Smartphone className="w-3.5 h-3.5" />
              <span>Logga in med iPhone</span>
            </button>
          </div>
        )}

        {/* Active Collection Filter Banner */}
        {activeCollection && viewMode !== 'collections' && (
          <div className="flex items-center justify-between p-3.5 rounded-xl bg-brand-red/10 border border-brand-red/40 text-rose-200">
            <div className="flex items-center gap-2">
              <FolderKanban className="w-4 h-4 text-brand-red" />
              <span className="text-sm font-semibold">
                Filtrerar efter samling: <strong className="text-white">{activeCollection.name}</strong>
              </span>
              <span className="text-xs text-zinc-400">({filteredGames.length} spel)</span>
            </div>
            <button
              onClick={() => setSelectedCollectionId(null)}
              className="flex items-center gap-1 text-xs text-zinc-300 hover:text-white bg-zinc-800 px-2.5 py-1 rounded-lg border border-zinc-700 transition"
            >
              <X className="w-3.5 h-3.5" />
              <span>Återställ filter</span>
            </button>
          </div>
        )}

        {/* Status Filter Tabs (Only shown in Library views) */}
        {viewMode !== 'collections' && viewMode !== 'stats' && games.length > 0 && (
          <div className="flex items-center gap-2 overflow-x-auto pb-2 scrollbar-none">
            <button
              onClick={() => setSelectedStatus('Alla')}
              className={`flex items-center gap-1.5 px-3.5 py-1.5 rounded-xl text-xs font-semibold whitespace-nowrap transition ${
                selectedStatus === 'Alla'
                  ? 'bg-zinc-100 text-zinc-900 shadow-md'
                  : 'bg-zinc-900/80 text-zinc-400 hover:text-zinc-200 border border-zinc-800'
              }`}
            >
              <span>Alla</span>
              <span
                className={`px-1.5 py-0.2 rounded-full text-[10px] ${
                  selectedStatus === 'Alla' ? 'bg-zinc-300 text-zinc-900' : 'bg-zinc-800 text-zinc-400'
                }`}
              >
                {statusCounts['Alla']}
              </span>
            </button>

            {PLAY_STATUSES.map((status) => {
              const isSelected = selectedStatus === status;
              const count = statusCounts[status] || 0;
              return (
                <button
                  key={status}
                  onClick={() => setSelectedStatus(status)}
                  className={`flex items-center gap-1.5 px-3.5 py-1.5 rounded-xl text-xs font-semibold whitespace-nowrap transition ${
                    isSelected
                      ? 'bg-zinc-100 text-zinc-900 shadow-md'
                      : 'bg-zinc-900/80 text-zinc-400 hover:text-zinc-200 border border-zinc-800'
                  }`}
                >
                  <span>{status}</span>
                  <span
                    className={`px-1.5 py-0.2 rounded-full text-[10px] ${
                      isSelected ? 'bg-zinc-300 text-zinc-900' : 'bg-zinc-800 text-zinc-400'
                    }`}
                  >
                    {count}
                  </span>
                </button>
              );
            })}
          </div>
        )}

        {/* Views Switcher: Collections, Stats, or Library (Shelf, Grid, List) */}
        {viewMode === 'collections' ? (
          <CollectionsView
            collections={collections}
            games={games}
            onCreateCollection={(col) => setCollections((prev) => [col, ...prev])}
            onDeleteCollection={(id) => setCollections((prev) => prev.filter((c) => c.id !== id))}
            onSelectGame={setSelectedGame}
          />
        ) : viewMode === 'stats' ? (
          <StatsDashboardView games={games} onSelectGame={setSelectedGame} />
        ) : games.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-24 text-center px-4 rounded-2xl border border-dashed border-zinc-800 bg-zinc-950/40">
            <div className="w-16 h-16 rounded-2xl bg-zinc-900 flex items-center justify-center text-zinc-500 mb-4 border border-zinc-800 shadow-inner">
              <Layers className="w-8 h-8 text-brand-red" />
            </div>
            <h2 className="text-xl font-bold text-white mb-2">Spelhyllan är tom</h2>
            <p className="text-sm text-zinc-400 max-w-md mb-6">
              Parkoppla med din iPhone för att synka över dina spel och samlingar, eller sök och lägg till nya spel direkt via IGDB.
            </p>
            <div className="flex flex-wrap items-center justify-center gap-3">
              <button
                onClick={() => setIsPairingModalOpen(true)}
                className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-sm font-semibold transition shadow-lg shadow-emerald-950/50"
              >
                📱 Parkoppla iPhone
              </button>
              <button
                onClick={() => setIsAddModalOpen(true)}
                className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-zinc-800 hover:bg-zinc-700 text-zinc-200 text-sm font-medium border border-zinc-700 transition"
              >
                + Lägg till spel manuellt
              </button>
            </div>
          </div>
        ) : filteredGames.length === 0 ? (
          <div className="text-center py-16 text-zinc-400">
            <p className="text-sm">Inga spel matchar det valda filtret eller sökningen.</p>
          </div>
        ) : (
          <>
            {viewMode === 'shelf' && (
              <ShelfView games={filteredGames} onSelectGame={setSelectedGame} />
            )}
            {viewMode === 'grid' && (
              <GridView games={filteredGames} onSelectGame={setSelectedGame} />
            )}
            {viewMode === 'list' && (
              <ListView games={filteredGames} onSelectGame={setSelectedGame} />
            )}
          </>
        )}
      </main>

      {/* Modals */}
      <AddGameModal
        isOpen={isAddModalOpen}
        onClose={() => setIsAddModalOpen(false)}
        onGameAdded={handleGameAdded}
        existingGames={games}
      />

      <GameDetailModal
        game={selectedGame}
        isOpen={!!selectedGame}
        onClose={() => setSelectedGame(null)}
        onUpdateGame={handleUpdateGame}
        onDeleteGame={handleDeleteGame}
        collections={collections}
        onToggleCollection={handleToggleCollection}
      />

      <CollectionsModal
        isOpen={isCollectionsModalOpen}
        onClose={() => setIsCollectionsModalOpen(false)}
        collections={collections}
        games={games}
        onCreateCollection={(col) => setCollections((prev) => [col, ...prev])}
        onDeleteCollection={(id) => setCollections((prev) => prev.filter((c) => c.id !== id))}
        selectedCollectionId={selectedCollectionId}
        onSelectCollection={setSelectedCollectionId}
      />

      <PairingModal
        isOpen={isPairingModalOpen}
        onClose={() => setIsPairingModalOpen(false)}
        onPaired={handlePairedAndMerge}
      />

      <GameRouletteModal
        isOpen={isRouletteModalOpen}
        onClose={() => setIsRouletteModalOpen(false)}
        games={games}
        onSelectGame={setSelectedGame}
        onUpdateGameStatus={handleUpdateGameStatus}
        onAddGameToLibrary={handleAddDiscoveryGameToLibrary}
      />
    </div>
  );
}
