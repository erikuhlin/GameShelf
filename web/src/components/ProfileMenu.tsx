'use client';

import React, { useState, useRef, useEffect } from 'react';
import {
  Smartphone,
  LogOut,
  User,
  ShieldCheck,
  ChevronDown,
  RefreshCw,
  QrCode,
  Layers,
} from 'lucide-react';

import { UserProfile } from '@/types/profile';
import { AVATAR_PRESETS } from '@/lib/profileStore';

interface ProfileMenuProps {
  profileName?: string;
  profile?: UserProfile;
  isSyncing: boolean;
  totalGames: number;
  totalCollections: number;
  onOpenPairingModal: () => void;
  onOpenProfileModal?: () => void;
  onLogout: () => void;
}

export function ProfileMenu({
  profileName,
  profile,
  isSyncing,
  totalGames,
  totalCollections,
  onOpenPairingModal,
  onOpenProfileModal,
  onLogout,
}: ProfileMenuProps) {
  const [isOpen, setIsOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);

  // Close when clicking outside
  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (menuRef.current && !menuRef.current.contains(event.target as Node)) {
        setIsOpen(false);
      }
    }
    if (isOpen) {
      document.addEventListener('mousedown', handleClickOutside);
    }
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, [isOpen]);

  // If not logged in / paired, render Login/Pair button
  if (!profileName) {
    return (
      <button
        onClick={onOpenPairingModal}
        className="flex items-center gap-2 px-3 py-1.5 text-xs font-semibold bg-zinc-900 hover:bg-zinc-800 text-zinc-200 border border-zinc-700/80 hover:border-zinc-600 rounded-xl transition shadow-sm active:scale-95"
        title="Logga in med iPhone"
      >
        <Smartphone className="w-3.5 h-3.5 text-brand-red" />
        <span>Logga in</span>
      </button>
    );
  }

  const renderAvatar = (size: 'sm' | 'md' = 'sm') => {
    if (profile?.avatarType === 'custom' && profile.avatarCustomImage) {
      return (
        <img
          src={profile.avatarCustomImage}
          alt="Avatar"
          className={`${size === 'sm' ? 'w-6 h-6' : 'w-10 h-10'} rounded-full object-cover shadow-inner`}
        />
      );
    }
    if (profile?.avatarType?.startsWith('preset:')) {
      const preset = AVATAR_PRESETS.find((p) => p.id === profile.avatarType);
      if (preset) {
        return (
          <div
            style={{
              background: `linear-gradient(135deg, ${preset.gradientColors[0]}, ${preset.gradientColors[1]})`,
            }}
            className={`${
              size === 'sm' ? 'w-6 h-6 text-xs' : 'w-10 h-10 text-lg'
            } rounded-full flex items-center justify-center shadow-inner`}
          >
            <span>{preset.icon}</span>
          </div>
        );
      }
    }
    const initial = (profileName || profile?.username || 'S').charAt(0).toUpperCase();
    return (
      <div
        className={`${
          size === 'sm' ? 'w-6 h-6 text-xs' : 'w-10 h-10 text-sm'
        } rounded-full bg-gradient-to-tr from-brand-red to-rose-500 text-white flex items-center justify-center font-bold shadow-inner`}
      >
        {initial}
      </div>
    );
  };

  return (
    <div className="relative" ref={menuRef}>
      {/* Profile Button */}
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="flex items-center gap-2.5 px-3 py-1.5 bg-zinc-900/90 hover:bg-zinc-800 border border-zinc-800 hover:border-zinc-700 rounded-xl transition shadow-sm"
      >
        {/* Avatar */}
        <div className="relative">
          {renderAvatar('sm')}
          <span className="absolute -bottom-0.5 -right-0.5 w-2 h-2 rounded-full bg-emerald-500 ring-2 ring-zinc-900 animate-pulse" />
        </div>

        {/* Name */}
        <span className="text-xs font-semibold text-zinc-200 hidden sm:inline">
          {profileName}
        </span>

        <ChevronDown
          className={`w-3.5 h-3.5 text-zinc-400 transition-transform duration-200 ${
            isOpen ? 'rotate-180' : ''
          }`}
        />
      </button>

      {/* Dropdown Menu */}
      {isOpen && (
        <div className="absolute right-0 mt-2 w-72 bg-[#14151b] border border-zinc-800 rounded-2xl shadow-2xl p-2 z-50 animate-in fade-in slide-in-from-top-2 duration-150">
          {/* Header info */}
          <div className="p-3 bg-zinc-950/60 rounded-xl border border-zinc-800/80 mb-2">
            <div className="flex items-center gap-3">
              <div className="relative shrink-0">
                {renderAvatar('md')}
              </div>
              <div className="overflow-hidden">
                <h4 className="text-sm font-bold text-white truncate">{profileName}</h4>
                <div className="flex items-center gap-1.5 text-[11px] text-emerald-400 font-medium">
                  <span className="w-1.5 h-1.5 rounded-full bg-emerald-500"></span>
                  <span>Ansluten iPhone</span>
                </div>
              </div>
            </div>

            {/* Quick Stats in Menu */}
            <div className="grid grid-cols-2 gap-2 mt-3 pt-2.5 border-t border-zinc-800/80 text-center">
              <div className="bg-zinc-900/80 rounded-lg py-1.5 px-2">
                <div className="text-xs font-bold text-white">{totalGames}</div>
                <div className="text-[10px] text-zinc-400">Spel i hyllan</div>
              </div>
              <div className="bg-zinc-900/80 rounded-lg py-1.5 px-2">
                <div className="text-xs font-bold text-white">{totalCollections}</div>
                <div className="text-[10px] text-zinc-400">Samlingar</div>
              </div>
            </div>
          </div>

          {/* Menu Items */}
          <div className="space-y-1">
            <button
              onClick={() => {
                setIsOpen(false);
                onOpenProfileModal?.();
              }}
              className="w-full flex items-center gap-2.5 px-3 py-2 text-xs font-medium text-zinc-300 hover:text-white hover:bg-zinc-800/80 rounded-xl transition"
            >
              <User className="w-4 h-4 text-brand-red" />
              <span>Min profil & Spel-DNA</span>
            </button>

            <button
              onClick={() => {
                setIsOpen(false);
                onOpenPairingModal();
              }}
              className="w-full flex items-center gap-2.5 px-3 py-2 text-xs font-medium text-zinc-300 hover:text-white hover:bg-zinc-800/80 rounded-xl transition"
            >
              <QrCode className="w-4 h-4 text-zinc-400" />
              <span>Koppla en annan iPhone / Visa kod</span>
            </button>

            <button
              onClick={() => {
                setIsOpen(false);
                if (confirm('Vill du koppla från och logga ut från denna webbläsare?')) {
                  onLogout();
                }
              }}
              className="w-full flex items-center gap-2.5 px-3 py-2 text-xs font-semibold text-rose-400 hover:text-rose-300 hover:bg-rose-950/40 rounded-xl transition"
            >
              <LogOut className="w-4 h-4 text-rose-400" />
              <span>Logga ut / Koppla från</span>
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
