import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'Gameshelf - Din Personliga Spelsamling & Hylla',
  description: 'Organisera, spåra och upptäck spel med Gameshelf. Synkroniserad med iOS och IGDB.',
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
