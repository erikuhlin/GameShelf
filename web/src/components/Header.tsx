'use client';

import React from 'react';
import {
  Gamepad2,
  Plus,
  LayoutGrid,
  Library,
  List,
  FolderKanban,
  Search,
  BarChart3,
  Dices,
} from 'lucide-react';
import { ProfileMenu } from './ProfileMenu';

export type ViewMode = 'shelf' | 'grid' | 'list' | 'collections' | 'stats';

interface HeaderProps {
  viewMode: ViewMode;
  onViewModeChange: (mode: ViewMode) => void;
  onOpenAddModal: () => void;
  onOpenCollectionsModal: () => void;
  onOpenPairingModal: () => void;
  onOpenRouletteModal: () => void;
  onLogout: () => void;
  searchQuery: string;
  onSearchChange: (q: string) => void;
  selectedCollectionId: string | null;
  onSelectCollection: (id: string | null) => void;
  collections: Array<{ id: string; name: string }>;
  isSyncing: boolean;
  totalGames: number;
  profileName?: string;
}

export function Header({
  viewMode,
  onViewModeChange,
  onOpenAddModal,
  onOpenCollectionsModal,
  onOpenPairingModal,
  onOpenRouletteModal,
  onLogout,
  searchQuery,
  onSearchChange,
  selectedCollectionId,
  onSelectCollection,
  collections,
  isSyncing,
  totalGames,
  profileName,
}: HeaderProps) {
  return (
    <header className="sticky top-0 z-30 bg-[#0d0e12]/90 backdrop-blur-md border-b border-zinc-800/80 px-4 lg:px-8 py-3.5">
      <div className="max-w-7xl mx-auto flex flex-col md:flex-row md:items-center md:justify-between gap-4">
        {/* Brand & Stats */}
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-brand-red to-rose-500 flex items-center justify-center shadow-lg shadow-brand-red/20 text-white font-bold cursor-pointer" onClick={() => onViewModeChange('shelf')}>
              <Gamepad2 className="w-6 h-6" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h1 className="text-xl font-bold tracking-tight text-white cursor-pointer" onClick={() => onViewModeChange('shelf')}>
                  {profileName ? `${profileName}s Gameshelf` : 'Gameshelf'}
                </h1>
                <span className="text-xs px-2 py-0.5 rounded-full bg-zinc-800 text-zinc-400 border border-zinc-700">
                  {totalGames} {totalGames === 1 ? 'spel' : 'spel'}
                </span>
              </div>
              <div className="flex items-center gap-1.5 text-xs text-zinc-400">
                <span className="inline-block w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
                <span>{profileName ? `Synkad med ${profileName}s iPhone` : 'Supabase Live Sync'}</span>
              </div>
            </div>
          </div>

          {/* Mobile Actions */}
          <div className="md:hidden flex items-center gap-2">
            <button
              onClick={onOpenRouletteModal}
              className="p-2 rounded-lg bg-zinc-900 text-amber-400 border border-amber-500/30 transition"
              title="Game Roulette (Vad ska jag spela?)"
            >
              <Dices className="w-4 h-4" />
            </button>
            <ProfileMenu
              profileName={profileName}
              isSyncing={isSyncing}
              totalGames={totalGames}
              totalCollections={collections.length}
              onOpenPairingModal={onOpenPairingModal}
              onLogout={onLogout}
            />
            <button
              onClick={() => onViewModeChange(viewMode === 'collections' ? 'shelf' : 'collections')}
              className={`p-2 rounded-lg border transition ${
                viewMode === 'collections'
                  ? 'bg-brand-red text-white border-brand-red'
                  : 'bg-zinc-800 text-zinc-200 border-zinc-700'
              }`}
              title="Samlingar"
            >
              <FolderKanban className="w-4 h-4" />
            </button>
            <button
              onClick={onOpenAddModal}
              className="flex items-center justify-center p-2 rounded-lg bg-brand-red hover:bg-brand-redPressed text-white shadow-md transition"
              title="Lägg till spel"
            >
              <Plus className="w-5 h-5" />
            </button>
          </div>
        </div>

        {/* Search & Main Nav Switcher */}
        <div className="flex flex-1 max-w-xl items-center gap-3">
          {/* Main View Tabs (Bibliotek vs Samlingar vs Statistik) */}
          <div className="flex items-center bg-zinc-900/90 border border-zinc-800 rounded-xl p-1 shrink-0">
            <button
              onClick={() => onViewModeChange('shelf')}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition ${
                viewMode !== 'collections' && viewMode !== 'stats'
                  ? 'bg-zinc-800 text-white shadow-sm'
                  : 'text-zinc-400 hover:text-zinc-200'
              }`}
            >
              <Library className="w-3.5 h-3.5" />
              <span>Bibliotek</span>
            </button>
            <button
              onClick={() => onViewModeChange('collections')}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition ${
                viewMode === 'collections'
                  ? 'bg-brand-red text-white shadow-sm'
                  : 'text-zinc-400 hover:text-zinc-200'
              }`}
            >
              <FolderKanban className="w-3.5 h-3.5" />
              <span>Samlingar</span>
              {collections.length > 0 && (
                <span className={`px-1.5 py-0.2 rounded-full text-[10px] ${
                  viewMode === 'collections' ? 'bg-white/20 text-white' : 'bg-zinc-800 text-zinc-400'
                }`}>
                  {collections.length}
                </span>
              )}
            </button>
            <button
              onClick={() => onViewModeChange('stats')}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition ${
                viewMode === 'stats'
                  ? 'bg-amber-600 text-white shadow-sm'
                  : 'text-zinc-400 hover:text-zinc-200'
              }`}
            >
              <BarChart3 className="w-3.5 h-3.5" />
              <span>Statistik</span>
            </button>
          </div>

          {/* Search bar (active in library view) */}
          <div className="relative flex-1">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-500" />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => onSearchChange(e.target.value)}
              placeholder="Filtrera bibliotek..."
              className="w-full pl-9 pr-4 py-2 text-xs bg-zinc-900/80 border border-zinc-800 rounded-xl text-zinc-100 placeholder-zinc-500 focus:outline-none focus:border-brand-red transition"
            />
          </div>
        </div>

        {/* Controls: Roulette, Profile Menu, View Switcher, Add Game */}
        <div className="flex items-center gap-2.5 self-end md:self-auto">
          {/* Game Roulette Button */}
          <button
            onClick={onOpenRouletteModal}
            className="flex items-center gap-1.5 px-3 py-2 text-xs font-semibold bg-amber-500/10 hover:bg-amber-500/20 border border-amber-500/40 text-amber-300 rounded-xl shadow-sm transition"
            title="Slumpa nästa spel ur samlingen"
          >
            <Dices className="w-3.5 h-3.5" />
            <span className="hidden sm:inline">Vad ska jag spela?</span>
          </button>

          {/* Profile & Session Menu (Desktop) */}
          <ProfileMenu
            profileName={profileName}
            isSyncing={isSyncing}
            totalGames={totalGames}
            totalCollections={collections.length}
            onOpenPairingModal={onOpenPairingModal}
            onLogout={onLogout}
          />

          {/* View Mode Toggle (Active when inside Bibliotek) */}
          {viewMode !== 'collections' && viewMode !== 'stats' && (
            <div className="flex items-center bg-zinc-900/90 border border-zinc-800 rounded-xl p-1">
              <button
                onClick={() => onViewModeChange('shelf')}
                className={`p-1.5 rounded-lg text-sm transition ${
                  viewMode === 'shelf'
                    ? 'bg-zinc-800 text-white shadow-sm'
                    : 'text-zinc-400 hover:text-zinc-200'
                }`}
                title="Hyllvy"
              >
                <Library className="w-4 h-4" />
              </button>
              <button
                onClick={() => onViewModeChange('grid')}
                className={`p-1.5 rounded-lg text-sm transition ${
                  viewMode === 'grid'
                    ? 'bg-zinc-800 text-white shadow-sm'
                    : 'text-zinc-400 hover:text-zinc-200'
                }`}
                title="Rutnätsvy"
              >
                <LayoutGrid className="w-4 h-4" />
              </button>
              <button
                onClick={() => onViewModeChange('list')}
                className={`p-1.5 rounded-lg text-sm transition ${
                  viewMode === 'list'
                    ? 'bg-zinc-800 text-white shadow-sm'
                    : 'text-zinc-400 hover:text-zinc-200'
                }`}
                title="Listvy"
              >
                <List className="w-4 h-4" />
              </button>
            </div>
          )}

          {/* Add Game Button (Desktop) */}
          <button
            onClick={onOpenAddModal}
            className="hidden md:flex items-center gap-1.5 px-4 py-2 text-xs font-semibold bg-brand-red hover:bg-brand-redPressed text-white rounded-xl shadow-md shadow-brand-red/20 transition transform active:scale-95"
          >
            <Plus className="w-4 h-4" />
            <span>Lägg till spel</span>
          </button>
        </div>
      </div>
    </header>
  );
}
