import Link from "next/link";
import { notFound } from "next/navigation";
import { Header } from "@/components/header";
import { createClient } from "@/lib/supabase/server";
export const dynamic="force-dynamic";
export default async function MediaProfile({params}:{params:Promise<{slug:string}>}) {
 const {slug}=await params;
 const supabase=await createClient();
 const {data:media}=await supabase.from("media").select("id,name,slug,bio,specialties,is_verified").eq("slug",slug).eq("status","approved").is("deleted_at",null).maybeSingle();
 if(!media) notFound();
 const {data:works}=await supabase.from("portfolio_items").select("id,title,description,asset_kind").eq("media_id",media.id).eq("status","published").order("created_at",{ascending:false}).limit(36);
 return <main><Header/><section className="shell profile-hero"><Link href="/discover" className="profile-back">← بازگشت به کشف رسانه‌ها</Link><div className="profile-brand"><div className="profile-avatar">{media.name.slice(0,1)}</div><div><div className="section-kicker">رسانه خلاق {media.is_verified&&<span className="verified">✓ تأییدشده</span>}</div><h1>{media.name}</h1></div></div><p>{media.bio}</p><div className="media-tags">{(media.specialties||[]).map(tag=><span key={tag}>{tag}</span>)}</div></section><section className="shell profile-works"><div className="directory-head"><h2>نمونه‌کارها</h2><span>{works?.length??0} اثر</span></div>{works?.length?<div className="work-grid">{works.map(work=><article className="work-card" key={work.id}><div className="work-placeholder"><span>{work.asset_kind==="video"?"PLAY":"IZ."}</span></div><div className="work-meta"><h3>{work.title}</h3><p>{work.description}</p></div></article>)}</div>:<div className="empty-state compact"><h3>نمونه‌کاری منتشر نشده است.</h3><p>به‌زودی آثار این رسانه در این صفحه نمایش داده می‌شوند.</p></div>}</section></main>;
}