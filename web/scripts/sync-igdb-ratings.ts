import fs from 'fs';
import path from 'path';
import { syncIGDBRatings } from '../src/lib/ratingSync';

// Load .env.local manually if running in pure node/tsx without dotenv
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

// Parse CLI arguments: e.g. --batches 5, --min-votes 10, --m 75
const args = process.argv.slice(2);
let maxBatches = 0;
let minVotes = 5; // Default: at least 5 votes to filter out zero-traction noise while keeping indie gems
let mVal = 75;

for (let i = 0; i < args.length; i++) {
  if (args[i] === '--batches' && args[i + 1]) {
    maxBatches = parseInt(args[i + 1], 10);
    i++;
  } else if (args[i] === '--min-votes' && args[i + 1]) {
    minVotes = parseInt(args[i + 1], 10);
    i++;
  } else if (args[i] === '--m' && args[i + 1]) {
    mVal = parseInt(args[i + 1], 10);
    i++;
  }
}

async function run() {
  console.log('--- Gameshelf IGDB Weighted Rating Synchronizer ---');
  console.log(`Config: minVotes=${minVotes}, m=${mVal}, maxBatches=${maxBatches || 'unlimited'}`);

  try {
    const result = await syncIGDBRatings({
      batchSize: 500,
      maxBatches,
      minVoteCount: minVotes,
      mThreshold: mVal,
      onProgress: (msg) => console.log(`[${new Date().toLocaleTimeString()}] ${msg}`),
    });

    console.log('\n--- Sync Finished Successfully! ---');
    console.log(`Total processed: ${result.count}`);
    if (result.top5 && result.top5.length > 0) {
      console.log('\nTop 5 Games:');
      console.table(result.top5);
    }
    process.exit(0);
  } catch (error) {
    console.error('\n❌ Fatal sync error:', error);
    process.exit(1);
  }
}

run();
