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
  Trash2,
} from 'lucide-react';

export default function HomePage() {
  const [games, setGames] = useState<Game[]>([]);
  const [collections, setCollections] = useState<GameCollection[]>([]);
  const [viewMode, setViewMode] = useState<ViewMode>('shelf');
  const [selectedStatus, setSelectedStatus] = useState<PlayStatus | 'Alla'>('Alla');
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCollectionId, setSelectedCollectionId] = useState<string | null>(null);
  const [profileName, setProfileName] = useState<string>('');
  const [pairedUserId, setPairedUserId] = useState<string | null>(null);

  // Modals
  const [isAddModalOpen, setIsAddModalOpen] = useState(false);
  const [isCollectionsModalOpen, setIsCollectionsModalOpen] = useState(false);
  const [isPairingModalOpen, setIsPairingModalOpen] = useState(false);
  const [isRouletteModalOpen, setIsRouletteModalOpen] = useState(false);
  const [selectedGame, setSelectedGame] = useState<Game | null>(null);
  const [isSyncing, setIsSyncing] = useState(false);

  // 1. Initialisera sessionsdata vid första rendering
  useEffect(() => {
    if (typeof window !== 'undefined') {
      const savedUserId = localStorage.getItem('gameshelf_paired_user_id');
      const savedName = localStorage.getItem('gameshelf_profile_name');
      if (savedName) setProfileName(savedName);
      if (savedUserId) setPairedUserId(savedUserId);
    }
  }, []);

  // Hjälpfunktion för att berika spel med IGDB releasedatum i bakgrunden
  const enrichGamesWithReleaseDates = (
    gameList: Game[],
    currentUserId?: string | null
  ) => {
    const gamesNeedingDates = gameList.filter((g) => !g.first_release_date);
    if (gamesNeedingDates.length === 0) return;

    gamesNeedingDates.forEach(async (g) => {
      try {
        let date: number | null = null;
        let igdbId: number | null = g.igdb_id ? Number(g.igdb_id) : null;
        const currentYear = new Date().getFullYear();

        if (igdbId) {
          const res = await fetch(`/api/igdb/games/${igdbId}`);
          if (res.ok) {
            const data = await res.json();
            const fetchedDate = data?.game?.first_release_date || null;
            const fetchedYear = fetchedDate
              ? new Date(fetchedDate * 1000).getFullYear()
              : data?.game?.release_year;

            if (
              g.release_year &&
              g.release_year >= currentYear &&
              fetchedYear &&
              fetchedYear < currentYear
            ) {
              date = null;
              igdbId = null;
            } else {
              date = fetchedDate;
            }
          }
        }

        if (!date && g.title) {
          const res = await fetch(`/api/igdb/search?q=${encodeURIComponent(g.title)}`);
          if (res.ok) {
            const data = await res.json();
            const results = data?.results || data?.games || [];
            const targetTitle = g.title.toLowerCase().trim();

            let bestMatch = g.release_year
              ? results.find((r: any) => {
                  const y = r.first_release_date
                    ? new Date(r.first_release_date * 1000).getFullYear()
                    : r.release_year;
                  return r.name?.toLowerCase().trim() === targetTitle && y === g.release_year;
                })
              : null;

            if (!bestMatch && g.release_year && g.release_year >= currentYear) {
              bestMatch = results.find((r: any) => {
                const y = r.first_release_date
                  ? new Date(r.first_release_date * 1000).getFullYear()
                  : r.release_year;
                return r.name?.toLowerCase().trim() === targetTitle && y && y >= currentYear;
              });
            }

            if (!bestMatch) {
              bestMatch = results.find((r: any) => r.name?.toLowerCase().trim() === targetTitle);
            }

            if (!bestMatch) {
              bestMatch = results.find((r: any) => r.name?.toLowerCase().trim().startsWith(targetTitle));
            }

            if (!bestMatch && results.length > 0) {
              bestMatch = results[0];
            }

            if (bestMatch?.first_release_date) {
              date = bestMatch.first_release_date;
              if (bestMatch.id) {
                igdbId = bestMatch.id;
              }
            }
          }
        }

        if (date) {

          if (currentUserId) {
            supabase
              .from('user_games')
              .update({
                first_release_date: date,
                ...(igdbId ? { igdb_id: igdbId } : {}),
              })
              .eq('id', g.id)
              .then(() => {});
          }

          setGames((prev) => {
            const next = prev.map((item) =>
              item.id === g.id
                ? {
                    ...item,
                    first_release_date: date,
                    ...(igdbId ? { igdb_id: igdbId } : {}),
                  }
                : item
            );
            if (typeof window !== 'undefined') {
              localStorage.setItem('gameshelf_local_games', JSON.stringify(next));
            }
            return next;
          });

          setSelectedGame((curr) =>
            curr?.id === g.id
              ? {
                  ...curr,
                  first_release_date: date,
                  ...(igdbId ? { igdb_id: igdbId } : {}),
                }
              : curr
          );
        }
      } catch (e) {}
    });
  };

  // 2. Hämta bibliotek & prenumerera på Supabase Realtime för den parkopplade användaren
  useEffect(() => {
    // Om ej inloggad / gästläge: Ladda från webbläsarens lokala minne
    if (!pairedUserId) {
      if (typeof window !== 'undefined') {
        const cachedGames = localStorage.getItem('gameshelf_local_games');
        const cachedCols = localStorage.getItem('gameshelf_local_collections');
        if (cachedGames) {
          try {
            const parsed = JSON.parse(cachedGames);
            if (Array.isArray(parsed)) {
              setGames(parsed);
              enrichGamesWithReleaseDates(parsed, null);
            }
          } catch (e) {}
        }
        if (cachedCols) {
          try {
            const parsedCols = JSON.parse(cachedCols);
            if (Array.isArray(parsedCols)) setCollections(parsedCols);
          } catch (e) {}
        }
      }
      setIsSyncing(false);
      return;
    }

    setIsSyncing(true);

    async function loadRemoteLibrary() {
      try {
        const [gamesRes, colRes] = await Promise.all([
          supabase
            .from('user_games')
            .select('*')
            .eq('user_id', pairedUserId)
            .order('created_at', { ascending: false }),
          supabase
            .from('collections')
            .select('*')
            .eq('user_id', pairedUserId)
            .order('created_at', { ascending: false }),
        ]);

        if (gamesRes.data) {
          const mapped = gamesRes.data.map(mapSupabaseGame);
          setGames(mapped);
          if (typeof window !== 'undefined') {
            localStorage.setItem('gameshelf_local_games', JSON.stringify(mapped));
          }

          // Berika befintliga spel i bakgrunden
          enrichGamesWithReleaseDates(mapped, pairedUserId);
        }

        if (colRes.data) {
          const mappedCols = colRes.data.map(mapSupabaseCollection);
          setCollections(mappedCols);
          if (typeof window !== 'undefined') {
            localStorage.setItem('gameshelf_local_collections', JSON.stringify(mappedCols));
          }
        }
      } catch (err) {
        console.warn('Could not fetch from Supabase:', err);
      } finally {
        setIsSyncing(false);
      }
    }

    loadRemoteLibrary();

    // Supabase Realtime Channel för användarens spel
    const gamesChannel = supabase
      .channel(`public:user_games:${pairedUserId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'user_games',
          filter: `user_id=eq.${pairedUserId}`,
        },
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

    // Supabase Realtime Channel för användarens samlingar
    const collectionsChannel = supabase
      .channel(`public:collections:${pairedUserId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'collections',
          filter: `user_id=eq.${pairedUserId}`,
        },
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
            setCollections((prev) =>
              prev.map((c) => (c.id === updated.id ? updated : c))
            );
          } else if (payload.eventType === 'DELETE') {
            const deletedId = payload.old?.id;
            if (deletedId) {
              setCollections((prev) => prev.filter((c) => c.id !== deletedId));
              if (selectedCollectionId === deletedId) {
                setSelectedCollectionId(null);
              }
            }
          }
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(gamesChannel);
      supabase.removeChannel(collectionsChannel);
    };
  }, [pairedUserId]);

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
    setPairedUserId(null);
    setGames([]);
    setCollections([]);
    setSelectedCollectionId(null);
  };

  const handlePairedAndMerge = async (userId: string, username?: string) => {
    const user = username?.trim() || (userId ? 'Spelare' : '');
    if (typeof window !== 'undefined') {
      if (user) localStorage.setItem('gameshelf_profile_name', user);
      if (userId) localStorage.setItem('gameshelf_paired_user_id', userId);
    }
    setProfileName(user);

    // Identifiera gästspel som skapats lokalt och migrera dem till användarens konto
    try {
      const { data: dbGames } = await supabase
        .from('user_games')
        .select('title, igdb_id')
        .eq('user_id', userId);

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

    setPairedUserId(userId);
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
      <main className="flex-1 max-w-7xl w-full mx-auto px-3 sm:px-6 lg:px-8 py-4 sm:py-6 space-y-4 sm:space-y-6 pb-28 md:pb-12">
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

            <div className="flex items-center gap-2 self-start sm:self-auto">
              {games.length > 0 && (
                <button
                  onClick={() => {
                    if (confirm('Vill du rensa dina lokala gästspel?')) {
                      handleLogout();
                    }
                  }}
                  className="flex items-center justify-center gap-1.5 px-3 py-2 rounded-xl bg-zinc-900/90 hover:bg-zinc-800 text-zinc-400 hover:text-rose-400 text-xs font-medium border border-zinc-700/80 transition"
                  title="Rensa lokalt gästbibliotek"
                >
                  <Trash2 className="w-3.5 h-3.5" />
                  <span>Rensa lokal data</span>
                </button>
              )}

              <button
                onClick={() => setIsPairingModalOpen(true)}
                className="flex items-center justify-center gap-1.5 px-4 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold shadow-md transition whitespace-nowrap"
              >
                <Smartphone className="w-3.5 h-3.5" />
                <span>Logga in med iPhone</span>
              </button>
            </div>
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
