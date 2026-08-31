import { NextRequest, NextResponse } from 'next/server';
import { queryIGDB } from '@/lib/igdb-server';

export async function GET(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  const companyParam = params.id;

  if (!companyParam || companyParam.trim() === '') {
    return NextResponse.json({ error: 'Företagsidentifierare saknas' }, { status: 400 });
  }

  try {
    // 1. Hämta företagsdetaljer (antingen via numeriskt ID eller namnsökning)
    let companyQuery = '';
    if (!isNaN(Number(companyParam)) && Number(companyParam) > 0) {
      companyQuery = `
        where id = ${companyParam};
        fields name, description, logo.image_id, logo.url, start_date, country, url, developed, published;
        limit 1;
      `;
    } else {
      const decoded = decodeURIComponent(companyParam).replace(/"/g, '\\"');
      companyQuery = `
        search "${decoded}";
        fields name, description, logo.image_id, logo.url, start_date, country, url, developed, published;
        limit 1;
      `;
    }

    const companyData = await queryIGDB('companies', companyQuery);

    if (!companyData || companyData.length === 0) {
      return NextResponse.json({ error: 'Företaget hittades inte' }, { status: 404 });
    }

    const comp = companyData[0];
    const targetCompanyId = comp.id;

    // Formatera logotyp
    let logoUrl = comp.logo?.url;
    if (logoUrl) {
      if (logoUrl.startsWith('//')) {
        logoUrl = 'https:' + logoUrl;
      }
      logoUrl = logoUrl.replace('/t_thumb/', '/t_logo_med/');
    } else if (comp.logo?.image_id) {
      logoUrl = `https://images.igdb.com/igdb/image/upload/t_logo_med/${comp.logo.image_id}.png`;
    }

    // 2. Hämta spelkatalog för företaget (både utvecklade och utgivna)
    const gamesQuery = `
      where involved_companies.company = ${targetCompanyId} & category = (0, 8, 9, 10, 11);
      fields name, summary, first_release_date, cover.image_id, cover.url, total_rating, total_rating_count, rating, genres.name, platforms.name, involved_companies.company, involved_companies.developer, involved_companies.publisher;
      sort first_release_date desc;
      limit 100;
    `;

    const gamesData = await queryIGDB('games', gamesQuery);

    const formattedGames = (gamesData || []).map((g: any) => {
      let cover = g.cover?.url;
      if (cover) {
        if (cover.startsWith('//')) {
          cover = 'https:' + cover;
        }
        cover = cover.replace('/t_thumb/', '/t_cover_big/');
      } else if (g.cover?.image_id) {
        cover = `https://images.igdb.com/igdb/image/upload/t_cover_big/${g.cover.image_id}.jpg`;
      }

      // Avgör roll för spelet (utvecklare eller utgivare)
      const thisCompanyInv = (g.involved_companies || []).find(
        (ic: any) => ic.company === Number(targetCompanyId)
      );

      const isDeveloper = thisCompanyInv ? Boolean(thisCompanyInv.developer) : false;
      const isPublisher = thisCompanyInv ? Boolean(thisCompanyInv.publisher) : false;

      return {
        id: g.id,
        name: g.name,
        summary: g.summary || '',
        coverUrl: cover || null,
        firstReleaseDate: g.first_release_date || null,
        releaseYear: g.first_release_date
          ? new Date(g.first_release_date * 1000).getFullYear()
          : null,
        totalRating: g.total_rating || g.rating || null,
        genres: (g.genres || []).map((gen: any) => gen.name),
        platforms: (g.platforms || []).map((p: any) => p.name),
        isDeveloper,
        isPublisher,
      };
    });

    return NextResponse.json({
      company: {
        id: comp.id,
        name: comp.name,
        description: comp.description || '',
        logoUrl: logoUrl || null,
        startDate: comp.start_date || null,
        country: comp.country || null,
        developedCount: (comp.developed || []).length,
        publishedCount: (comp.published || []).length,
      },
      games: formattedGames,
    });
  } catch (error: any) {
    console.error(`[API Companies ${companyParam}] Error:`, error);
    return NextResponse.json(
      { error: error.message || 'Kunde inte hämta företagsdetaljer' },
      { status: 500 }
    );
  }
}
