'use client';

import React, { useState, useEffect, useRef } from 'react';
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
  Mail,
  Lock,
  ArrowRight,
  ShieldCheck,
  User,
} from 'lucide-react';

interface PairingModalProps {
  isOpen: boolean;
  onClose: () => void;
  onPaired: (userId: string, username?: string) => void;
}

export function PairingModal({ isOpen, onClose, onPaired }: PairingModalProps) {
  const [activeTab, setActiveTab] = useState<'qr' | 'account'>('account');

  // Account State
  const [isSignUp, setIsSignUp] = useState(false);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [accountUsername, setAccountUsername] = useState('');
  const [accountLoading, setAccountLoading] = useState(false);
  const [accountMessage, setAccountMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null);

  // QR / Code State
  const [code, setCode] = useState<string>('');
  const [isCopied, setIsCopied] = useState(false);
  const [isSuccess, setIsSuccess] = useState(false);
  const pollIntervalRef = useRef<NodeJS.Timeout | null>(null);

  // Generera en 6-teckens kod, t.ex. "GS-4821"
  const generateNewCode = () => {
    const randomDigits = Math.floor(1000 + Math.random() * 9000);
    return `GS-${randomDigits}`;
  };

  // Initiera parkopplingssession vid öppning
  useEffect(() => {
    if (!isOpen) {
      setIsSuccess(false);
      if (pollIntervalRef.current) clearInterval(pollIntervalRef.current);
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

    const handleSuccessPairing = (userId: string, username: string) => {
      setIsSuccess(true);
      if (pollIntervalRef.current) clearInterval(pollIntervalRef.current);
      if (typeof window !== 'undefined') {
        if (userId) localStorage.setItem('gameshelf_paired_user_id', userId);
        if (username) localStorage.setItem('gameshelf_profile_name', username);
      }
      if (userId) {
        onPaired(userId, username);
      }
      setTimeout(() => {
        onClose();
      }, 1200);
    };

    // 2. Lyssna i realtid via WebSocket
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
            handleSuccessPairing(userId, username);
          }
        }
      )
      .subscribe();

    // 3. Robust polling fallback var 2:a sekund för garanterad träff
    pollIntervalRef.current = setInterval(async () => {
      try {
        const { data } = await supabase
          .from('pairing_sessions')
          .select('status, user_id, session_data')
          .eq('code', newCode)
          .single();

        if (data && data.status === 'approved' && data.user_id) {
          const username = data.session_data?.username || '';
          handleSuccessPairing(data.user_id, username);
        }
      } catch (e) {}
    }, 2000);

    return () => {
      supabase.removeChannel(channel);
      if (pollIntervalRef.current) clearInterval(pollIntervalRef.current);
    };
  }, [isOpen]);

  if (!isOpen) return null;

  const handleCopyCode = () => {
    navigator.clipboard.writeText(code);
    setIsCopied(true);
    setTimeout(() => setIsCopied(false), 2000);
  };

  const qrValue = `gameshelf://pair?code=${encodeURIComponent(code)}`;

  const handleAccountSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email || !password) return;

    setAccountLoading(true);
    setAccountMessage(null);

    const cleanEmail = email.trim().toLowerCase();
    const cleanUsername = accountUsername.trim() || cleanEmail.split('@')[0];

    try {
      if (isSignUp) {
        const { data, error } = await supabase.auth.signUp({
          email: cleanEmail,
          password,
          options: {
            data: {
              username: cleanUsername,
            },
          },
        });

        if (error) {
          if (error.message.toLowerCase().includes('already registered')) {
            throw new Error('Ett konto med denna e-postadress finns redan. Välj "Logga in" istället.');
          }
          throw error;
        }

        if (data.session && data.user) {
          if (typeof window !== 'undefined') {
            localStorage.setItem('gameshelf_paired_user_id', data.user.id);
            localStorage.setItem('gameshelf_profile_name', cleanUsername);
          }
          onPaired(data.user.id, cleanUsername);
          onClose();
        } else {
          setAccountMessage({
            type: 'success',
            text: 'Konto skapat! Kontrollera din e-post för att bekräfta kontot, eller logga in direkt.',
          });
        }
      } else {
        const { data, error } = await supabase.auth.signInWithPassword({
          email: cleanEmail,
          password,
        });

        if (error) {
          if (error.message.toLowerCase().includes('invalid login credentials')) {
            throw new Error('Felaktig e-postadress eller lösenord. Kontrollera dina uppgifter.');
          }
          throw error;
        }

        if (data.user) {
          const resolvedName = data.user.user_metadata?.username || cleanEmail.split('@')[0] || 'Spelare';
          if (typeof window !== 'undefined') {
            localStorage.setItem('gameshelf_paired_user_id', data.user.id);
            localStorage.setItem('gameshelf_profile_name', resolvedName);
          }
          onPaired(data.user.id, resolvedName);
          onClose();
        }
      }
    } catch (err: any) {
      setAccountMessage({
        type: 'error',
        text: err.message || 'Ett fel uppstod vid inloggningen.',
      });
    } finally {
      setAccountLoading(false);
    }
  };

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
                <span>Konto & Synkronisering</span>
                <Sparkles className="w-4 h-4 text-amber-400" />
              </h3>
              <p className="text-xs text-zinc-400">Synka dina spel mellan iOS och webbläsaren</p>
            </div>
          </div>

          <button
            onClick={onClose}
            className="p-2 rounded-lg bg-zinc-800/80 hover:bg-zinc-700 text-zinc-400 hover:text-white transition"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Tab Picker */}
        <div className="px-6 pt-5">
          <div className="flex bg-zinc-950 p-1 rounded-xl border border-zinc-800">
            <button
              type="button"
              onClick={() => {
                setActiveTab('account');
                setAccountMessage(null);
              }}
              className={`flex-1 py-2 text-xs font-semibold rounded-lg transition flex items-center justify-center gap-2 ${
                activeTab === 'account'
                  ? 'bg-zinc-800 text-white shadow-sm'
                  : 'text-zinc-400 hover:text-zinc-200'
              }`}
            >
              <Mail className="w-3.5 h-3.5 text-brand-red" />
              <span>Logga in med konto</span>
            </button>
            <button
              type="button"
              onClick={() => {
                setActiveTab('qr');
                setAccountMessage(null);
              }}
              className={`flex-1 py-2 text-xs font-semibold rounded-lg transition flex items-center justify-center gap-2 ${
                activeTab === 'qr'
                  ? 'bg-zinc-800 text-white shadow-sm'
                  : 'text-zinc-400 hover:text-zinc-200'
              }`}
            >
              <QrCode className="w-3.5 h-3.5 text-brand-red" />
              <span>Koppla iPhone (QR)</span>
            </button>
          </div>
        </div>

        {/* Content */}
        <div className="p-6 sm:p-8 flex flex-col space-y-6">
          {activeTab === 'account' ? (
            /* Tab 1: Gameshelf-konto */
            <div className="space-y-4">
              <div className="text-center sm:text-left">
                <h4 className="text-base font-bold text-white">
                  {isSignUp ? 'Skapa ditt Gameshelf-konto' : 'Välkommen tillbaka'}
                </h4>
                <p className="text-xs text-zinc-400 mt-1">
                  {isSignUp
                    ? 'Skapa ett konto så synkroniseras dina spel automatiskt mellan mobilen och webben.'
                    : 'Logga in med dina kontouppgifter för att ladda ditt bibliotek.'}
                </p>
              </div>

              {accountMessage && (
                <div
                  className={`p-3 rounded-xl text-xs flex items-start gap-2.5 ${
                    accountMessage.type === 'success'
                      ? 'bg-emerald-950/60 border border-emerald-800/80 text-emerald-300'
                      : 'bg-red-950/60 border border-red-800/80 text-red-300'
                  }`}
                >
                  {accountMessage.type === 'success' && <CheckCircle2 className="w-4 h-4 shrink-0 mt-0.5" />}
                  <span>{accountMessage.text}</span>
                </div>
              )}

              <form onSubmit={handleAccountSubmit} className="space-y-3">
                {isSignUp && (
                  <div>
                    <label className="block text-xs font-medium text-zinc-300 mb-1">
                      Användarnamn
                    </label>
                    <div className="relative">
                      <User className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-500" />
                      <input
                        type="text"
                        value={accountUsername}
                        onChange={(e) => setAccountUsername(e.target.value)}
                        placeholder="Ditt spelarnamn"
                        className="w-full pl-10 pr-4 py-2 bg-zinc-950 border border-zinc-700 rounded-xl text-sm text-zinc-100 placeholder-zinc-500 focus:outline-none focus:border-brand-red"
                      />
                    </div>
                  </div>
                )}

                <div>
                  <label className="block text-xs font-medium text-zinc-300 mb-1">
                    E-postadress
                  </label>
                  <div className="relative">
                    <Mail className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-500" />
                    <input
                      type="email"
                      required
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      placeholder="din.epost@example.com"
                      className="w-full pl-10 pr-4 py-2 bg-zinc-950 border border-zinc-700 rounded-xl text-sm text-zinc-100 placeholder-zinc-500 focus:outline-none focus:border-brand-red"
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-xs font-medium text-zinc-300 mb-1">
                    Lösenord
                  </label>
                  <div className="relative">
                    <Lock className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-500" />
                    <input
                      type="password"
                      required
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      placeholder="••••••••"
                      className="w-full pl-10 pr-4 py-2 bg-zinc-950 border border-zinc-700 rounded-xl text-sm text-zinc-100 placeholder-zinc-500 focus:outline-none focus:border-brand-red"
                    />
                  </div>
                </div>

                <button
                  type="submit"
                  disabled={accountLoading}
                  className="w-full py-2.5 bg-brand-red hover:bg-brand-redPressed disabled:bg-zinc-800 text-white rounded-xl text-sm font-semibold shadow-lg shadow-brand-red/20 flex items-center justify-center gap-2 transition transform active:scale-95 mt-2"
                >
                  {accountLoading ? (
                    <Loader2 className="w-4 h-4 animate-spin" />
                  ) : (
                    <>
                      <span>{isSignUp ? 'Skapa konto och synka' : 'Logga in och synka'}</span>
                      <ArrowRight className="w-4 h-4" />
                    </>
                  )}
                </button>
              </form>

              <div className="text-center pt-1">
                <button
                  type="button"
                  onClick={() => {
                    setIsSignUp(!isSignUp);
                    setAccountMessage(null);
                  }}
                  className="text-xs text-zinc-400 hover:text-zinc-200 transition"
                >
                  {isSignUp
                    ? 'Har du redan ett konto? Logga in här'
                    : 'Ny här? Skapa ett konto gratis'}
                </button>
              </div>
            </div>
          ) : (
            /* Tab 2: Snabbkoppling via iPhone */
            <div className="flex flex-col items-center text-center space-y-6">
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
                    <div className="p-3.5 bg-white rounded-2xl shadow-xl shrink-0">
                      <QRCodeSVG value={qrValue} size={150} level="M" />
                    </div>

                    {/* 6-digit Code */}
                    <div className="flex flex-col items-center sm:items-start text-center sm:text-left space-y-2">
                      <span className="text-xs font-semibold text-zinc-400 uppercase tracking-wider">
                        Synkkod
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
                      <span className="w-5 h-5 rounded-full bg-zinc-800 text-brand-red font-bold flex items-center justify-center shrink-0 text-[11px]">
                        1
                      </span>
                      <span>Öppna <strong>Gameshelf</strong> på din iPhone.</span>
                    </div>
                    <div className="flex items-start gap-2.5 text-xs text-zinc-300">
                      <span className="w-5 h-5 rounded-full bg-zinc-800 text-brand-red font-bold flex items-center justify-center shrink-0 text-[11px]">
                        2
                      </span>
                      <span>Gå till <strong>Profil &gt; Konto & Synk</strong> (eller öppna iPhone-kameran och skanna QR-koden ovan).</span>
                    </div>
                    <div className="flex items-start gap-2.5 text-xs text-zinc-300">
                      <span className="w-5 h-5 rounded-full bg-zinc-800 text-brand-red font-bold flex items-center justify-center shrink-0 text-[11px]">
                        3
                      </span>
                      <span>
                        Tryck <strong>Godkänn</strong> – ditt bibliotek visas direkt på skärmen!
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
          )}
        </div>
      </div>
    </div>
  );
}
