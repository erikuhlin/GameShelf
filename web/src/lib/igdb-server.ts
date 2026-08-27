// Server-side IGDB API helper with automatic Twitch OAuth token caching

interface TokenCache {
  token: string;
  expiresAt: number;
}

let cachedToken: TokenCache | null = null;

export async function getTwitchAccessToken(): Promise<string> {
  const clientId = process.env.TWITCH_CLIENT_ID;
  const clientSecret = process.env.TWITCH_CLIENT_SECRET;

  if (!clientId || !clientSecret) {
    throw new Error('TWITCH_CLIENT_ID or TWITCH_CLIENT_SECRET is missing in environment variables.');
  }

  // Return cached token if valid (with 60-second buffer)
  if (cachedToken && cachedToken.expiresAt > Date.now() + 60000) {
    return cachedToken.token;
  }

  const url = `https://id.twitch.tv/oauth2/token?client_id=${encodeURIComponent(
    clientId
  )}&client_secret=${encodeURIComponent(clientSecret)}&grant_type=client_credentials`;

  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    cache: 'no-store',
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Failed to obtain Twitch OAuth token (${res.status}): ${errText}`);
  }

  const data = await res.json();
  const token = data.access_token;
  const expiresIn = data.expires_in || 3600;

  cachedToken = {
    token,
    expiresAt: Date.now() + expiresIn * 1000,
  };

  return token;
}

export async function queryIGDB(endpoint: string, queryBody: string) {
  const token = await getTwitchAccessToken();
  const clientId = process.env.TWITCH_CLIENT_ID!;

  const url = `https://api.igdb.com/v4/${endpoint}`;

  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Client-ID': clientId,
      Authorization: `Bearer ${token}`,
      'Content-Type': 'text/plain',
    },
    body: queryBody,
    cache: 'no-store',
  });

  if (!res.ok) {
    const errorText = await res.text();
    throw new Error(`IGDB query failed (${res.status}): ${errorText}`);
  }

  return res.json();
}
