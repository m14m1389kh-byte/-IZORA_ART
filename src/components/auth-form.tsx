"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";

export function AuthForm({ mode }: { mode: "login" | "signup" }) {
  const router = useRouter();
  const [displayName, setDisplayName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [notice, setNotice] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const isSignup = mode === "signup";
  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setNotice(""); setError(""); setBusy(true);
    try {
      const client = createClient();
      const result = isSignup
        ? await client.auth.signUp({ email: email.trim().toLowerCase(), password, options: { data: { display_name: displayName.trim() } } })
        : await client.auth.signInWithPassword({ email: email.trim().toLowerCase(), password });
      if (result.error) throw result.error;
      if (isSignup && !result.data.session) {
        setNotice("حساب ایجاد شد. ایمیل تأیید را برای فعال‌سازی بررسی کنید.");
      } else {
        router.push("/dashboard"); router.refresh();
      }
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "امکان انجام درخواست وجود نداشت.");
    } finally { setBusy(false); }
  }
  return <form className="auth-form" onSubmit={submit}>
    {isSignup && <label>نام نمایشی<input value={displayName} onChange={e=>setDisplayName(e.target.value)} autoComplete="name" required minLength={2}/></label>}
    <label>ایمیل<input type="email" value={email} onChange={e=>setEmail(e.target.value)} autoComplete="email" required/></label>
    <label>رمز عبور<input type="password" value={password} onChange={e=>setPassword(e.target.value)} autoComplete={isSignup?"new-password":"current-password"} required minLength={8}/></label>
    {error && <p className="form-message form-error">{error}</p>}
    {notice && <p className="form-message form-success">{notice}</p>}
    <button className="button auth-submit" disabled={busy}>{busy?"در حال انجام…":isSignup?"ایجاد حساب":"ورود به حساب"} <span>↗</span></button>
    <p className="auth-switch">{isSignup?"حساب دارید؟":"حساب کاربری ندارید؟"} <Link href={isSignup?"/login":"/signup"}>{isSignup?"وارد شوید":"ثبت‌نام کنید"}</Link></p>
  </form>;
}