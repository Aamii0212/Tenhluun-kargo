import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type","Access-Control-Allow-Methods":"POST, OPTIONS"};
Deno.serve(async(req)=>{
 if(req.method==="OPTIONS")return new Response("ok",{headers:cors});
 const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,"Content-Type":"application/json"}});
 if(req.method!=="POST")return json({error:"Method not allowed"},405);
 try{
  const url=Deno.env.get("SUPABASE_URL")!,anonKey=Deno.env.get("SUPABASE_ANON_KEY")!,serviceKey=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,authHeader=req.headers.get("Authorization")||"";
  if(!authHeader.startsWith("Bearer "))return json({error:"Админ аккаунтаар нэвтэрнэ үү."},401);
  const caller=createClient(url,anonKey,{global:{headers:{Authorization:authHeader}}});
  const {data:userData,error:userError}=await caller.auth.getUser();
  if(userError||!userData.user)return json({error:"Нэвтрэх эрх баталгаажаагүй."},401);
  const {data:profile,error:profileError}=await caller.from("profiles").select("role").eq("id",userData.user.id).maybeSingle();
  if(profileError||profile?.role!=="admin")return json({error:"Зөвхөн админ ажилтан үүсгэнэ."},403);
  const body=await req.json(),username=String(body.username||"").trim().toLowerCase(),password=String(body.password||""),fullName=String(body.full_name||"").trim(),phone=String(body.phone||"").replace(/\D/g,""),branchId=String(body.branch_id||"").trim();
  if(!/^[a-z0-9_-]{3,30}$/.test(username))return json({error:"Нэвтрэх нэр 3-30 тэмдэгт, англи жижиг үсэг/тоо/_/- байна."},400);
  if(password.length<8)return json({error:"Нууц үг хамгийн багадаа 8 тэмдэгт байна."},400);
  if(!fullName)return json({error:"Ажилтны нэр оруулна уу."},400);
  if(!/^\d{8}$/.test(phone))return json({error:"Утасны дугаар 8 оронтой байна."},400);
  if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(branchId))return json({error:"Ажиллах салбараа сонгоно уу."},400);
  const email=username+"@tenhluun.invalid",admin=createClient(url,serviceKey,{auth:{autoRefreshToken:false,persistSession:false}});
  const {data:branch,error:branchError}=await admin.from("branches").select("id,name").eq("id",branchId).maybeSingle();
  if(branchError||!branch)return json({error:"Салбар олдсонгүй."},404);
  const {data:users,error:usersError}=await admin.auth.admin.listUsers({page:1,perPage:1000});
  if(usersError)return json({error:"Хэрэглэгч шалгахад алдаа: "+usersError.message},500);
  let target=users.users.find(u=>(u.email||"").toLowerCase()===email);
  if(target){
   const {data:existingProfile}=await admin.from("profiles").select("role").eq("id",target.id).maybeSingle();
   if(existingProfile?.role==="admin")return json({error:"Админы аккаунтыг ажилтан болгож өөрчлөхгүй."},409);
   const {data:updated,error:updateError}=await admin.auth.admin.updateUserById(target.id,{password,email_confirm:true,user_metadata:{username,full_name:fullName,phone}});
   if(updateError)return json({error:"Ажилтны нууц үг шинэчлэх алдаа: "+updateError.message},400);
   target=updated.user;
  }else{
   const {data,error}=await admin.auth.admin.createUser({email,password,email_confirm:true,user_metadata:{username,full_name:fullName,phone,role:"employee"}});
   if(error)return json({error:"Ажилтан үүсгэх алдаа: "+error.message},400);
   target=data.user;
  }
  const {error:profileUpsertError}=await admin.from("profiles").upsert({id:target.id,role:"employee"},{onConflict:"id"});
  if(profileUpsertError)return json({error:"Ажилтны эрх хадгалах алдаа: "+profileUpsertError.message},500);
  const {error:removeError}=await admin.from("employee_branch_access").delete().eq("employee_id",target.id);
  if(removeError)return json({error:"Өмнөх салбарын эрхийг цэвэрлэх алдаа: "+removeError.message},500);
  const {error:accessError}=await admin.from("employee_branch_access").insert({employee_id:target.id,branch_id:branchId,employee_email:email});
  if(accessError)return json({error:"Салбар оноох алдаа: "+accessError.message},500);
  return json({success:true,username,branch:branch.name,message:"✓ "+fullName+" ажилтны эрх үүсгэж, "+branch.name+" салбарт оноолоо. Нэвтрэх нэр: "+username});
 }catch(error){return json({error:error instanceof Error?error.message:"Тодорхойгүй алдаа"},500)}
});
