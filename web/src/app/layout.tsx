import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'Gameshelf - Din Personliga Spelsamling & Hylla',
  description: 'Organisera, spåra och upptäck spel med Gameshelf. Synkroniserad med iOS och IGDB.',
  manifest: '/manifest.json',
  icons: {
    icon: [
      { url: '/favicon.ico?v=2' },
      { url: '/icon.png?v=2', sizes: '512x512', type: 'image/png' },
      { url: '/favicon-32x32.png?v=2', sizes: '32x32', type: 'image/png' },
      { url: '/favicon-16x16.png?v=2', sizes: '16x16', type: 'image/png' },
    ],
    apple: [
      { url: '/apple-touch-icon.png?v=2', sizes: '180x180', type: 'image/png' },
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
