import fs from 'fs';
import path from 'path';
import { createClient } from '@supabase/supabase-js';
import { VERIFIED_WALKTHROUGHS, normalizeWalkthroughTitle } from '../src/lib/verifiedWalkthroughs';

if (typeof globalThis.WebSocket === 'undefined') {
  // @ts-ignore
  globalThis.WebSocket = class DummyWebSocket {};
}

function loadEnvLocal() {
  const envPath = path.resolve(__dirname, '../.env.local');
  if (fs.existsSync(envPath)) {
    const lines = fs.readFileSync(envPath, 'utf8').split('\n');
    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith('#')) continue;
      const eqIdx = trimmed.indexOf('=');
      if (eqIdx > 0) {
        const key = trimmed.slice(0, eqIdx).trim();
        const val = trimmed.slice(eqIdx + 1).trim();
        if (!process.env[key]) {
          process.env[key] = val;
        }
      }
    }
  }
}

loadEnvLocal();

async function run() {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://dgsifbugyepnzxvcfaax.supabase.co';
  const supabaseKey =
    process.env.SUPABASE_SERVICE_ROLE_KEY ||
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ||
    '';

  if (!supabaseKey) {
    console.error('❌ Missing NEXT_PUBLIC_SUPABASE_ANON_KEY in .env.local');
    process.exit(1);
  }

  const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  console.log(`🚀 Seeding ${VERIFIED_WALKTHROUGHS.length} verified 1:1 walkthroughs to Supabase...`);

  const rows: any[] = [];

  for (const w of VERIFIED_WALKTHROUGHS) {
    const baseRow = {
      igdb_id: w.igdbId,
      title: w.title,
      normalized_title: normalizeWalkthroughTitle(w.title),
      alternate_igdb_ids: w.alternateIgdbIds || [],
      has_linear_progression: w.hasLinearProgression,
      progression_type: w.progressionType,
      summary: w.summary,
      items: w.items,
      source: 'curated',
      source_url: w.sourceUrl,
      updated_at: new Date().toISOString(),
    };
    rows.push(baseRow);

    // Om spelet även finns under en alternativ utgåva i användarens bibliotek (t.ex. Gold Edition / Switch 2 Edition),
    // lägg även in en rad för det igdb_id:t så direktuppslag via igdb_id i iOS alltid träffar 100%
    if (w.alternateIgdbIds && w.alternateIgdbIds.length > 0) {
      for (const altId of w.alternateIgdbIds) {
        rows.push({
          ...baseRow,
          igdb_id: altId,
          alternate_igdb_ids: [w.igdbId],
        });
      }
    }
  }

  const { error } = await supabase.from('game_walkthroughs').upsert(rows, {
    onConflict: 'igdb_id',
  });

  if (error) {
    console.error(`❌ Error upserting to public.game_walkthroughs: ${error.message}`);
    console.error(
      '💡 Tips: Kör först SQL-migrationen supabase/migrations/20261024000000_create_game_walkthroughs.sql i Supabase SQL Editor!'
    );
    process.exit(1);
  }

  console.log(`✅ Successfully seeded ${rows.length} rows (${VERIFIED_WALKTHROUGHS.length} unique games + editions) into public.game_walkthroughs!`);
}

run();
