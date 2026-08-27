import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./src/pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/components/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  darkMode: "class",
  theme: {
    extend: {
      colors: {
        brand: {
          red: "#E53E3E",
          redPressed: "#C53030",
          redDark: "#9B2C2C",
        },
        shelf: {
          wood: "#2C221E",
          woodLight: "#3D312A",
          border: "#4A3B33",
        },
        surface: {
          dark: "#121212",
          card: "#1E1E1E",
          cardHover: "#282828",
          border: "#333333",
        },
      },
    },
  },
  plugins: [],
};
export default config;
