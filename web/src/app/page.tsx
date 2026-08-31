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
import { DiscoverView } from '@/components/DiscoverView';
import { UniversalSearchModal } from '@/components/UniversalSearchModal';
import { ProfileModal } from '@/components/ProfileModal';
import { CompanyModal } from '@/components/CompanyModal';
import { UserProfile } from '@/types/profile';
import { loadUserProfile, saveUserProfile, DEFAULT_PROFILE } from '@/lib/profileStore';
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
  Gamepad2,
  Plus,
  Library,
  LayoutGrid,
  List,
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
  const [userProfile, setUserProfile] = useState<UserProfile>(DEFAULT_PROFILE);

  // Modals
  const [isAddModalOpen, setIsAddModalOpen] = useState(false);
  const [isSearchModalOpen, setIsSearchModalOpen] = useState(false);
  const [isCollectionsModalOpen, setIsCollectionsModalOpen] = useState(false);
  const [isPairingModalOpen, setIsPairingModalOpen] = useState(false);
  const [isRouletteModalOpen, setIsRouletteModalOpen] = useState(false);
  const [isProfileModalOpen, setIsProfileModalOpen] = useState(false);
  const [activeCompanyModal, setActiveCompanyModal] = useState<{
    id: number;
    name: string;
    role: 'developer' | 'publisher';
  } | null>(null);
  const [selectedGame, setSelectedGame] = useState<Game | null>(null);
  const [isSyncing, setIsSyncing] = useState(false);

  // Global snabbtangent: ⌘K / Ctrl+K för Spotlight
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
        e.preventDefault();
        setIsSearchModalOpen((prev) => !prev);
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, []);

  // 1. Initialisera sessionsdata vid första rendering
  useEffect(() => {
    if (typeof window !== 'undefined') {
      const savedUserId = localStorage.getItem('gameshelf_paired_user_id');
      const loaded = loadUserProfile();
      setUserProfile(loaded);
      setProfileName(loaded.username);
      if (savedUserId) setPairedUserId(savedUserId);

      const handleProfileUpdate = () => {
        const p = loadUserProfile();
        setUserProfile(p);
        setProfileName(p.username);
      };
      window.addEventListener('gameshelf_profile_updated', handleProfileUpdate);
      return () => window.removeEventListener('gameshelf_profile_updated', handleProfileUpdate);
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

  const handleAddFromDiscover = async (gameToAdd: Game) => {
    const newGamePayload = {
      id: crypto.randomUUID(),
      user_id: pairedUserId || undefined,
      title: gameToAdd.title,
      cover_url: gameToAdd.cover_url || null,
      platforms: gameToAdd.platforms || [],
      release_year: gameToAdd.release_year || null,
      first_release_date: gameToAdd.first_release_date || null,
      genres: gameToAdd.genres || [],
      developers: gameToAdd.developers || [],
      status: 'Önskelista' as PlayStatus,
      rating: null,
      igdb_rating: gameToAdd.igdb_rating || null,
      igdb_id: gameToAdd.igdb_id || null,
      estimated_hours: null,
      is_owned: false,
      notes: '',
      todos: [],
    };

    if (pairedUserId) {
      let { data, error } = await supabase
        .from('user_games')
        .insert([newGamePayload])
        .select()
        .single();

      if (error && error.message?.includes('first_release_date')) {
        const { first_release_date, ...fallbackPayload } = newGamePayload;
        const retry = await supabase.from('user_games').insert([fallbackPayload]).select().single();
        data = retry.data;
      }
    }

    const createdGame: Game = {
      ...newGamePayload,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    setGames((prev) => {
      const updated = [createdGame, ...prev];
      if (typeof window !== 'undefined') {
        localStorage.setItem('gameshelf_local_games', JSON.stringify(updated));
      }
      return updated;
    });
  };

  const activeCollection = collections.find((c) => c.id === selectedCollectionId);

  return (
    <div className="min-h-screen bg-[#0d0e12] text-zinc-100 flex flex-col">
      {/* Navigation Header */}
      <Header
        viewMode={viewMode}
        onViewModeChange={setViewMode}
        onOpenAddModal={() => setIsAddModalOpen(true)}
        onOpenSearchModal={() => setIsSearchModalOpen(true)}
        onOpenCollectionsModal={() => setIsCollectionsModalOpen(false)}
        onOpenPairingModal={() => setIsPairingModalOpen(true)}
        onOpenProfileModal={() => setIsProfileModalOpen(true)}
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
        profile={userProfile}
      />

      {/* Main Content Area */}
      <main className="flex-1 max-w-7xl w-full mx-auto px-3 sm:px-6 lg:px-8 py-4 sm:py-6 space-y-4 sm:space-y-6 pb-28 md:pb-12">
        {/* Guest Mode Banner (Visas enbart om man har spel lokalt men inte är inloggad) */}
        {!profileName && games.length > 0 && (
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 p-4 rounded-2xl bg-zinc-900/80 border border-zinc-800 shadow-md animate-in fade-in duration-200">
            <div className="flex items-center gap-3">
              <div className="w-9 h-9 rounded-xl bg-zinc-800 border border-zinc-700 flex items-center justify-center text-zinc-400 shrink-0">
                <Smartphone className="w-4 h-4 text-brand-red" />
              </div>
              <div>
                <h4 className="text-xs sm:text-sm font-bold text-white flex items-center gap-2">
                  <span>Gästläge aktivt</span>
                  <span className="text-[10px] px-2 py-0.5 rounded-full bg-zinc-800 text-zinc-400 font-semibold border border-zinc-700">
                    {games.length} {games.length === 1 ? 'spel sparat' : 'spel sparade'} lokalt
                  </span>
                </h4>
                <p className="text-[11px] text-zinc-400 mt-0.5">
                  Spelen sparas i din webbläsare. Logga in med iPhone för att synka dem till ditt konto.
                </p>
              </div>
            </div>

            <div className="flex items-center gap-2 self-start sm:self-auto">
              <button
                onClick={() => {
                  if (confirm('Vill du rensa dina lokala gästspel?')) {
                    handleLogout();
                  }
                }}
                className="flex items-center justify-center gap-1.5 px-3 py-1.5 rounded-xl bg-zinc-950 hover:bg-zinc-800 text-zinc-400 hover:text-rose-400 text-xs font-medium border border-zinc-800 transition"
                title="Rensa lokalt gästbibliotek"
              >
                <Trash2 className="w-3.5 h-3.5" />
                <span>Rensa</span>
              </button>

              <button
                onClick={() => setIsPairingModalOpen(true)}
                className="flex items-center justify-center gap-1.5 px-3.5 py-1.5 rounded-xl bg-brand-red hover:bg-brand-redPressed text-white text-xs font-semibold shadow-md transition whitespace-nowrap"
              >
                <Smartphone className="w-3.5 h-3.5" />
                <span>Logga in</span>
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

        {/* Library Sub-bar: Status Filter Tabs & View Mode Switcher */}
        {viewMode !== 'collections' && viewMode !== 'stats' && viewMode !== 'discover' && games.length > 0 && (
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-1">
            {/* Left: Status Filter Pills */}
            <div className="flex items-center gap-1.5 overflow-x-auto pb-1 sm:pb-0 scrollbar-none">
              <button
                onClick={() => setSelectedStatus('Alla')}
                className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-semibold whitespace-nowrap transition ${
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
                    className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-semibold whitespace-nowrap transition ${
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

            {/* Right: View Mode Switcher (Hylla | Grid | Lista) */}
            <div className="flex items-center self-end sm:self-auto bg-zinc-900/90 border border-zinc-800/90 rounded-xl p-1 shrink-0">
              <button
                onClick={() => setViewMode('shelf')}
                className={`flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-medium transition ${
                  viewMode === 'shelf'
                    ? 'bg-zinc-800 text-white shadow-sm'
                    : 'text-zinc-400 hover:text-zinc-200'
                }`}
                title="Hyllvy"
              >
                <Library className="w-3.5 h-3.5" />
                <span className="hidden sm:inline">Hylla</span>
              </button>
              <button
                onClick={() => setViewMode('grid')}
                className={`flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-medium transition ${
                  viewMode === 'grid'
                    ? 'bg-zinc-800 text-white shadow-sm'
                    : 'text-zinc-400 hover:text-zinc-200'
                }`}
                title="Rutnätsvy"
              >
                <LayoutGrid className="w-3.5 h-3.5" />
                <span className="hidden sm:inline">Rutnät</span>
              </button>
              <button
                onClick={() => setViewMode('list')}
                className={`flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-medium transition ${
                  viewMode === 'list'
                    ? 'bg-zinc-800 text-white shadow-sm'
                    : 'text-zinc-400 hover:text-zinc-200'
                }`}
                title="Listvy"
              >
                <List className="w-3.5 h-3.5" />
                <span className="hidden sm:inline">Lista</span>
              </button>
            </div>
          </div>
        )}

        {/* Views Switcher: Discover, Collections, Stats, or Library (Shelf, Grid, List) */}
        {viewMode === 'discover' ? (
          <DiscoverView
            games={games}
            onSelectGame={setSelectedGame}
            onAddGame={handleAddFromDiscover}
            onOpenRouletteModal={() => setIsRouletteModalOpen(true)}
          />
        ) : viewMode === 'collections' ? (
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
          <div className="flex flex-col items-center justify-center py-20 sm:py-28 text-center px-4 rounded-3xl border border-zinc-800/80 bg-gradient-to-b from-zinc-900/40 via-zinc-950/60 to-zinc-950/80 shadow-2xl max-w-2xl mx-auto my-6">
            <div className="w-16 h-16 sm:w-20 sm:h-20 rounded-2xl bg-gradient-to-tr from-brand-red to-rose-500 flex items-center justify-center text-white mb-5 shadow-xl shadow-brand-red/20">
              <Gamepad2 className="w-8 h-8 sm:w-10 sm:h-10" />
            </div>
            <h2 className="text-2xl sm:text-3xl font-bold text-white mb-2 tracking-tight">
              Välkommen till Gameshelf
            </h2>
            <p className="text-sm text-zinc-400 max-w-md mb-8 leading-relaxed">
              Ditt personliga spelbibliotek i webben och på mobilen. Synka direkt med din iPhone eller börja utforska och lägga till spel med ett klick.
            </p>
            <div className="flex flex-col sm:flex-row items-center justify-center gap-3 w-full max-w-sm">
              <button
                onClick={() => setIsPairingModalOpen(true)}
                className="w-full sm:w-auto flex items-center justify-center gap-2 px-5 py-3 rounded-xl bg-brand-red hover:bg-brand-redPressed text-white text-sm font-semibold transition shadow-lg shadow-brand-red/25 active:scale-95"
              >
                <Smartphone className="w-4 h-4" />
                <span>Logga in med iPhone</span>
              </button>
              <button
                onClick={() => setIsAddModalOpen(true)}
                className="w-full sm:w-auto flex items-center justify-center gap-2 px-5 py-3 rounded-xl bg-zinc-900 hover:bg-zinc-800 text-zinc-200 text-sm font-semibold border border-zinc-700/80 transition active:scale-95"
              >
                <Plus className="w-4 h-4" />
                <span>Lägg till spel</span>
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
        onOpenCompany={(companyId, companyName, role) => {
          setActiveCompanyModal({ id: companyId, name: companyName, role });
        }}
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

      <UniversalSearchModal
        isOpen={isSearchModalOpen}
        onClose={() => setIsSearchModalOpen(false)}
        games={games}
        onSelectGame={setSelectedGame}
        onAddGame={handleAddFromDiscover}
      />

      <ProfileModal
        isOpen={isProfileModalOpen}
        onClose={() => setIsProfileModalOpen(false)}
        profile={userProfile}
        onUpdateProfile={(updated) => {
          setUserProfile(updated);
          setProfileName(updated.username);
        }}
        libraryGames={games}
        onSelectGame={(igdbId) => {
          const local = games.find((g) => g.igdb_id === igdbId);
          if (local) {
            setSelectedGame(local);
          }
        }}
      />

      {activeCompanyModal && (
        <CompanyModal
          companyId={activeCompanyModal.id}
          companyName={activeCompanyModal.name}
          role={activeCompanyModal.role}
          isOpen={Boolean(activeCompanyModal)}
          onClose={() => setActiveCompanyModal(null)}
          libraryGames={games}
          onAddGame={async (newGame) => {
            const gameToAdd: Game = {
              id: crypto.randomUUID(),
              title: newGame.title,
              igdb_id: newGame.igdbId,
              cover_url: newGame.coverUrl || null,
              release_year: newGame.releaseYear || null,
              genres: newGame.genres,
              developers: newGame.developers,
              platforms: newGame.platforms,
              status: 'Önskelista',
              is_owned: false,
              notes: '',
              todos: [],
            };
            await handleAddFromDiscover(gameToAdd);
          }}
          onSelectGame={(igdbId) => {
            const local = games.find((g) => g.igdb_id === igdbId);
            if (local) {
              setSelectedGame(local);
            }
          }}
        />
      )}
    </div>
  );
}
