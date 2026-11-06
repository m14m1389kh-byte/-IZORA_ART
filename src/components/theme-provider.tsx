"use client";
import { createContext, useContext, useEffect, useState } from "react";
type Theme = "dark" | "light";
const ThemeContext = createContext<{ theme: Theme; toggle: () => void }>({ theme: "dark", toggle: () => undefined });
export function ThemeProvider({ children }: { children: React.ReactNode }) {
 const [theme, setTheme] = useState<Theme>("dark");
 useEffect(() => { const saved = window.localStorage.getItem("izora-theme"); const initial = saved === "light" ? "light" : "dark"; setTheme(initial); document.documentElement.dataset.theme = initial; }, []);
 const toggle = () => { const next = theme === "dark" ? "light" : "dark"; setTheme(next); document.documentElement.dataset.theme = next; window.localStorage.setItem("izora-theme", next); };
 return <ThemeContext.Provider value={{ theme, toggle }}>{children}</ThemeContext.Provider>;
}
export const useTheme = () => useContext(ThemeContext);