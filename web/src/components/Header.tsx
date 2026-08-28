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
  Sparkles,
} from 'lucide-react';
import { ProfileMenu } from './ProfileMenu';

export type ViewMode = 'shelf' | 'grid' | 'list' | 'discover' | 'collections' | 'stats';

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
    <>
      <header className="sticky top-0 z-30 bg-[#0d0e12]/95 backdrop-blur-md border-b border-zinc-800/80 px-3 sm:px-6 lg:px-8 py-2.5 sm:py-3.5">
        <div className="max-w-7xl mx-auto flex flex-col md:flex-row md:items-center md:justify-between gap-2.5 sm:gap-4">
          {/* Brand & Top Controls */}
          <div className="flex items-center justify-between">
            {/* Logo & Title */}
            <div
              className="flex items-center gap-2.5 sm:gap-3 cursor-pointer select-none"
              onClick={() => onViewModeChange('shelf')}
            >
              <div className="w-9 h-9 sm:w-10 sm:h-10 rounded-xl bg-gradient-to-tr from-brand-red to-rose-500 flex items-center justify-center shadow-lg shadow-brand-red/20 text-white font-bold shrink-0">
                <Gamepad2 className="w-5 h-5 sm:w-6 sm:h-6" />
              </div>
              <div>
                <div className="flex items-center gap-2">
                  <h1 className="text-base sm:text-xl font-bold tracking-tight text-white">
                    {profileName ? `${profileName}s Gameshelf` : 'Gameshelf'}
                  </h1>
                  <span className="text-[11px] sm:text-xs px-2 py-0.5 rounded-full bg-zinc-800 text-zinc-400 border border-zinc-700">
                    {totalGames} spel
                  </span>
                </div>
                <div className="flex items-center gap-1.5 text-[11px] sm:text-xs text-zinc-400">
                  <span className="inline-block w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
                  <span className="truncate max-w-[170px] sm:max-w-none">
                    {profileName ? `Synkad med iPhone` : 'Supabase Live Sync'}
                  </span>
                </div>
              </div>
            </div>

            {/* Mobile Top Actions (Profile & Add) */}
            <div className="flex md:hidden items-center gap-2">
              <ProfileMenu
                profileName={profileName}
                isSyncing={isSyncing}
                totalGames={totalGames}
                totalCollections={collections.length}
                onOpenPairingModal={onOpenPairingModal}
                onLogout={onLogout}
              />
              <button
                onClick={onOpenAddModal}
                className="flex items-center justify-center p-2 rounded-xl bg-brand-red hover:bg-brand-redPressed text-white shadow-md shadow-brand-red/20 transition transform active:scale-95"
                title="Lägg till spel"
              >
                <Plus className="w-4 h-4" />
              </button>
            </div>
          </div>

          {/* Search, Desktop Tabs & View Mode */}
          <div className="flex flex-1 max-w-xl items-center gap-2 sm:gap-3">
            {/* Desktop Navigation Tabs */}
            <div className="hidden md:flex items-center bg-zinc-900/90 border border-zinc-800 rounded-xl p-1 shrink-0">
              <button
                onClick={() => onViewModeChange('shelf')}
                className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition ${
                  viewMode === 'shelf' || viewMode === 'grid' || viewMode === 'list'
                    ? 'bg-zinc-800 text-white shadow-sm'
                    : 'text-zinc-400 hover:text-zinc-200'
                }`}
              >
                <Library className="w-3.5 h-3.5" />
                <span>Bibliotek</span>
              </button>
              <button
                onClick={() => onViewModeChange('discover')}
                className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition ${
                  viewMode === 'discover'
                    ? 'bg-brand-red text-white shadow-sm'
                    : 'text-zinc-400 hover:text-zinc-200'
                }`}
              >
                <Sparkles className="w-3.5 h-3.5" />
                <span>Utforska</span>
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
                  <span
                    className={`px-1.5 py-0.2 rounded-full text-[10px] ${
                      viewMode === 'collections'
                        ? 'bg-white/20 text-white'
                        : 'bg-zinc-800 text-zinc-400'
                    }`}
                  >
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

            {/* Mobile View Mode Switcher (Compact in Search row) */}
            {viewMode !== 'collections' && viewMode !== 'stats' && (
              <div className="flex md:hidden items-center bg-zinc-900 border border-zinc-800 rounded-xl p-1 shrink-0">
                <button
                  onClick={() => onViewModeChange('shelf')}
                  className={`p-1.5 rounded-lg text-xs transition ${
                    viewMode === 'shelf'
                      ? 'bg-zinc-800 text-white'
                      : 'text-zinc-400 hover:text-zinc-200'
                  }`}
                  title="Hylla"
                >
                  <Library className="w-3.5 h-3.5" />
                </button>
                <button
                  onClick={() => onViewModeChange('grid')}
                  className={`p-1.5 rounded-lg text-xs transition ${
                    viewMode === 'grid'
                      ? 'bg-zinc-800 text-white'
                      : 'text-zinc-400 hover:text-zinc-200'
                  }`}
                  title="Rutnät"
                >
                  <LayoutGrid className="w-3.5 h-3.5" />
                </button>
                <button
                  onClick={() => onViewModeChange('list')}
                  className={`p-1.5 rounded-lg text-xs transition ${
                    viewMode === 'list'
                      ? 'bg-zinc-800 text-white'
                      : 'text-zinc-400 hover:text-zinc-200'
                  }`}
                  title="Lista"
                >
                  <List className="w-3.5 h-3.5" />
                </button>
              </div>
            )}
          </div>

          {/* Desktop Controls (Roulette, Profile, View Switcher, Add Game) */}
          <div className="hidden md:flex items-center gap-2.5">
            <button
              onClick={onOpenRouletteModal}
              className="flex items-center gap-1.5 px-3 py-2 text-xs font-semibold bg-amber-500/10 hover:bg-amber-500/20 border border-amber-500/40 text-amber-300 rounded-xl shadow-sm transition"
              title="Slumpa nästa spel ur samlingen"
            >
              <Dices className="w-3.5 h-3.5" />
              <span>Vad ska jag spela?</span>
            </button>

            <ProfileMenu
              profileName={profileName}
              isSyncing={isSyncing}
              totalGames={totalGames}
              totalCollections={collections.length}
              onOpenPairingModal={onOpenPairingModal}
              onLogout={onLogout}
            />

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

            <button
              onClick={onOpenAddModal}
              className="flex items-center gap-1.5 px-4 py-2 text-xs font-semibold bg-brand-red hover:bg-brand-redPressed text-white rounded-xl shadow-md shadow-brand-red/20 transition transform active:scale-95"
            >
              <Plus className="w-4 h-4" />
              <span>Lägg till spel</span>
            </button>
          </div>
        </div>
      </header>

      {/* Sleek Native Mobile Bottom Navigation Bar */}
      <nav className="md:hidden fixed bottom-0 left-0 right-0 z-40 bg-[#0d0e12]/95 backdrop-blur-xl border-t border-zinc-800/80 px-2 py-1.5 flex items-center justify-around shadow-2xl safe-bottom">
        <button
          onClick={() => onViewModeChange('shelf')}
          className={`flex flex-col items-center gap-1 py-1 px-2 rounded-xl transition ${
            viewMode === 'shelf' || viewMode === 'grid' || viewMode === 'list'
              ? 'text-brand-red font-bold'
              : 'text-zinc-400 hover:text-zinc-200'
          }`}
        >
          <Library className="w-5 h-5" />
          <span className="text-[10px]">Bibliotek</span>
        </button>

        <button
          onClick={() => onViewModeChange('discover')}
          className={`flex flex-col items-center gap-1 py-1 px-2 rounded-xl transition ${
            viewMode === 'discover'
              ? 'text-brand-red font-bold'
              : 'text-zinc-400 hover:text-zinc-200'
          }`}
        >
          <Sparkles className="w-5 h-5" />
          <span className="text-[10px]">Utforska</span>
        </button>

        <button
          onClick={onOpenAddModal}
          className="flex flex-col items-center justify-center -mt-4 w-12 h-12 rounded-full bg-gradient-to-tr from-brand-red to-rose-500 text-white shadow-lg shadow-brand-red/30 transition transform active:scale-95"
          title="Lägg till spel"
        >
          <Plus className="w-6 h-6" />
        </button>

        <button
          onClick={() => onViewModeChange('collections')}
          className={`relative flex flex-col items-center gap-1 py-1 px-2 rounded-xl transition ${
            viewMode === 'collections'
              ? 'text-brand-red font-bold'
              : 'text-zinc-400 hover:text-zinc-200'
          }`}
        >
          <FolderKanban className="w-5 h-5" />
          <span className="text-[10px]">Samlingar</span>
          {collections.length > 0 && (
            <span className="absolute top-0 right-1 w-3.5 h-3.5 rounded-full bg-brand-red text-white text-[8px] flex items-center justify-center font-bold">
              {collections.length}
            </span>
          )}
        </button>

        <button
          onClick={() => onViewModeChange('stats')}
          className={`flex flex-col items-center gap-1 py-1 px-2 rounded-xl transition ${
            viewMode === 'stats'
              ? 'text-amber-400 font-bold'
              : 'text-zinc-400 hover:text-zinc-200'
          }`}
        >
          <BarChart3 className="w-5 h-5" />
          <span className="text-[10px]">Statistik</span>
        </button>
      </nav>
    </>
  );
}
