import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'Gameshelf - Din Personliga Spelsamling & Hylla',
  description: 'Organisera, spåra och upptäck spel med Gameshelf. Synkroniserad med iOS och IGDB.',
  manifest: '/manifest.json',
  icons: {
    icon: [
      { url: '/favicon.ico' },
      { url: '/icon.png', sizes: '512x512', type: 'image/png' },
    ],
    apple: [
      { url: '/apple-touch-icon.png', sizes: '180x180', type: 'image/png' },
    ],
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="sv" className="dark">
      <body className="bg-[#0d0e12] min-h-screen antialiased selection:bg-brand-red selection:text-white">
        {children}
      </body>
    </html>
  );
}
