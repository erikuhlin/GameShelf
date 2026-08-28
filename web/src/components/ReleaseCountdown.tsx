'use client';

import React, { useState, useEffect } from 'react';
import { Hourglass, Sparkles, Calendar } from 'lucide-react';

interface ReleaseCountdownProps {
  firstReleaseDate?: number | null; // Unix timestamp in seconds
  releaseYear?: number | null;
}

export function ReleaseCountdown({ firstReleaseDate, releaseYear }: ReleaseCountdownProps) {
  const [timeLeft, setTimeLeft] = useState<{
    days: number;
    hours: number;
    minutes: number;
    seconds: number;
    isPast: boolean;
    isToday: boolean;
  } | null>(null);

  useEffect(() => {
    if (!firstReleaseDate) return;

    const targetTime = firstReleaseDate * 1000;

    const updateCountdown = () => {
      const now = Date.now();
      const diff = targetTime - now;

      if (diff <= 0) {
        // Kontrollera om det är idag
        const targetDate = new Date(targetTime);
        const today = new Date();
        const isSameDay =
          targetDate.getFullYear() === today.getFullYear() &&
          targetDate.getMonth() === today.getMonth() &&
          targetDate.getDate() === today.getDate();

        setTimeLeft({
          days: 0,
          hours: 0,
          minutes: 0,
          seconds: 0,
          isPast: true,
          isToday: isSameDay,
        });
        return;
      }

      const days = Math.floor(diff / (1000 * 60 * 60 * 24));
      const hours = Math.floor((diff / (1000 * 60 * 60)) % 24);
      const minutes = Math.floor((diff / 1000 / 60) % 60);
      const seconds = Math.floor((diff / 1000) % 60);

      setTimeLeft({
        days,
        hours,
        minutes,
        seconds,
        isPast: false,
        isToday: false,
      });
    };

    updateCountdown();
    const interval = setInterval(updateCountdown, 1000);
    return () => clearInterval(interval);
  }, [firstReleaseDate]);

  const currentYear = new Date().getFullYear();
  const isFutureYearOnly =
    !firstReleaseDate && releaseYear && releaseYear > currentYear;

  // Om spelet redan har släppts och inte är idag, visa ingen nedräkning
  if (timeLeft?.isPast && !timeLeft.isToday) {
    return null;
  }

  // Om varken framtida datum eller år finns
  if (!timeLeft && !isFutureYearOnly) {
    return null;
  }

  const formattedDate = firstReleaseDate
    ? new Date(firstReleaseDate * 1000).toLocaleDateString('sv-SE', {
        year: 'numeric',
        month: 'long',
        day: 'numeric',
      })
    : null;

  return (
    <div className="w-full rounded-2xl bg-gradient-to-br from-amber-950/30 via-zinc-900/90 to-zinc-950/90 border border-amber-500/30 p-4 sm:p-5 shadow-lg shadow-amber-500/5 backdrop-blur-sm transition-all">
      <div className="flex items-center justify-between gap-2 mb-3">
        <div className="flex items-center gap-2">
          <div className="flex items-center justify-center w-7 h-7 rounded-full bg-amber-500/10 text-amber-400">
            <Hourglass className="w-4 h-4 animate-pulse" />
          </div>
          <span className="text-xs font-black tracking-wider uppercase text-amber-400">
            Kommande Släpp
          </span>
        </div>

        {formattedDate && (
          <span className="text-xs font-medium text-zinc-400">
            {formattedDate}
          </span>
        )}
      </div>

      {timeLeft?.isToday ? (
        <div className="flex items-center justify-center gap-2 py-3 bg-amber-500/10 rounded-xl border border-amber-500/20 text-amber-300 font-bold">
          <Sparkles className="w-5 h-5 text-amber-400" />
          <span>Spelet släpps idag! 🎉</span>
          <Sparkles className="w-5 h-5 text-amber-400" />
        </div>
      ) : timeLeft ? (
        <div className="grid grid-cols-4 gap-2 text-center">
          <div className="flex flex-col items-center bg-black/40 border border-white/5 rounded-xl py-2 px-1">
            <span className="text-xl sm:text-2xl font-black text-white font-mono">
              {String(timeLeft.days).padStart(2, '0')}
            </span>
            <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-wide">
              Dagar
            </span>
          </div>

          <div className="flex flex-col items-center bg-black/40 border border-white/5 rounded-xl py-2 px-1">
            <span className="text-xl sm:text-2xl font-black text-white font-mono">
              {String(timeLeft.hours).padStart(2, '0')}
            </span>
            <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-wide">
              Timmar
            </span>
          </div>

          <div className="flex flex-col items-center bg-black/40 border border-white/5 rounded-xl py-2 px-1">
            <span className="text-xl sm:text-2xl font-black text-white font-mono">
              {String(timeLeft.minutes).padStart(2, '0')}
            </span>
            <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-wide">
              Minuter
            </span>
          </div>

          <div className="flex flex-col items-center bg-black/40 border border-white/5 rounded-xl py-2 px-1">
            <span className="text-xl sm:text-2xl font-black text-amber-400 font-mono">
              {String(timeLeft.seconds).padStart(2, '0')}
            </span>
            <span className="text-[10px] font-bold text-amber-400/80 uppercase tracking-wide">
              Sekunder
            </span>
          </div>
        </div>
      ) : (
        <div className="flex items-center justify-between py-2 px-3 bg-black/40 rounded-xl border border-white/5">
          <div className="flex items-center gap-2 text-zinc-300 text-sm">
            <Calendar className="w-4 h-4 text-amber-400" />
            <span>Planerat lanseringsår</span>
          </div>
          <span className="text-base font-black text-amber-400 font-mono">
            {releaseYear}
          </span>
        </div>
      )}
    </div>
  );
}
