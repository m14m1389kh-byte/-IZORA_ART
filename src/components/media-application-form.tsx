"use client";
import { FormEvent, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
export function MediaApplicationForm(){
 const router=useRouter();
 const [name,setName]=useState(""); const [slug,setSlug]=useState(""); const [bio,setBio]=useState(""); const [email,setEmail]=useState(""); const [specialties,setSpecialties]=useState(""); const [error,setError]=useState(""); const [busy,setBusy]=useState(false);
 async function submit(event:FormEvent<HTMLFormElement>){event.preventDefault();setError("");setBusy(true);
  try{
   const client=createClient(); const {data:{user}}=await client.auth.getUser();
   if(!user){router.push("/login");return;}
   const safeSlug=slug.trim().toLowerCase().replace(/[^a-z0-9-]/g,"").replace(/-+/g,"-").replace(/^-|-$/g,"");
   if(safeSlug.length<2)throw new Error("شناسه انگلیسی باید حداقل ۲ حرف داشته باشد.");
   const {error}=await client.from("media").insert({owner_user_id:user.id,name:name.trim(),slug:safeSlug,bio:bio.trim(),contact_email:email.trim()||null,specialties:specialties.split(",").map(x=>x.trim()).filter(Boolean),status:"pending"});
   if(error)throw error; router.push("/dashboard");router.refresh();
  }catch(e){setError(e instanceof Error?e.message:"ثبت درخواست انجام نشد.");}finally{setBusy(false);}
 }
 return <form className="application-form" onSubmit={submit}>
  <label>نام رسانه یا مجموعه<input value={name} onChange={e=>setName(e.target.value)} required minLength={2} maxLength={80}/></label>
  <label>شناسه انگلیسی صفحه<input dir="ltr" value={slug} onChange={e=>setSlug(e.target.value)} placeholder="your-media-name" required pattern="[A-Za-z0-9-]{2,40}"/><small>آدرس صفحه شما به شکل /media/شناسه خواهد بود.</small></label>
  <label>معرفی کوتاه<textarea value={bio} onChange={e=>setBio(e.target.value)} rows={4} maxLength={600} placeholder="حوزه فعالیت و ویژگی‌های رسانه را توضیح دهید."/></label>
  <label>حوزه‌های تخصصی<input value={specialties} onChange={e=>setSpecialties(e.target.value)} placeholder="طراحی گرافیک، تدوین، موشن‌گرافیک"/></label>
  <label>ایمیل تماس عمومی<input type="email" value={email} onChange={e=>setEmail(e.target.value)} placeholder="hello@example.com"/></label>
  {error&&<p className="form-message form-error">{error}</p>}
  <button className="button" disabled={busy}>{busy?"در حال ثبت…":"ارسال برای بررسی"} <span>↗</span></button>
 </form>;
}