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
  Sparkles,
} from 'lucide-react';
import { ProfileMenu } from './ProfileMenu';

import { UserProfile } from '@/types/profile';

export type ViewMode = 'shelf' | 'grid' | 'list' | 'discover' | 'collections' | 'stats';

interface HeaderProps {
  viewMode: ViewMode;
  onViewModeChange: (mode: ViewMode) => void;
  onOpenAddModal: () => void;
  onOpenCollectionsModal: () => void;
  onOpenPairingModal: () => void;
  onOpenProfileModal?: () => void;
  onOpenRouletteModal: () => void;
  onOpenSearchModal: () => void;
  onLogout: () => void;
  searchQuery: string;
  onSearchChange: (q: string) => void;
  selectedCollectionId: string | null;
  onSelectCollection: (id: string | null) => void;
  collections: Array<{ id: string; name: string }>;
  isSyncing: boolean;
  totalGames: number;
  profileName?: string;
  profile?: UserProfile;
}

export function Header({
  viewMode,
  onViewModeChange,
  onOpenAddModal,
  onOpenPairingModal,
  onOpenProfileModal,
  onOpenSearchModal,
  onLogout,
  searchQuery,
  onSearchChange,
  collections,
  isSyncing,
  totalGames,
  profileName,
  profile,
}: HeaderProps) {
  const isLibraryActive =
    viewMode === 'shelf' || viewMode === 'grid' || viewMode === 'list';

  return (
    <>
      <header className="sticky top-0 z-30 bg-[#0d0e12]/95 backdrop-blur-xl border-b border-zinc-800/80 px-4 sm:px-6 lg:px-8 py-3">
        <div className="max-w-7xl mx-auto flex items-center justify-between gap-4">
          {/* 1. Left Zone: Clean Logo & Brand */}
          <div
            className="flex items-center gap-3 cursor-pointer select-none shrink-0"
            onClick={() => onViewModeChange('shelf')}
          >
            <div className="w-9 h-9 rounded-xl bg-gradient-to-tr from-brand-red to-rose-500 flex items-center justify-center shadow-lg shadow-brand-red/25 text-white shrink-0">
              <Gamepad2 className="w-5 h-5" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h1 className="text-base font-bold tracking-tight text-white leading-none">
                  Gameshelf
                </h1>
                {profileName && (
                  <span className="text-[11px] text-zinc-400 font-medium hidden sm:inline">
                    • {profileName}
                  </span>
                )}
              </div>
              <div className="flex items-center gap-1.5 text-[11px] text-zinc-400 mt-1">
                <span
                  className={`inline-block w-1.5 h-1.5 rounded-full ${
                    profileName
                      ? 'bg-emerald-500 animate-pulse'
                      : totalGames > 0
                      ? 'bg-amber-500'
                      : 'bg-zinc-600'
                  }`}
                />
                <span className="truncate max-w-[130px] sm:max-w-none text-zinc-400">
                  {profileName
                    ? 'Synkad med iPhone'
                    : totalGames > 0
                    ? 'Gästläge (lokal)'
                    : 'Ej inloggad'}
                </span>
              </div>
            </div>
          </div>

          {/* 2. Center Zone: Floating Navigation Pill (Desktop) */}
          <nav className="hidden md:flex items-center bg-zinc-900/90 border border-zinc-800/90 rounded-2xl p-1 shadow-inner">
            <button
              onClick={() => onViewModeChange('shelf')}
              className={`flex items-center gap-1.5 px-4 py-1.5 rounded-xl text-xs font-semibold transition ${
                isLibraryActive
                  ? 'bg-zinc-800 text-white shadow-sm'
                  : 'text-zinc-400 hover:text-zinc-200'
              }`}
            >
              <Library className="w-3.5 h-3.5" />
              <span>Bibliotek</span>
            </button>

            <button
              onClick={() => onViewModeChange('discover')}
              className={`flex items-center gap-1.5 px-4 py-1.5 rounded-xl text-xs font-semibold transition ${
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
              className={`flex items-center gap-1.5 px-4 py-1.5 rounded-xl text-xs font-semibold transition ${
                viewMode === 'collections'
                  ? 'bg-brand-red text-white shadow-sm'
                  : 'text-zinc-400 hover:text-zinc-200'
              }`}
            >
              <FolderKanban className="w-3.5 h-3.5" />
              <span>Samlingar</span>
              {collections.length > 0 && (
                <span
                  className={`px-1.5 py-0.2 rounded-full text-[10px] font-bold ${
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
              className={`flex items-center gap-1.5 px-4 py-1.5 rounded-xl text-xs font-semibold transition ${
                viewMode === 'stats'
                  ? 'bg-amber-600 text-white shadow-sm'
                  : 'text-zinc-400 hover:text-zinc-200'
              }`}
            >
              <BarChart3 className="w-3.5 h-3.5" />
              <span>Statistik</span>
            </button>
          </nav>

          {/* 3. Right Zone: Global Actions */}
          <div className="flex items-center gap-2.5">
            {/* Combined Search & Add Trigger (⌘K) */}
            <button
              onClick={onOpenSearchModal}
              className="flex items-center gap-2 px-3 py-1.5 rounded-xl bg-brand-red hover:bg-brand-redPressed text-white transition shadow-md shadow-brand-red/20 transform active:scale-95 whitespace-nowrap"
              title="Sök & Lägg till spel (⌘K)"
            >
              <Search className="w-3.5 h-3.5" />
              <span className="text-xs font-bold hidden sm:inline">Sök & Lägg till</span>
              <kbd className="hidden lg:inline-flex items-center gap-0.5 px-1.5 py-0.5 rounded bg-red-700/60 text-[10px] font-mono text-white/80 border border-red-600/40">
                ⌘K
              </kbd>
            </button>

            {/* Profile Dropdown / Login */}
            <ProfileMenu
              profileName={profileName}
              profile={profile}
              isSyncing={isSyncing}
              totalGames={totalGames}
              totalCollections={collections.length}
              onOpenPairingModal={onOpenPairingModal}
              onOpenProfileModal={onOpenProfileModal}
              onLogout={onLogout}
            />
          </div>
        </div>
      </header>

      {/* Sleek Native Mobile Bottom Navigation Bar */}
      <nav className="md:hidden fixed bottom-0 left-0 right-0 z-40 bg-[#0d0e12]/95 backdrop-blur-xl border-t border-zinc-800/80 px-2 py-1.5 flex items-center justify-around shadow-2xl safe-bottom">
        <button
          onClick={() => onViewModeChange('shelf')}
          className={`flex flex-col items-center gap-1 py-1 px-2 rounded-xl transition ${
            isLibraryActive
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
          onClick={onOpenSearchModal}
          className="flex flex-col items-center justify-center -mt-4 w-12 h-12 rounded-full bg-gradient-to-tr from-brand-red to-rose-500 text-white shadow-lg shadow-brand-red/30 transition transform active:scale-95"
          title="Sök & Lägg till spel"
        >
          <Search className="w-5 h-5" />
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
