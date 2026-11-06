import type { Metadata } from "next";
import "./globals.css";
import { ThemeProvider } from "@/components/theme-provider";
export const metadata: Metadata = { title: "IZORA — خانه رسانه‌های خلاق", description: "رسانه‌ها و مجموعه‌های خلاق را کشف کنید؛ آثارشان را ببینید و با آن‌ها ارتباط بگیرید.", applicationName: "IZORA" };
export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) { return <html lang="fa" dir="rtl" suppressHydrationWarning><body><ThemeProvider>{children}</ThemeProvider></body></html>; }