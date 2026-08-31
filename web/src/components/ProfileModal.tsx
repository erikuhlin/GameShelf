'use client';

import React, { useState, useMemo, useRef } from 'react';
import {
  X,
  Camera,
  Edit2,
  Check,
  Plus,
  Trash2,
  Sparkles,
  Gamepad2,
  Heart,
  Target,
  Trophy,
  HelpCircle,
  Upload,
} from 'lucide-react';
import { Game } from '@/types/game';
import { UserProfile } from '@/types/profile';
import { calculateSpelDNA } from '@/lib/spelDNA';
import {
  AVATAR_PRESETS,
  DEFAULT_PLATFORMS,
  DEFAULT_GENRES,
  DEFAULT_PLAY_FOR,
  saveUserProfile,
} from '@/lib/profileStore';

interface ProfileModalProps {
  isOpen: boolean;
  onClose: () => void;
  profile: UserProfile;
  onUpdateProfile: (updated: UserProfile) => void;
  libraryGames: Game[];
  onSelectGame?: (igdbId: number) => void;
}

export function ProfileModal({
  isOpen,
  onClose,
  profile,
  onUpdateProfile,
  libraryGames,
  onSelectGame,
}: ProfileModalProps) {
  const [activeTab, setActiveTab] = useState<'profile' | 'avatar'>('profile');
  const [editingName, setEditingName] = useState(false);
  const [nameInput, setNameInput] = useState(profile.username);
  const [ageInput, setAgeInput] = useState(profile.age.toString());
  const [isAddingFavorite, setIsAddingFavorite] = useState(false);
  const [favoriteSearch, setFavoriteSearch] = useState('');
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Beräkna Spel-DNA
  const spelDNA = useMemo(() => {
    return calculateSpelDNA(libraryGames, profile.playFor);
  }, [libraryGames, profile.playFor]);

  // Hämta favoritspelobjekt
  const favoriteGames = useMemo(() => {
    return profile.favoriteGameIDs
      .map((id) => libraryGames.find((g) => g.id === id))
      .filter((g): g is Game => Boolean(g));
  }, [profile.favoriteGameIDs, libraryGames]);

  // Spel som kan läggas till i favoriter (ur biblioteket)
  const availableForFavorites = useMemo(() => {
    const search = favoriteSearch.toLowerCase().trim();
    return libraryGames.filter((g) => {
      const alreadyFav = profile.favoriteGameIDs.includes(g.id);
      if (alreadyFav) return false;
      if (!search) return true;
      return g.title.toLowerCase().includes(search);
    });
  }, [libraryGames, profile.favoriteGameIDs, favoriteSearch]);

  if (!isOpen) return null;

  const handleTogglePlatform = (plat: string) => {
    const current = new Set(profile.platforms);
    if (current.has(plat)) {
      current.delete(plat);
    } else {
      current.add(plat);
    }
    const updated = { ...profile, platforms: Array.from(current) };
    onUpdateProfile(updated);
    saveUserProfile(updated);
  };

  const handleToggleGenre = (genre: string) => {
    const current = new Set(profile.favoriteGenres);
    if (current.has(genre)) {
      current.delete(genre);
    } else {
      current.add(genre);
    }
    const updated = { ...profile, favoriteGenres: Array.from(current) };
    onUpdateProfile(updated);
    saveUserProfile(updated);
  };

  const handleTogglePlayFor = (motive: string) => {
    const current = new Set(profile.playFor);
    if (current.has(motive)) {
      current.delete(motive);
    } else {
      current.add(motive);
    }
    const updated = { ...profile, playFor: Array.from(current) };
    onUpdateProfile(updated);
    saveUserProfile(updated);
  };

  const handleSaveIdentity = () => {
    const trimmed = nameInput.trim();
    const ageNum = parseInt(ageInput, 10);
    const updated = {
      ...profile,
      username: trimmed || profile.username,
      age: isNaN(ageNum) || ageNum <= 0 ? profile.age : ageNum,
    };
    onUpdateProfile(updated);
    saveUserProfile(updated);
    setEditingName(false);
  };

  const handleAddFavorite = (gameId: string) => {
    if (profile.favoriteGameIDs.length >= 10) return;
    const updated = {
      ...profile,
      favoriteGameIDs: [...profile.favoriteGameIDs, gameId],
    };
    onUpdateProfile(updated);
    saveUserProfile(updated);
    setIsAddingFavorite(false);
    setFavoriteSearch('');
  };

  const handleRemoveFavorite = (gameId: string) => {
    const updated = {
      ...profile,
      favoriteGameIDs: profile.favoriteGameIDs.filter((id) => id !== gameId),
    };
    onUpdateProfile(updated);
    saveUserProfile(updated);
  };

  const handleSelectAvatarPreset = (presetId: string) => {
    const updated = { ...profile, avatarType: presetId };
    onUpdateProfile(updated);
    saveUserProfile(updated);
    setActiveTab('profile');
  };

  const handleSelectInitial = () => {
    const updated = { ...profile, avatarType: 'initial' };
    onUpdateProfile(updated);
    saveUserProfile(updated);
    setActiveTab('profile');
  };

  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (event) => {
      const base64 = event.target?.result as string;
      if (base64) {
        const updated = {
          ...profile,
          avatarType: 'custom',
          avatarCustomImage: base64,
        };
        onUpdateProfile(updated);
        saveUserProfile(updated);
        setActiveTab('profile');
      }
    };
    reader.readAsDataURL(file);
  };

  // Rendera vald avatar
  const renderAvatarContent = (size: 'sm' | 'md' | 'lg' = 'md') => {
    const sizeClasses = {
      sm: 'w-8 h-8 text-sm',
      md: 'w-16 h-16 text-2xl',
      lg: 'w-24 h-24 text-4xl',
    };

    if (profile.avatarType === 'custom' && profile.avatarCustomImage) {
      return (
        <img
          src={profile.avatarCustomImage}
          alt="Avatar"
          className={`${sizeClasses[size]} rounded-full object-cover shadow-lg border-2 border-white/20`}
        />
      );
    }

    if (profile.avatarType.startsWith('preset:')) {
      const preset = AVATAR_PRESETS.find((p) => p.id === profile.avatarType);
      if (preset) {
        return (
          <div
            style={{
              background: `linear-gradient(135deg, ${preset.gradientColors[0]}, ${preset.gradientColors[1]})`,
            }}
            className={`${sizeClasses[size]} rounded-full flex items-center justify-center shadow-lg border-2 border-white/20`}
          >
            <span>{preset.icon}</span>
          </div>
        );
      }
    }

    // Default: Monogram Initial
    const initial = (profile.username || 'E').charAt(0).toUpperCase();
    return (
      <div
        className={`${sizeClasses[size]} rounded-full bg-gradient-to-tr from-brand-red to-rose-600 text-white flex items-center justify-center font-black shadow-lg border-2 border-white/20`}
      >
        {initial}
      </div>
    );
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 sm:p-6 bg-black/80 backdrop-blur-md animate-in fade-in duration-200">
      <div className="relative w-full max-w-3xl max-h-[90vh] bg-[#121319] border border-zinc-800 rounded-3xl shadow-2xl flex flex-col overflow-hidden">
        {/* Header bar */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-zinc-800/80 bg-zinc-950/60 shrink-0">
          <div className="flex items-center gap-3">
            <h2 className="text-base font-bold text-white">
              {activeTab === 'avatar' ? 'Välj avatar' : 'Min Profil'}
            </h2>
            {activeTab === 'avatar' && (
              <button
                onClick={() => setActiveTab('profile')}
                className="text-xs text-zinc-400 hover:text-white transition"
              >
                ← Tillbaka
              </button>
            )}
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
          {activeTab === 'avatar' ? (
            /* AVATAR SELECTOR VIEW */
            <div className="space-y-6">
              {/* Förhandsvisning */}
              <div className="flex flex-col items-center justify-center p-6 bg-zinc-950/60 border border-zinc-800/80 rounded-2xl">
                {renderAvatarContent('lg')}
                <span className="text-sm font-bold text-white mt-3">{profile.username}</span>
              </div>

              {/* 1. Klassiskt Monogram */}
              <div className="space-y-2">
                <span className="text-xs font-bold uppercase tracking-wider text-zinc-400">
                  Klassiskt monogram
                </span>
                <button
                  onClick={handleSelectInitial}
                  className={`w-full flex items-center justify-between p-3.5 rounded-2xl border transition ${
                    profile.avatarType === 'initial'
                      ? 'bg-zinc-900 border-brand-red'
                      : 'bg-zinc-900/60 border-zinc-800 hover:border-zinc-700'
                  }`}
                >
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-full bg-gradient-to-tr from-brand-red to-rose-600 text-white flex items-center justify-center font-bold">
                      {(profile.username || 'E').charAt(0).toUpperCase()}
                    </div>
                    <div className="text-left">
                      <div className="text-sm font-bold text-white">Initial</div>
                      <div className="text-xs text-zinc-400">Röd gradient med din första bokstav</div>
                    </div>
                  </div>
                  {profile.avatarType === 'initial' && <Check className="w-5 h-5 text-brand-red" />}
                </button>
              </div>

              {/* 2. Eget Foto */}
              <div className="space-y-2">
                <span className="text-xs font-bold uppercase tracking-wider text-zinc-400">
                  Eget foto
                </span>
                <input
                  type="file"
                  ref={fileInputRef}
                  onChange={handleFileUpload}
                  accept="image/*"
                  className="hidden"
                />
                <button
                  onClick={() => fileInputRef.current?.click()}
                  className={`w-full flex items-center justify-between p-3.5 rounded-2xl border transition ${
                    profile.avatarType === 'custom'
                      ? 'bg-zinc-900 border-brand-red'
                      : 'bg-zinc-900/60 border-zinc-800 hover:border-zinc-700'
                  }`}
                >
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-full bg-zinc-800 flex items-center justify-center text-zinc-300">
                      <Upload className="w-5 h-5" />
                    </div>
                    <div className="text-left">
                      <div className="text-sm font-bold text-white">Ladda upp bild</div>
                      <div className="text-xs text-zinc-400">Välj valfri bild från din dator</div>
                    </div>
                  </div>
                  {profile.avatarType === 'custom' && <Check className="w-5 h-5 text-brand-red" />}
                </button>
              </div>

              {/* 3. Gamer Ikoner */}
              <div className="space-y-3">
                <span className="text-xs font-bold uppercase tracking-wider text-zinc-400">
                  Gamer-ikoner
                </span>
                <div className="grid grid-cols-3 sm:grid-cols-4 gap-3">
                  {AVATAR_PRESETS.map((preset) => {
                    const isSelected = profile.avatarType === preset.id;
                    return (
                      <button
                        key={preset.id}
                        onClick={() => handleSelectAvatarPreset(preset.id)}
                        style={{
                          background: `linear-gradient(135deg, ${preset.gradientColors[0]}, ${preset.gradientColors[1]})`,
                        }}
                        className={`flex flex-col items-center gap-2 p-4 rounded-2xl border transition ${
                          isSelected
                            ? 'border-brand-red ring-2 ring-brand-red/40 scale-105'
                            : 'border-white/10 hover:border-white/25'
                        }`}
                      >
                        <span className="text-3xl">{preset.icon}</span>
                        <span className="text-xs font-bold text-white truncate max-w-full">
                          {preset.name}
                        </span>
                      </button>
                    );
                  })}
                </div>
              </div>
            </div>
          ) : (
            /* MAIN PROFILE VIEW */
            <>
              {/* 1. Identitet Header */}
              <div className="flex items-center justify-between p-5 bg-gradient-to-br from-zinc-900/90 to-zinc-950 border border-zinc-800/80 rounded-2xl">
                <div className="flex items-center gap-4">
                  {/* Klickbar avatar med kamera-badge */}
                  <div
                    onClick={() => setActiveTab('avatar')}
                    className="relative cursor-pointer group"
                    title="Byt avatar"
                  >
                    {renderAvatarContent('md')}
                    <div className="absolute -bottom-1 -right-1 w-6 h-6 rounded-full bg-brand-red text-white flex items-center justify-center shadow-md group-hover:scale-110 transition">
                      <Camera className="w-3 h-3" />
                    </div>
                  </div>

                  {editingName ? (
                    <div className="flex items-center gap-2">
                      <input
                        type="text"
                        value={nameInput}
                        onChange={(e) => setNameInput(e.target.value)}
                        placeholder="Namn"
                        className="px-3 py-1 bg-zinc-800 border border-zinc-700 rounded-xl text-sm font-bold text-white outline-none w-32"
                      />
                      <input
                        type="number"
                        value={ageInput}
                        onChange={(e) => setAgeInput(e.target.value)}
                        placeholder="Ålder"
                        className="px-3 py-1 bg-zinc-800 border border-zinc-700 rounded-xl text-sm font-bold text-white outline-none w-20"
                      />
                      <button
                        onClick={handleSaveIdentity}
                        className="p-1.5 bg-brand-red text-white rounded-xl text-xs font-bold hover:bg-rose-600 transition"
                      >
                        <Check className="w-4 h-4" />
                      </button>
                    </div>
                  ) : (
                    <div>
                      <div className="flex items-center gap-2">
                        <h3 className="text-xl font-black text-white">{profile.username}</h3>
                        <button
                          onClick={() => {
                            setNameInput(profile.username);
                            setAgeInput(profile.age.toString());
                            setEditingName(true);
                          }}
                          className="p-1 text-zinc-400 hover:text-white transition"
                        >
                          <Edit2 className="w-3.5 h-3.5" />
                        </button>
                      </div>
                      <span className="text-xs text-zinc-400 font-medium">{profile.age} år</span>
                    </div>
                  )}
                </div>

                <button
                  onClick={() => setActiveTab('avatar')}
                  className="px-3 py-1.5 text-xs font-semibold text-zinc-300 hover:text-white bg-zinc-800/80 hover:bg-zinc-800 border border-zinc-700/80 rounded-xl transition"
                >
                  Byt avatar
                </button>
              </div>

              {/* 2. Spel-DNA Hero-kort */}
              {spelDNA ? (
                <div
                  style={{
                    boxShadow: `0 0 45px -10px ${spelDNA.accentHex}40`,
                    borderColor: `${spelDNA.accentHex}40`,
                  }}
                  className="relative p-6 bg-gradient-to-br from-zinc-900/95 via-[#13141c] to-zinc-950 border rounded-3xl overflow-hidden"
                >
                  {/* Bakgrundsglöd */}
                  <div
                    style={{ background: spelDNA.accentHex }}
                    className="absolute -top-16 -right-16 w-44 h-44 rounded-full opacity-20 blur-3xl pointer-events-none"
                  />

                  <div className="relative space-y-3">
                    <div className="flex items-center justify-between">
                      <span className="text-[11px] font-black uppercase tracking-widest text-zinc-400">
                        Ditt Spel-DNA
                      </span>
                      <span className="text-2xl">{spelDNA.icon}</span>
                    </div>

                    <div>
                      <h3
                        style={{ color: spelDNA.accentHex }}
                        className="text-2xl font-black tracking-tight"
                      >
                        {spelDNA.title}
                      </h3>
                      <p className="text-xs text-zinc-300 mt-1 leading-relaxed max-w-xl">
                        {spelDNA.description}
                      </p>
                    </div>

                    {/* Stödchips */}
                    <div className="flex items-center gap-2 pt-2 flex-wrap">
                      {spelDNA.supportingStats.map((stat, i) => (
                        <span
                          key={i}
                          style={{
                            borderColor: `${spelDNA.accentHex}50`,
                            background: `${spelDNA.accentHex}15`,
                            color: spelDNA.accentHex,
                          }}
                          className="px-3 py-1 rounded-full text-xs font-bold border shadow-sm"
                        >
                          {stat}
                        </span>
                      ))}
                    </div>
                  </div>
                </div>
              ) : (
                <div className="p-6 bg-zinc-900/40 border border-zinc-800/80 rounded-3xl text-center space-y-2">
                  <span className="text-2xl">🎲</span>
                  <h4 className="text-sm font-bold text-white">Spel-DNA kräver minst 5 spel</h4>
                  <p className="text-xs text-zinc-400 max-w-md mx-auto">
                    Lägg till minst 5 spel i din spelsamling så analyserar Gameshelf din unika
                    spelarprofil.
                  </p>
                </div>
              )}

              {/* 3. Min setup */}
              <div className="space-y-3">
                <div className="flex items-center gap-2">
                  <Gamepad2 className="w-4 h-4 text-brand-red" />
                  <h4 className="text-sm font-bold text-white">Min setup (Plattformar)</h4>
                </div>

                <div className="flex flex-wrap gap-2">
                  {DEFAULT_PLATFORMS.map((plat) => {
                    const isSelected = profile.platforms.includes(plat);
                    return (
                      <button
                        key={plat}
                        onClick={() => handleTogglePlatform(plat)}
                        className={`flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-bold transition ${
                          isSelected
                            ? 'bg-brand-red/15 text-white border border-brand-red/60 shadow-sm'
                            : 'bg-zinc-900/80 text-zinc-400 border border-zinc-800 hover:border-zinc-700'
                        }`}
                      >
                        {isSelected && <Check className="w-3.5 h-3.5 text-brand-red" />}
                        <span>{plat}</span>
                      </button>
                    );
                  })}
                </div>
              </div>

              {/* 4. Mina Spelpreferenser */}
              <div className="space-y-4">
                <div className="flex items-center gap-2">
                  <Heart className="w-4 h-4 text-brand-red" />
                  <h4 className="text-sm font-bold text-white">Mina spelpreferenser</h4>
                </div>

                {/* Favoritgenrer */}
                <div className="space-y-2">
                  <span className="text-xs font-bold text-zinc-400">Favoritgenrer</span>
                  <div className="flex flex-wrap gap-2">
                    {DEFAULT_GENRES.map((genre) => {
                      const isSelected = profile.favoriteGenres.includes(genre);
                      return (
                        <button
                          key={genre}
                          onClick={() => handleToggleGenre(genre)}
                          className={`px-3 py-1.5 rounded-full text-xs font-bold transition ${
                            isSelected
                              ? 'bg-brand-red text-white shadow-sm'
                              : 'bg-zinc-900 text-zinc-400 border border-zinc-800 hover:border-zinc-700'
                          }`}
                        >
                          {genre}
                        </button>
                      );
                    })}
                  </div>
                </div>

                {/* Jag spelar helst för */}
                <div className="space-y-2 pt-2">
                  <span className="text-xs font-bold text-zinc-400">Jag spelar helst för</span>
                  <div className="flex flex-wrap gap-2">
                    {DEFAULT_PLAY_FOR.map((motive) => {
                      const isSelected = profile.playFor.includes(motive);
                      return (
                        <button
                          key={motive}
                          onClick={() => handleTogglePlayFor(motive)}
                          className={`px-3 py-1.5 rounded-full text-xs font-bold transition ${
                            isSelected
                              ? 'bg-brand-red text-white shadow-sm'
                              : 'bg-zinc-900 text-zinc-400 border border-zinc-800 hover:border-zinc-700'
                          }`}
                        >
                          {motive}
                        </button>
                      );
                    })}
                  </div>
                </div>
              </div>

              {/* 5. Mina favoritspel */}
              <div className="space-y-3">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <Trophy className="w-4 h-4 text-amber-400" />
                    <h4 className="text-sm font-bold text-white">Mina favoritspel</h4>
                    <span className="px-2 py-0.5 rounded-full bg-zinc-800 text-zinc-400 text-xs font-bold">
                      {favoriteGames.length}/10
                    </span>
                  </div>

                  {profile.favoriteGameIDs.length < 10 && (
                    <button
                      onClick={() => setIsAddingFavorite(true)}
                      className="flex items-center gap-1 px-3 py-1 bg-zinc-800 hover:bg-zinc-700 text-white rounded-xl text-xs font-bold transition"
                    >
                      <Plus className="w-3.5 h-3.5" />
                      <span>Lägg till</span>
                    </button>
                  )}
                </div>

                {/* Add favorite picker */}
                {isAddingFavorite && (
                  <div className="p-4 bg-zinc-900/90 border border-zinc-800 rounded-2xl space-y-3">
                    <div className="flex items-center justify-between">
                      <span className="text-xs font-bold text-zinc-200">
                        Välj från din spelsamling:
                      </span>
                      <button
                        onClick={() => setIsAddingFavorite(false)}
                        className="text-xs text-zinc-400 hover:text-white"
                      >
                        Avbryt
                      </button>
                    </div>

                    <input
                      type="text"
                      placeholder="Sök i ditt bibliotek..."
                      value={favoriteSearch}
                      onChange={(e) => setFavoriteSearch(e.target.value)}
                      className="w-full px-3 py-2 bg-zinc-950 border border-zinc-800 rounded-xl text-xs text-white placeholder-zinc-500 outline-none"
                    />

                    <div className="max-h-48 overflow-y-auto space-y-1.5 custom-scrollbar">
                      {availableForFavorites.length === 0 ? (
                        <div className="p-3 text-center text-xs text-zinc-500">
                          Inga fler spel tillgängliga att lägga till.
                        </div>
                      ) : (
                        availableForFavorites.map((g) => (
                          <div
                            key={g.id}
                            onClick={() => handleAddFavorite(g.id)}
                            className="flex items-center justify-between p-2 hover:bg-zinc-800/80 rounded-xl cursor-pointer transition"
                          >
                            <div className="flex items-center gap-2.5 truncate">
                              {g.cover_url && (
                                <img
                                  src={g.cover_url}
                                  alt={g.title}
                                  className="w-7 h-9 rounded object-cover"
                                />
                              )}
                              <span className="text-xs font-bold text-zinc-200 truncate">
                                {g.title}
                              </span>
                            </div>
                            <Plus className="w-4 h-4 text-brand-red shrink-0" />
                          </div>
                        ))
                      )}
                    </div>
                  </div>
                )}

                {/* Favoritspelslista */}
                {favoriteGames.length === 0 ? (
                  <div className="p-6 bg-zinc-900/30 border border-dashed border-zinc-800 rounded-2xl text-center">
                    <p className="text-xs text-zinc-500">
                      Inga favoriter valda än. Klicka på "Lägg till" för att välja upp till 10
                      favoriter från din samling.
                    </p>
                  </div>
                ) : (
                  <div className="grid grid-cols-2 sm:grid-cols-4 md:grid-cols-5 gap-3">
                    {favoriteGames.map((game) => (
                      <div
                        key={game.id}
                        className="group relative bg-zinc-900/60 border border-zinc-800 rounded-2xl overflow-hidden"
                      >
                        <div
                          onClick={() => game.igdb_id && onSelectGame?.(game.igdb_id)}
                          className="relative aspect-[3/4] bg-zinc-950 cursor-pointer overflow-hidden"
                        >
                          {game.cover_url ? (
                            <img
                              src={game.cover_url}
                              alt={game.title}
                              className="w-full h-full object-cover group-hover:scale-105 transition duration-300"
                            />
                          ) : (
                            <div className="w-full h-full flex items-center justify-center p-2 text-center text-xs font-bold text-zinc-400">
                              {game.title}
                            </div>
                          )}

                          {/* Ta bort-knapp */}
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              handleRemoveFavorite(game.id);
                            }}
                            className="absolute top-1.5 right-1.5 p-1 rounded-lg bg-black/70 hover:bg-rose-600 text-white opacity-0 group-hover:opacity-100 transition shadow"
                            title="Ta bort från favoriter"
                          >
                            <Trash2 className="w-3 h-3" />
                          </button>
                        </div>

                        <div className="p-2 truncate">
                          <span className="text-[11px] font-bold text-zinc-200 truncate block">
                            {game.title}
                          </span>
                        </div>
                      </div>
                    ))}
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
