# Gameshelf – Utvecklingsguide för Web & iOS

Denna guide beskriver hur du startar den lokala utvecklingsmiljön för **Gameshelf Web (Next.js)**, **Supabase Backend** och synkroniserar med **Gameshelf iOS-appen**.

---

## 1. Öppna projektet i Visual Studio Code

Webbprojektet och Supabase-konfigurationen kan öppnas separat i VS Code på två sätt:

### Alternativ A: Via terminalen
```bash
code web/
# eller öppna hela multi-root workspacet:
code web.code-workspace
```

### Alternativ B: I VS Code GUI
- Välj **File > Open Workspace from File...** och välj [`web.code-workspace`](./web.code-workspace).
- Rekommenderade extensions (Tailwind CSS IntelliSense, ESLint, Prettier) installeras automatiskt från [`.vscode/extensions.json`](./web/.vscode/extensions.json).

---

## 2. Starta den lokala Supabase-databasen

Supabase körs lokalt med databas, Auth och Realtime via Supabase CLI (kräver Docker Desktop eller OrbStack):

```bash
# Från projektets rotmapp:
npx supabase start
```

### Lokala adresser & Uppgifter:
- **API URL:** `http://127.0.0.1:54321`
- **Studio Dashboard:** `http://127.0.0.1:54323` (webbgränssnitt för att inspektera tabellerna `user_games` och `profiles`)
- **PostgreSQL:** `postgresql://postgres:postgres@127.0.0.1:54322/postgres`
- **Anon Public Key:** `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM0MTkyMDB9.dummy`

---

## 3. Starta Next.js-webbservern

I VS Code-terminalen eller en separat terminal:

```bash
cd web
npm run dev
```

Öppna webbläsaren på [http://localhost:3000](http://localhost:3000).

### Tillgängliga webbsidor:
- **Hyllan (`/`):** Din spelsamling med 3D-hyllvy, rutnät och listvy samt filtrering på status (*Spelar nu*, *Backlog*, *Klar* m.fl.).
- **Sök & Lägg till (`/search`):** Sök spel direkt i IGDB och spara med ett klick.
- **Inloggning (`/login`):** Logga in med e-post/lösenord eller Magic Link.

---

## 4. Köra iOS-appen & Testa Realtidssynk

1. **Öppna i Xcode:**
   - Öppna `Gameshelf.xcodeproj` i Xcode.
   - Välj valfri Simulator (t.ex. *iPhone 16 Pro*) eller din fysiska enhet.
   - Tryck **Cmd + R** för att bygga och köra (eller kör `./deploy.sh`).

2. **Testa tvåvägssynkronisering:**
   - **Från Webb till App:**
     1. Gå till [http://localhost:3000/search](http://localhost:3000/search) i webbläsaren.
     2. Sök efter ett spel (t.ex. *Metroid Prime*) och tryck **Lägg till**.
     3. I iOS-appen i Simulatorn: Dra nedåt på biblioteksskärmen (pull-to-refresh) eller starta om appen – spelet syns nu direkt i din iOS-samling med omslag och metadata!
   - **Från App till Webb:**
     1. Lägg till ett spel eller ändra status (t.ex. ändra från *Backlog* till *Spelar nu*) i iOS-appen.
     2. Titta i webbläsaren – tack vare Supabase Realtime uppdateras sidan omedelbart utan att du behöver ladda om!

3. **Länka konto (valfritt):**
   - I iOS-appen: Gå till **Profile > Webb & Databassynk > Länka konto**.
   - Ange en e-postadress och lösenord för att skapa permanent webbinloggning.
