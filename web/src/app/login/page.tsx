'use client';

import React, { useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabase';
import { Gamepad2, Mail, Lock, Sparkles, ArrowRight, Loader2, CheckCircle2 } from 'lucide-react';
import Link from 'next/link';

export default function LoginPage() {
  const router = useRouter();
  const [authMode, setAuthMode] = useState<'password' | 'magic-link'>('password');
  const [isSignUp, setIsSignUp] = useState(false);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [message, setMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email) return;

    setIsLoading(true);
    setMessage(null);

    try {
      if (authMode === 'magic-link') {
        const { error } = await supabase.auth.signInWithOtp({
          email,
          options: {
            emailRedirectTo: typeof window !== 'undefined' ? `${window.location.origin}/` : undefined,
          },
        });
        if (error) throw error;
        setMessage({
          type: 'success',
          text: 'En inloggningslänk har skickats till din e-postadress!',
        });
      } else if (isSignUp) {
        const { data, error } = await supabase.auth.signUp({
          email,
          password,
        });
        if (error) throw error;
        if (data.session) {
          router.push('/');
        } else {
          setMessage({
            type: 'success',
            text: 'Konto skapat! Kontrollera din e-post för att bekräfta kontot.',
          });
        }
      } else {
        const { error } = await supabase.auth.signInWithPassword({
          email,
          password,
        });
        if (error) throw error;
        router.push('/');
      }
    } catch (err: any) {
      setMessage({
        type: 'error',
        text: err.message || 'Ett fel uppstod vid autentisering',
      });
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-[#0d0e12] flex flex-col justify-center items-center px-4 sm:px-6 lg:px-8 py-12">
      <div className="w-full max-w-md space-y-8">
        {/* Header & Logo */}
        <div className="text-center">
          <div className="mx-auto w-14 h-14 rounded-2xl bg-gradient-to-tr from-brand-red to-rose-500 flex items-center justify-center shadow-xl shadow-brand-red/25 text-white">
            <Gamepad2 className="w-8 h-8" />
          </div>
          <h2 className="mt-5 text-2xl sm:text-3xl font-bold tracking-tight text-white">
            Logga in på Gameshelf
          </h2>
          <p className="mt-2 text-xs text-zinc-400">
            Synka din spelsamling mellan iOS-appen och webbläsaren.
          </p>
        </div>

        {/* Card */}
        <div className="bg-[#16181f] border border-zinc-800 rounded-2xl p-6 sm:p-8 shadow-2xl space-y-6">
          {/* Method tabs */}
          <div className="flex bg-zinc-950 p-1 rounded-xl border border-zinc-800">
            <button
              type="button"
              onClick={() => {
                setAuthMode('password');
                setMessage(null);
              }}
              className={`flex-1 py-2 text-xs font-semibold rounded-lg transition ${
                authMode === 'password'
                  ? 'bg-zinc-800 text-white shadow-sm'
                  : 'text-zinc-400 hover:text-zinc-200'
              }`}
            >
              Lösenord
            </button>
            <button
              type="button"
              onClick={() => {
                setAuthMode('magic-link');
                setMessage(null);
              }}
              className={`flex-1 py-2 text-xs font-semibold rounded-lg transition ${
                authMode === 'magic-link'
                  ? 'bg-zinc-800 text-white shadow-sm'
                  : 'text-zinc-400 hover:text-zinc-200'
              }`}
            >
              Magic Link
            </button>
          </div>

          {message && (
            <div
              className={`p-3.5 rounded-xl text-xs flex items-start gap-2.5 ${
                message.type === 'success'
                  ? 'bg-emerald-950/60 border border-emerald-800/80 text-emerald-300'
                  : 'bg-red-950/60 border border-red-800/80 text-red-300'
              }`}
            >
              {message.type === 'success' && <CheckCircle2 className="w-4 h-4 flex-shrink-0 mt-0.5" />}
              <span>{message.text}</span>
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-xs font-medium text-zinc-300 mb-1.5">
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
                  className="w-full pl-10 pr-4 py-2.5 bg-zinc-950 border border-zinc-700 rounded-xl text-sm text-zinc-100 placeholder-zinc-500 focus:outline-none focus:border-brand-red"
                />
              </div>
            </div>

            {authMode === 'password' && (
              <div>
                <label className="block text-xs font-medium text-zinc-300 mb-1.5">
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
                    className="w-full pl-10 pr-4 py-2.5 bg-zinc-950 border border-zinc-700 rounded-xl text-sm text-zinc-100 placeholder-zinc-500 focus:outline-none focus:border-brand-red"
                  />
                </div>
              </div>
            )}

            <button
              type="submit"
              disabled={isLoading}
              className="w-full py-2.5 bg-brand-red hover:bg-brand-redPressed disabled:bg-zinc-800 text-white rounded-xl text-sm font-semibold shadow-lg shadow-brand-red/20 flex items-center justify-center gap-2 transition transform active:scale-95"
            >
              {isLoading ? (
                <Loader2 className="w-4 h-4 animate-spin" />
              ) : (
                <>
                  <span>
                    {authMode === 'magic-link'
                      ? 'Skicka Magic Link'
                      : isSignUp
                      ? 'Skapa konto'
                      : 'Logga in'}
                  </span>
                  <ArrowRight className="w-4 h-4" />
                </>
              )}
            </button>
          </form>

          {authMode === 'password' && (
            <div className="text-center pt-2">
              <button
                type="button"
                onClick={() => setIsSignUp(!isSignUp)}
                className="text-xs text-zinc-400 hover:text-zinc-200 transition"
              >
                {isSignUp
                  ? 'Har du redan ett konto? Logga in'
                  : 'Ny användare? Skapa ett konto'}
              </button>
            </div>
          )}
        </div>

        {/* Back to Home */}
        <div className="text-center">
          <Link
            href="/"
            className="text-xs text-zinc-500 hover:text-zinc-300 transition"
          >
            ← Fortsätt till spelhyllan utan att logga in
          </Link>
        </div>
      </div>
    </div>
  );
}
