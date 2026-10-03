import { NextRequest, NextResponse } from 'next/server';
import { syncIGDBRatings } from '@/lib/ratingSync';

export const maxDuration = 300; // Allow max timeout where supported (e.g. Vercel Pro/Fluid compute)

export async function GET(request: NextRequest) {
  return handleSync(request);
}

export async function POST(request: NextRequest) {
  return handleSync(request);
}

async function handleSync(request: NextRequest) {
  const authHeader = request.headers.get('authorization');
  const cronSecret = process.env.CRON_SECRET;

  // Verify secret if CRON_SECRET is configured
  if (cronSecret && authHeader !== `Bearer ${cronSecret}`) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const searchParams = request.nextUrl.searchParams;
  const maxBatches = Number(searchParams.get('batches')) || 2; // Default to 2 batches (1000 games) for fast HTTP responses
  const minVotes = Number(searchParams.get('min_votes')) || 5;

  const logs: string[] = [];
  try {
    const result = await syncIGDBRatings({
      batchSize: 500,
      maxBatches,
      minVoteCount: minVotes,
      onProgress: (msg) => logs.push(`[${new Date().toLocaleTimeString()}] ${msg}`),
    });

    return NextResponse.json({
      success: true,
      message: 'Ratings synchronized successfully',
      count: result.count,
      top5: result.top5,
      logs,
    });
  } catch (error: any) {
    return NextResponse.json(
      {
        success: false,
        error: error.message || 'Rating sync failed',
        logs,
      },
      { status: 500 }
    );
  }
}
