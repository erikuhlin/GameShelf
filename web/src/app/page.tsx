'use client';

import React, { useState, useEffect, useMemo } from 'react';
import { Game, GameCollection, PlayStatus, PLAY_STATUSES } from '@/types/game';
import { supabase, mapSupabaseGame, mapSupabaseCollection } from '@/lib/supabase';
import { getStatusDisplayTitle, inferPlayTypes } from '@/lib/statusHelper';
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
  ArrowUpDown,
} from 'lucide-react';

export type LibrarySortOption =
  | 'dateAdded'
  | 'titleAsc'
  | 'titleDesc'
  | 'rating'
  | 'releaseYearDesc'
  | 'releaseYearAsc'
  | 'hours';

export default function HomePage() {
  const [games, setGames] = useState<Game[]>([]);
  const [collections, setCollections] = useState<GameCollection[]>([]);
  const [viewMode, setViewMode] = useState<ViewMode>('shelf');
  const [selectedStatus, setSelectedStatus] = useState<PlayStatus | 'Alla' | 'Backlog'>('Alla');
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCollectionId, setSelectedCollectionId] = useState<string | null>(null);
  const [profileName, setProfileName] = useState<string>('');
  const [pairedUserId, setPairedUserId] = useState<string | null>(null);
  const [userProfile, setUserProfile] = useState<UserProfile>(DEFAULT_PROFILE);

  // Library Sorting & Filtering state
  const [librarySort, setLibrarySort] = useState<LibrarySortOption>('dateAdded');
  const [libraryPlatformFilter, setLibraryPlatformFilter] = useState<string>('Alla');
  const [libraryOwnershipFilter, setLibraryOwnershipFilter] = useState<'all' | 'owned' | 'wishlist'>('all');

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
      const cachedGames = localStorage.getItem('gameshelf_local_games');
      const cachedCols = localStorage.getItem('gameshelf_local_collections');

      if (cachedGames) {
        try {
          const parsed = JSON.parse(cachedGames);
          if (Array.isArray(parsed) && parsed.length > 0) {
            setGames(parsed);
          }
        } catch (e) {}
      }

      if (cachedCols) {
        try {
          const parsedCols = JSON.parse(cachedCols);
          if (Array.isArray(parsedCols) && parsedCols.length > 0) {
            setCollections(parsedCols);
          }
        } catch (e) {}
      }

      const savedSort = localStorage.getItem('gameshelf_library_sort') as LibrarySortOption;
      if (savedSort) setLibrarySort(savedSort);
      const savedPlatform = localStorage.getItem('gameshelf_library_platform');
      if (savedPlatform) setLibraryPlatformFilter(savedPlatform);
      const savedOwnership = localStorage.getItem('gameshelf_library_ownership') as any;
      if (savedOwnership) {
        setLibraryOwnershipFilter(savedOwnership === 'memories' ? 'wishlist' : savedOwnership);
      }

      const loaded = loadUserProfile();
      setUserProfile(loaded);
      setProfileName(loaded.username);
      if (savedUserId) {
        setPairedUserId(savedUserId);
        fetchRemoteProfile(savedUserId);
      }

      const handleProfileUpdate = () => {
        const p = loadUserProfile();
        setUserProfile(p);
        setProfileName(p.username);
      };
      window.addEventListener('gameshelf_profile_updated', handleProfileUpdate);
      return () => window.removeEventListener('gameshelf_profile_updated', handleProfileUpdate);
    }
  }, []);

  const fetchRemoteProfile = async (userId: string) => {
    try {
      const { data, error } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', userId)
        .single();

      if (!error && data) {
        let prefs: any = {};
        if (data.full_name) {
          try {
            prefs = JSON.parse(data.full_name);
          } catch {}
        }
        const updated: UserProfile = {
          username: data.username || 'Spelare',
          age: prefs.age || 27,
          platforms: Array.isArray(prefs.platforms) ? prefs.platforms : ['PlayStation 5', 'PC'],
          favoriteGenres: Array.isArray(prefs.favoriteGenres) ? prefs.favoriteGenres : ['RPG', 'Action', 'Skräck'],
          playFor: Array.isArray(prefs.playFor) ? prefs.playFor : ['Story', 'Utforskning'],
          favoriteGameIDs: Array.isArray(prefs.favoriteGameIDs) ? prefs.favoriteGameIDs : [],
          targetGameIDs: Array.isArray(prefs.targetGameIDs) ? prefs.targetGameIDs : [],
          annualGamingGoal: prefs.annualGamingGoal || 12,
          avatarType: data.avatar_url || prefs.avatarType || 'initial',
          avatarCustomImage: data.avatar_url?.startsWith('data:') ? data.avatar_url : undefined,
        };
        setUserProfile(updated);
        setProfileName(updated.username);
        saveUserProfile(updated);
      }
    } catch (e) {
      console.error('Kunde inte läsa in profil från Supabase:', e);
    }
  };

  const handleUpdateProfile = async (updated: UserProfile) => {
    setUserProfile(updated);
    setProfileName(updated.username);
    saveUserProfile(updated);

    if (pairedUserId) {
      const prefs = {
        age: updated.age,
        platforms: updated.platforms,
        favoriteGenres: updated.favoriteGenres,
        playFor: updated.playFor,
        favoriteGameIDs: updated.favoriteGameIDs,
        targetGameIDs: updated.targetGameIDs || [],
        annualGamingGoal: updated.annualGamingGoal,
        avatarType: updated.avatarType,
      };
      try {
        await supabase.from('profiles').upsert({
          id: pairedUserId,
          username: updated.username,
          full_name: JSON.stringify(prefs),
          avatar_url: updated.avatarCustomImage || updated.avatarType,
          updated_at: new Date().toISOString(),
        });
      } catch (err) {
        console.error('Kunde inte synka profil till Supabase:', err);
      }
    }
  };

  // Realtidssynk för profilen
  useEffect(() => {
    if (!pairedUserId) return;

    fetchRemoteProfile(pairedUserId);

    const profileChannel = supabase
      .channel(`profile:${pairedUserId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'profiles',
          filter: `id=eq.${pairedUserId}`,
        },
        (payload: any) => {
          if (payload.new) {
            const data = payload.new;
            let prefs: any = {};
            if (data.full_name) {
              try {
                prefs = JSON.parse(data.full_name);
              } catch {}
            }
            const updated: UserProfile = {
              username: data.username || 'Spelare',
              age: prefs.age || 27,
              platforms: Array.isArray(prefs.platforms) ? prefs.platforms : ['PlayStation 5', 'PC'],
              favoriteGenres: Array.isArray(prefs.favoriteGenres) ? prefs.favoriteGenres : ['RPG', 'Action', 'Skräck'],
              playFor: Array.isArray(prefs.playFor) ? prefs.playFor : ['Story', 'Utforskning'],
              favoriteGameIDs: Array.isArray(prefs.favoriteGameIDs) ? prefs.favoriteGameIDs : [],
              targetGameIDs: Array.isArray(prefs.targetGameIDs) ? prefs.targetGameIDs : [],
              annualGamingGoal: prefs.annualGamingGoal || 12,
              avatarType: data.avatar_url || prefs.avatarType || 'initial',
              avatarCustomImage: data.avatar_url?.startsWith('data:') ? data.avatar_url : undefined,
            };
            setUserProfile(updated);
            setProfileName(updated.username);
            saveUserProfile(updated);
          }
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(profileChannel);
    };
  }, [pairedUserId]);

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
          setGames((prev) => {
            const existingMap = new Map(prev.map((g) => [g.id, g]));
            const mapped = gamesRes.data.map((row: any) => {
              const game = mapSupabaseGame(row);
              const existing = existingMap.get(game.id);
              if (!game.first_release_date && existing?.first_release_date) {
                game.first_release_date = existing.first_release_date;
              }
              if (!game.igdb_id && existing?.igdb_id) {
                game.igdb_id = existing.igdb_id;
              }
              return game;
            });

            if (typeof window !== 'undefined') {
              localStorage.setItem('gameshelf_local_games', JSON.stringify(mapped));
            }

            // Berika saknade spel i bakgrunden
            enrichGamesWithReleaseDates(mapped, pairedUserId);
            return mapped;
          });
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

  // Filterändringshandlers med localStorage-persistens
  const handleSortChange = (sort: LibrarySortOption) => {
    setLibrarySort(sort);
    if (typeof window !== 'undefined') localStorage.setItem('gameshelf_library_sort', sort);
  };
  const handlePlatformChange = (p: string) => {
    setLibraryPlatformFilter(p);
    if (typeof window !== 'undefined') localStorage.setItem('gameshelf_library_platform', p);
  };
  const handleOwnershipChange = (o: 'all' | 'owned' | 'wishlist') => {
    setLibraryOwnershipFilter(o);
    if (typeof window !== 'undefined') localStorage.setItem('gameshelf_library_ownership', o);
  };

  // Dynamiska plattformar som finns i biblioteket
  const availablePlatforms = useMemo(() => {
    const set = new Set<string>();
    games.forEach((g) => {
      (g.platforms || []).forEach((p) => {
        const lower = p.toLowerCase();
        if (
          lower.includes('playstation') ||
          lower.includes('ps5') ||
          lower.includes('ps4') ||
          lower.includes('ps3') ||
          lower.includes('ps2') ||
          lower.includes('ps1') ||
          lower.includes('psp') ||
          lower.includes('vita')
        ) {
          set.add('PlayStation');
        } else if (lower.includes('xbox')) {
          set.add('Xbox');
        } else if (
          lower.includes('nintendo') ||
          lower.includes('switch') ||
          lower.includes('wii') ||
          lower.includes('ds') ||
          lower.includes('game boy') ||
          lower.includes('nes') ||
          lower.includes('snes') ||
          lower.includes('n64') ||
          lower.includes('gamecube')
        ) {
          set.add('Nintendo');
        } else if (
          lower.includes('pc') ||
          lower.includes('windows') ||
          lower.includes('mac') ||
          lower.includes('linux')
        ) {
          set.add('PC');
        } else {
          set.add(p);
        }
      });
    });
    return ['Alla', ...Array.from(set).sort()];
  }, [games]);

  // Hjälpfunktion för att hämta lanserings-tidsstämpel i millisekunder
  const getReleaseTimestamp = (game: Game): number => {
    if (game.first_release_date) {
      return game.first_release_date < 1e11
        ? game.first_release_date * 1000
        : game.first_release_date;
    }
    if (game.release_year && game.release_year > 0) {
      return new Date(game.release_year, 0, 1).getTime();
    }
    return 0;
  };

  // Aktiva spel som spelas just nu
  const playingNowGames = useMemo(() => {
    return games.filter(
      (g) =>
        (g.status === 'playing' || (g.status as string) === 'Spelar nu') &&
        g.is_owned
    );
  }, [games]);

  // Filtrerade och sorterade spel
  const filteredGames = useMemo(() => {
    let result = games.filter((game) => {
      // 1. Spelstatus filter
      if (selectedStatus === 'Backlog') {
        if (!game.is_backlog) return false;
      } else if (selectedStatus !== 'Alla' && game.status !== selectedStatus) {
        return false;
      }

      // 2. Ägarskapsfilter / Önskelista
      if (libraryOwnershipFilter === 'owned' && !game.is_owned) {
        return false;
      }
      if (libraryOwnershipFilter === 'wishlist' && game.is_owned) {
        return false;
      }

      // 3. Plattformsfilter
      if (libraryPlatformFilter !== 'Alla') {
        const pFilter = libraryPlatformFilter.toLowerCase();
        const hasPlatform = (game.platforms || []).some((p) => {
          const lp = p.toLowerCase();
          if (pFilter === 'playstation') {
            return lp.includes('playstation') || lp.includes('ps');
          }
          if (pFilter === 'xbox') {
            return lp.includes('xbox');
          }
          if (pFilter === 'nintendo') {
            return (
              lp.includes('nintendo') ||
              lp.includes('switch') ||
              lp.includes('wii') ||
              lp.includes('ds')
            );
          }
          if (pFilter === 'pc') {
            return (
              lp.includes('pc') ||
              lp.includes('windows') ||
              lp.includes('mac') ||
              lp.includes('linux')
            );
          }
          return lp.includes(pFilter);
        });
        if (!hasPlatform) return false;
      }

      // 4. Samlingsfilter
      if (selectedCollectionId) {
        const col = collections.find((c) => c.id === selectedCollectionId);
        const matchesCol = Boolean(
          col &&
            (col.game_ids?.includes(game.id) ||
              (game.igdb_id && col.game_ids?.includes(String(game.igdb_id))))
        );
        if (!matchesCol) {
          return false;
        }
      }

      // 5. Textsökning
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

    // 6. Sortering
    switch (librarySort) {
      case 'titleAsc':
        result.sort((a, b) => a.title.localeCompare(b.title, 'sv'));
        break;
      case 'titleDesc':
        result.sort((a, b) => b.title.localeCompare(a.title, 'sv'));
        break;
      case 'rating':
        result.sort((a, b) => (b.rating || 0) - (a.rating || 0));
        break;
      case 'releaseYearDesc':
        // Jämför lanseringsdatum kronologiskt fallande (nyast först) baserat på exakt datum
        result.sort((a, b) => {
          const dateA = getReleaseTimestamp(a);
          const dateB = getReleaseTimestamp(b);
          if (dateA !== dateB) {
            if (dateA === 0) return 1;
            if (dateB === 0) return -1;
            return dateB - dateA;
          }
          return a.title.localeCompare(b.title, 'sv');
        });
        break;
      case 'releaseYearAsc':
        // Jämför lanseringsdatum kronologiskt stigande (äldst först) baserat på exakt datum
        result.sort((a, b) => {
          const dateA = getReleaseTimestamp(a);
          const dateB = getReleaseTimestamp(b);
          if (dateA !== dateB) {
            if (dateA === 0) return 1;
            if (dateB === 0) return -1;
            return dateA - dateB;
          }
          return a.title.localeCompare(b.title, 'sv');
        });
        break;
      case 'hours':
        result.sort(
          (a, b) => (Number(b.estimated_hours) || 0) - (Number(a.estimated_hours) || 0)
        );
        break;
      case 'dateAdded':
      default:
        // Behåll standardordning (senast tillagda/index)
        break;
    }

    return result;
  }, [
    games,
    selectedStatus,
    libraryOwnershipFilter,
    libraryPlatformFilter,
    selectedCollectionId,
    searchQuery,
    collections,
    librarySort,
  ]);

  // Status counts for tab pills
  const statusCounts = useMemo(() => {
    const relevant = games.filter((g) =>
      libraryOwnershipFilter === 'owned'
        ? g.is_owned
        : libraryOwnershipFilter === 'wishlist'
        ? !g.is_owned
        : true
    );
    const counts: { [k: string]: number } = { Alla: relevant.length };
    PLAY_STATUSES.forEach((s) => {
      counts[s] = relevant.filter((g) => g.status === s).length;
    });
    counts['Backlog'] = relevant.filter((g) => g.is_backlog).length;
    return counts;
  }, [games, libraryOwnershipFilter]);

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
    const isPlaying = newStatus === 'playing';
    const isCompleted = newStatus === 'completed';
    const currentYear = new Date().getFullYear();

    setGames((prev) => {
      const next = prev.map((g) =>
        g.id === gameId
          ? {
              ...g,
              status: newStatus,
              is_backlog: isPlaying ? false : g.is_backlog,
              last_played_date: isPlaying
                ? g.last_played_date || new Date().toISOString()
                : g.last_played_date,
              completed_year: isCompleted ? (g.completed_year || currentYear) : g.completed_year,
              completed_date: isCompleted ? (g.completed_date || new Date().toISOString()) : g.completed_date,
            }
          : g
      );
      if (typeof window !== 'undefined') {
        localStorage.setItem('gameshelf_local_games', JSON.stringify(next));
      }
      return next;
    });

    try {
      const updatePayload: any = {
        status: newStatus,
        ...(isPlaying ? { is_backlog: false } : {}),
      };
      if (isCompleted) {
        updatePayload.completed_year = currentYear;
        updatePayload.completed_date = new Date().toISOString();
      }
      await supabase
        .from('user_games')
        .update(updatePayload)
        .eq('id', gameId);
    } catch (err) {
      console.error('Failed to update game status:', err);
    }
  };

  const handleAddDiscoveryGameToLibrary = async (game: Game) => {
    let pairedUserId: string | null = null;
    if (typeof window !== 'undefined') {
      pairedUserId = localStorage.getItem('gameshelf_paired_user_id');
    }

    const playTypes = game.play_types || inferPlayTypes(game);
    const payload = {
      user_id: pairedUserId,
      title: game.title,
      cover_url: game.cover_url || null,
      platforms: game.platforms || [],
      release_year: game.release_year || null,
      genres: game.genres || [],
      developers: game.developers || [],
      status: game.status || 'notStarted',
      is_owned: game.is_owned ?? false,
      is_backlog: game.is_backlog ?? false,
      play_types: playTypes,
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

  const handleToggleTargetGoal = (gameId: string) => {
    if (!userProfile) return;
    const current = userProfile.targetGameIDs || [];
    let next: string[];
    if (current.includes(gameId)) {
      next = current.filter((id) => id !== gameId);
    } else {
      next = current.length >= 3 ? [...current.slice(1), gameId] : [...current, gameId];
    }
    handleUpdateProfile({
      ...userProfile,
      targetGameIDs: next,
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

  const handleCreateCollectionAndAddGame = async (name: string, gameId: string) => {
    const trimmed = name.trim();
    if (!trimmed) return;

    const newColId = crypto.randomUUID();
    const newCol: GameCollection = {
      id: newColId,
      name: trimmed,
      description: '',
      game_ids: [gameId],
      created_at: new Date().toISOString(),
    };

    setCollections((prev) => {
      const next = [newCol, ...prev];
      if (typeof window !== 'undefined') {
        localStorage.setItem('gameshelf_local_collections', JSON.stringify(next));
      }
      return next;
    });

    if (pairedUserId) {
      try {
        await supabase.from('collections').insert({
          id: newColId,
          user_id: pairedUserId,
          name: trimmed,
          game_ids: [gameId],
        });
      } catch (err) {
        console.error('Failed to create collection in Supabase:', err);
      }
    }
  };

  const handleLogout = () => {
    if (typeof window !== 'undefined') {
      localStorage.removeItem('gameshelf_profile_name');
      localStorage.removeItem('gameshelf_paired_user_id');
      localStorage.removeItem('gameshelf_user_profile');
      localStorage.removeItem('gameshelf_local_games');
      localStorage.removeItem('gameshelf_local_collections');
    }
    setProfileName('');
    setUserProfile(DEFAULT_PROFILE);
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
    if (userId) {
      await fetchRemoteProfile(userId);
    }

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
    const playTypes = gameToAdd.play_types || inferPlayTypes(gameToAdd);
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
      status: (gameToAdd.status || 'notStarted') as PlayStatus,
      rating: null,
      igdb_rating: gameToAdd.igdb_rating || null,
      igdb_id: gameToAdd.igdb_id || null,
      estimated_hours: null,
      is_owned: false,
      is_backlog: false,
      play_types: playTypes,
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
          <div className="space-y-2">
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
                  {statusCounts['Alla'] || 0}
                </span>
              </button>

              {/* Backlog Tab */}
              {libraryOwnershipFilter !== 'wishlist' && (
                <button
                  onClick={() => setSelectedStatus('Backlog')}
                  className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-semibold whitespace-nowrap transition ${
                    selectedStatus === 'Backlog'
                      ? 'bg-blue-600 text-white shadow-md'
                      : 'bg-zinc-900/80 text-blue-300 hover:text-blue-200 border border-blue-900/40'
                  }`}
                >
                  <span>Backlog</span>
                  <span
                    className={`px-1.5 py-0.2 rounded-full text-[10px] ${
                      selectedStatus === 'Backlog'
                        ? 'bg-blue-800 text-white'
                        : 'bg-blue-950 text-blue-300'
                    }`}
                  >
                    {statusCounts['Backlog'] || 0}
                  </span>
                </button>
              )}

              {PLAY_STATUSES.map((status) => {
                const isSelected = selectedStatus === status;
                const count = statusCounts[status] || 0;
                const label = getStatusDisplayTitle(status, false);
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
                    <span>{label}</span>
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

          {/* Sub-toolbar: Sortering & Anpassa biblioteksvyn */}
          <div className="flex flex-wrap items-center justify-between gap-3 pt-2 pb-2 border-t border-zinc-800/60 text-xs">
            {/* Vänster: Sorteringsdropdown & Plattformsfilter */}
            <div className="flex items-center gap-2.5 flex-wrap">
              <div className="flex items-center gap-1.5 text-zinc-400 font-medium">
                <ArrowUpDown className="w-3.5 h-3.5 text-brand-red" />
                <span>Sortera:</span>
              </div>
              <select
                value={librarySort}
                onChange={(e) => handleSortChange(e.target.value as LibrarySortOption)}
                className="bg-zinc-900 border border-zinc-800 text-zinc-200 text-xs rounded-xl px-3 py-1.5 focus:outline-none focus:border-brand-red cursor-pointer font-medium hover:border-zinc-700 transition"
              >
                <option value="dateAdded">Senast tillagda</option>
                <option value="titleAsc">Titel (A–Ö)</option>
                <option value="titleDesc">Titel (Ö–A)</option>
                <option value="rating">Högst betyg ⭐</option>
                <option value="releaseYearDesc">Lanseringsdatum (Nyast först)</option>
                <option value="releaseYearAsc">Lanseringsdatum (Äldst först)</option>
                <option value="hours">Speltid ⏱️</option>
              </select>

              {/* Plattformsfilter */}
              {availablePlatforms.length > 2 && (
                <div className="flex items-center gap-2">
                  <span className="text-zinc-600 hidden sm:inline">•</span>
                  <select
                    value={libraryPlatformFilter}
                    onChange={(e) => handlePlatformChange(e.target.value)}
                    className="bg-zinc-900 border border-zinc-800 text-zinc-200 text-xs rounded-xl px-3 py-1.5 focus:outline-none focus:border-brand-red cursor-pointer font-medium hover:border-zinc-700 transition"
                  >
                    {availablePlatforms.map((p) => (
                      <option key={p} value={p}>
                        {p === 'Alla' ? 'Alla plattformar' : p}
                      </option>
                    ))}
                  </select>
                </div>
              )}
            </div>

            {/* Höger: Ägarskapsfilter (Alla / I ägo / Önskelista) */}
            <div className="flex items-center gap-1 bg-zinc-900/90 border border-zinc-800/90 rounded-xl p-1 shrink-0">
              <button
                onClick={() => handleOwnershipChange('all')}
                className={`px-3 py-1 rounded-lg text-xs font-medium transition cursor-pointer ${
                  libraryOwnershipFilter === 'all'
                    ? 'bg-zinc-800 text-white shadow-sm'
                    : 'text-zinc-400 hover:text-zinc-200'
                }`}
              >
                Alla ({games.length})
              </button>
              <button
                onClick={() => handleOwnershipChange('owned')}
                className={`px-3 py-1 rounded-lg text-xs font-medium transition cursor-pointer ${
                  libraryOwnershipFilter === 'owned'
                    ? 'bg-zinc-800 text-white shadow-sm'
                    : 'text-zinc-400 hover:text-zinc-200'
                }`}
                title="Endast spel du äger i ditt bibliotek"
              >
                I ägo 🎮 ({games.filter((g) => g.is_owned).length})
              </button>
              <button
                onClick={() => handleOwnershipChange('wishlist')}
                className={`px-3 py-1 rounded-lg text-xs font-medium transition cursor-pointer ${
                  libraryOwnershipFilter === 'wishlist'
                    ? 'bg-zinc-800 text-white shadow-sm'
                    : 'text-zinc-400 hover:text-zinc-200'
                }`}
                title="Spel på din önskelista"
              >
                Önskelista 🎁 ({games.filter((g) => !g.is_owned).length})
              </button>
            </div>
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
            userProfile={userProfile}
            onOpenProfileModal={() => setIsProfileModalOpen(true)}
            onUpdateProfile={handleUpdateProfile}
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
            {/* Spelar just nu - horisontell strip överst i biblioteket (motsvarande appen) */}
            {selectedStatus === 'Alla' &&
              !searchQuery.trim() &&
              libraryOwnershipFilter !== 'wishlist' &&
              playingNowGames.length > 0 && (
                <div className="mb-6 space-y-2.5">
                  <div className="flex items-center gap-2">
                    <span className="relative flex h-2.5 w-2.5">
                      <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75" />
                      <span className="relative inline-flex rounded-full h-2.5 w-2.5 bg-emerald-500" />
                    </span>
                    <h3 className="text-xs font-black text-white uppercase tracking-wider">
                      Spelar just nu
                    </h3>
                    <span className="text-xs text-zinc-500 font-semibold">
                      ({playingNowGames.length})
                    </span>
                  </div>

                  <div className="flex items-center gap-3 overflow-x-auto pb-2 scrollbar-none">
                    {playingNowGames.map((game) => (
                      <div
                        key={`playing-${game.id}`}
                        onClick={() => setSelectedGame(game)}
                        className="flex items-center gap-3 p-2 bg-zinc-900/80 hover:bg-zinc-800/80 border border-zinc-800/80 hover:border-zinc-700 rounded-2xl cursor-pointer transition flex-shrink-0 w-64 sm:w-72 shadow-md group"
                      >
                        <div className="w-12 h-16 rounded-xl overflow-hidden bg-zinc-800 flex-shrink-0 border border-zinc-700/60 aspect-[3/4]">
                          {game.cover_url ? (
                            <img
                              src={game.cover_url}
                              alt={game.title}
                              className="w-full h-full object-cover group-hover:scale-105 transition duration-200"
                            />
                          ) : (
                            <div className="w-full h-full flex items-center justify-center text-zinc-600">
                              🎮
                            </div>
                          )}
                        </div>
                        <div className="min-w-0 flex-1">
                          <div className="flex items-center gap-1.5 mb-1">
                            {game.platforms && game.platforms[0] && (
                              <span className="text-[10px] font-bold text-emerald-400 bg-emerald-500/10 px-2 py-0.5 rounded-full">
                                {game.platforms[0]}
                              </span>
                            )}
                            {game.rating && (
                              <span className="text-[10px] font-bold text-amber-400 ml-auto flex items-center gap-0.5">
                                ★ {game.rating}
                              </span>
                            )}
                          </div>
                          <h4 className="text-xs font-bold text-white line-clamp-2 leading-tight group-hover:text-brand-red transition">
                            {game.title}
                          </h4>
                          <p className="text-[11px] text-zinc-400 mt-0.5 truncate">
                            {game.developers?.[0] ||
                              (game.estimated_hours ? `${game.estimated_hours}h speltid` : 'Aktiv')}
                          </p>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}

            {viewMode === 'shelf' && (
              <ShelfView games={filteredGames} onSelectGame={setSelectedGame} />
            )}
            {viewMode === 'grid' && (
              <GridView
                games={filteredGames}
                onSelectGame={setSelectedGame}
                groupByYear={librarySort === 'releaseYearDesc' || librarySort === 'releaseYearAsc'}
              />
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
        onCreateCollection={handleCreateCollectionAndAddGame}
        onOpenCompany={(companyId, companyName, role) => {
          setActiveCompanyModal({ id: companyId, name: companyName, role });
        }}
        isTargetGoal={Boolean(selectedGame && userProfile?.targetGameIDs?.includes(selectedGame.id))}
        onToggleTargetGoal={handleToggleTargetGoal}
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
        onOpenCompany={(companyId, companyName, role) => {
          setActiveCompanyModal({
            id: companyId,
            name: companyName,
            role,
          });
        }}
      />

      <ProfileModal
        isOpen={isProfileModalOpen}
        onClose={() => setIsProfileModalOpen(false)}
        profile={userProfile}
        onUpdateProfile={handleUpdateProfile}
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
              status: 'notStarted',
              is_owned: false,
              is_backlog: false,
              play_types: inferPlayTypes({ title: newGame.title, genres: newGame.genres }),
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
