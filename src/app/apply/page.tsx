import Link from "next/link";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { MediaApplicationForm } from "@/components/media-application-form";
export const dynamic="force-dynamic";
export default async function ApplyPage(){
 const supabase=await createClient();const {data:{user}}=await supabase.auth.getUser();if(!user)redirect("/login");
 const {data:existing}=await supabase.from("media").select("id").eq("owner_user_id",user.id).maybeSingle();if(existing)redirect("/dashboard");
 return <main className="form-page"><header className="dashboard-top"><Link className="wordmark" href="/">IZ<span>O</span>RA<span className="wordmark-dot">.</span></Link><Link href="/dashboard" className="text-link">داشبورد ←</Link></header><section className="form-page-intro"><div className="section-kicker">درخواست عضویت / رسانه</div><h1>خودتان را<br/><span>معرفی کنید.</span></h1><p>اطلاعات اولیه را وارد کنید. درخواست شما برای بررسی ارسال می‌شود و پس از تأیید، صفحه اختصاصی رسانه فعال خواهد شد.</p></section><section className="form-panel"><MediaApplicationForm/></section></main>;
}