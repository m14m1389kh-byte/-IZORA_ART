import Link from "next/link";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
export const dynamic="force-dynamic";
export default async function DashboardPage(){
 const supabase=await createClient();const {data:{user}}=await supabase.auth.getUser();if(!user)redirect("/login");
 const [{data:profile},{data:media}]=await Promise.all([
  supabase.from("profiles").select("display_name,role").eq("id",user.id).maybeSingle(),
  supabase.from("media").select("id,name,slug,status,is_verified").eq("owner_user_id",user.id).maybeSingle()
 ]);
 return <main className="dashboard-shell"><header className="dashboard-top"><Link className="wordmark" href="/">IZ<span>O</span>RA<span className="wordmark-dot">.</span></Link><Link href="/" className="text-link">مشاهده سایت ↗</Link></header><section className="dashboard-welcome"><div className="section-kicker">فضای کاری / داشبورد</div><h1>سلام، {profile?.display_name||user.email?.split("@")[0]||"دوست خلاق"}.</h1><p>از اینجا می‌توانید حضور خود را در شبکه IZORA مدیریت کنید.</p></section><section className="dashboard-panel"><div className="dashboard-panel-head"><div><div className="section-kicker">وضعیت رسانه</div><h2>{media?"رسانه شما":"هنوز رسانه‌ای ندارید"}</h2></div>{media&&<span className={"status-chip status-"+media.status}>{media.status==="approved"?"تأیید شده":media.status==="pending"?"در انتظار بررسی":media.status}</span>}</div>{media?<><p className="dashboard-description">{media.name} {media.status==="pending"?"پس از بررسی و تأیید مدیر کل، صفحه عمومی و پنل رسانه فعال می‌شود.":"آماده مدیریت و تکمیل نمونه‌کارهاست."}</p>{media.status==="approved"&&<Link className="button" href={`/media/${media.slug}`}>مشاهده صفحه عمومی <span>↗</span></Link>}</>:<><p className="dashboard-description">برای معرفی استودیو، تیم یا رسانه خلاق خود، درخواست عضویت ثبت کنید. پس از تأیید، صفحه اختصاصی و پنل مدیریت در اختیارتان قرار می‌گیرد.</p><Link className="button" href="/apply">ثبت درخواست معرفی رسانه <span>↗</span></Link></>}</section><section className="dashboard-footnote"><span>حساب شما</span><strong>{user.email}</strong><Link href="/sign-out">خروج از حساب</Link></section></main>;
}