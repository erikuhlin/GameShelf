'use client';

import React, { useState, useEffect } from 'react';
import { QRCodeSVG } from 'qrcode.react';
import { supabase } from '@/lib/supabase';
import {
  Smartphone,
  X,
  Copy,
  Check,
  CheckCircle2,
  Loader2,
  Sparkles,
  QrCode,
  ShieldCheck,
  RefreshCw,
} from 'lucide-react';

interface PairingModalProps {
  isOpen: boolean;
  onClose: () => void;
  onPaired: (userId: string, username?: string) => void;
}

export function PairingModal({ isOpen, onClose, onPaired }: PairingModalProps) {
  const [code, setCode] = useState<string>('');
  const [isCopied, setIsCopied] = useState(false);
  const [isSuccess, setIsSuccess] = useState(false);
  const [pairedUserId, setPairedUserId] = useState<string | null>(null);

  // Generate a random 6-character code e.g. "GS-4821"
  const generateNewCode = () => {
    const randomDigits = Math.floor(1000 + Math.random() * 9000);
    return `GS-${randomDigits}`;
  };

  useEffect(() => {
    if (!isOpen) {
      setIsSuccess(false);
      return;
    }

    const newCode = generateNewCode();
    setCode(newCode);

    // 1. Skapa en pairing_session i Supabase
    async function initSession() {
      try {
        await supabase.from('pairing_sessions').insert([
          {
            code: newCode,
            status: 'pending',
          },
        ]);
      } catch (err) {
        console.error('Failed to init pairing session:', err);
      }
    }

    initSession();

    // 2. Lyssna i realtid på godkännande
    const channel = supabase
      .channel(`pairing:${newCode}`)
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'pairing_sessions',
          filter: `code=eq.${newCode}`,
        },
        (payload: any) => {
          if (payload.new && payload.new.status === 'approved') {
            const userId = payload.new.user_id;
            const username = payload.new.session_data?.username || '';
            setIsSuccess(true);
            setPairedUserId(userId);
            if (typeof window !== 'undefined') {
              if (userId) localStorage.setItem('gameshelf_paired_user_id', userId);
              if (username) localStorage.setItem('gameshelf_profile_name', username);
            }
            if (userId) {
              onPaired(userId, username);
            }
            setTimeout(() => {
              if (userId) {
                onPaired(userId, username);
              }
              onClose();
            }, 1200);
          }
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [isOpen]);

  if (!isOpen) return null;

  const handleCopyCode = () => {
    navigator.clipboard.writeText(code);
    setIsCopied(true);
    setTimeout(() => setIsCopied(false), 2000);
  };

  const qrValue = `gameshelf://pair?code=${encodeURIComponent(code)}`;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm animate-in fade-in duration-200">
      <div className="bg-[#16181f] border border-zinc-800 rounded-3xl w-full max-w-lg shadow-2xl overflow-hidden flex flex-col">
        {/* Header */}
        <div className="p-6 border-b border-zinc-800 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-brand-red/10 border border-brand-red/40 flex items-center justify-center text-brand-red">
              <Smartphone className="w-5 h-5" />
            </div>
            <div>
              <h3 className="text-lg font-bold text-white flex items-center gap-2">
                <span>Anslut iPhone / Simulator</span>
                <Sparkles className="w-4 h-4 text-amber-400" />
              </h3>
              <p className="text-xs text-zinc-400">Lösenordsfri parkoppling mot iOS-appen</p>
            </div>
          </div>

          <button
            onClick={onClose}
            className="p-2 rounded-lg bg-zinc-800/80 hover:bg-zinc-700 text-zinc-400 hover:text-white transition"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content */}
        <div className="p-6 sm:p-8 flex flex-col items-center text-center space-y-6">
          {isSuccess ? (
            <div className="py-8 space-y-4 animate-in zoom-in-95 duration-300 flex flex-col items-center">
              <div className="w-20 h-20 rounded-full bg-emerald-500/20 border-2 border-emerald-500 flex items-center justify-center text-emerald-400 shadow-xl shadow-emerald-500/20">
                <CheckCircle2 className="w-10 h-10" />
              </div>
              <h4 className="text-xl font-bold text-white">Parkoppling lyckades!</h4>
              <p className="text-sm text-zinc-400 max-w-xs">
                Webbläsaren är nu ansluten till din iPhone. Laddar ditt personliga spelbibliotek...
              </p>
            </div>
          ) : (
            <>
              {/* QR Code & Code Box */}
              <div className="flex flex-col sm:flex-row items-center gap-6 w-full justify-center">
                {/* QR Code */}
                <div className="p-3.5 bg-white rounded-2xl shadow-xl flex-shrink-0">
                  <QRCodeSVG value={qrValue} size={150} level="M" />
                </div>

                {/* 6-digit Code for Simulator */}
                <div className="flex flex-col items-center sm:items-start text-center sm:text-left space-y-2">
                  <span className="text-xs font-semibold text-zinc-400 uppercase tracking-wider">
                    Kod för Simulator
                  </span>
                  <div
                    onClick={handleCopyCode}
                    className="cursor-pointer group flex items-center gap-2 px-4 py-2.5 rounded-xl bg-zinc-900 border border-zinc-700 hover:border-brand-red transition"
                  >
                    <span className="text-2xl font-mono font-bold tracking-widest text-white">
                      {code}
                    </span>
                    <button className="text-zinc-400 group-hover:text-white p-1">
                      {isCopied ? (
                        <Check className="w-4 h-4 text-emerald-400" />
                      ) : (
                        <Copy className="w-4 h-4" />
                      )}
                    </button>
                  </div>
                  <span className="text-[11px] text-zinc-500">
                    {isCopied ? 'Kopierat till urklipp!' : 'Klicka för att kopiera'}
                  </span>
                </div>
              </div>

              {/* Step by step Instructions */}
              <div className="w-full bg-zinc-950/70 border border-zinc-800 rounded-2xl p-4 text-left space-y-2.5">
                <div className="flex items-start gap-2.5 text-xs text-zinc-300">
                  <span className="w-5 h-5 rounded-full bg-zinc-800 text-brand-red font-bold flex items-center justify-center flex-shrink-0 text-[11px]">
                    1
                  </span>
                  <span>Öppna <strong>Gameshelf</strong> i Xcode Simulatorn eller på din iPhone.</span>
                </div>
                <div className="flex items-start gap-2.5 text-xs text-zinc-300">
                  <span className="w-5 h-5 rounded-full bg-zinc-800 text-brand-red font-bold flex items-center justify-center flex-shrink-0 text-[11px]">
                    2
                  </span>
                  <span>Gå till <strong>Profile &gt; Parkoppla webbläsare</strong>.</span>
                </div>
                <div className="flex items-start gap-2.5 text-xs text-zinc-300">
                  <span className="w-5 h-5 rounded-full bg-zinc-800 text-brand-red font-bold flex items-center justify-center flex-shrink-0 text-[11px]">
                    3
                  </span>
                  <span>
                    Skriv in koden <strong>{code}</strong> (eller skanna QR-koden) och tryck <strong>Godkänn</strong>.
                  </span>
                </div>
              </div>

              {/* Waiting Indicator */}
              <div className="flex items-center gap-2 text-xs text-zinc-400">
                <Loader2 className="w-3.5 h-3.5 animate-spin text-brand-red" />
                <span>Väntar på godkännande från appen i realtid...</span>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
