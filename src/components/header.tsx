"use client";
import Link from "next/link";
import { useTheme } from "@/components/theme-provider";
import { useState } from "react";
export function Header() {
 const { theme, toggle } = useTheme(); const [open, setOpen] = useState(false);
 return <header className="site-header"><Link className="wordmark" href="/">IZ<span>O</span>RA<span className="wordmark-dot">.</span></Link><button className="mobile-menu" onClick={() => setOpen(!open)} aria-label="باز کردن منو">☰</button><nav className={open ? "nav-links nav-open" : "nav-links"}><Link href="/discover">کشف رسانه‌ها</Link><a href="#featured">رسانه‌های منتخب</a><a href="#about">درباره ایزورا</a></nav><div className="header-actions"><button className="icon-button" onClick={toggle} aria-label="تغییر پوسته">{theme === "dark" ? "☼" : "☾"}</button><Link className="login-link" href="/login">ورود</Link><Link className="button button-small" href="/register">شروع فعالیت <span>↗</span></Link></div></header>;
}