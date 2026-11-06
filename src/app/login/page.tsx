import Link from "next/link";
import { AuthForm } from "@/components/auth-form";
export default function LoginPage(){return <main className="auth-page"><Link href="/" className="wordmark">IZ<span>O</span>RA<span className="wordmark-dot">.</span></Link><section className="auth-card"><div className="section-kicker">حساب کاربری / ۰۱</div><h1>خوش برگشتی.</h1><p>برای ادامه به فضای کاری خود وارد شوید.</p><AuthForm mode="login"/></section><Link href="/" className="auth-back">بازگشت به صفحه اصلی ←</Link></main>}
