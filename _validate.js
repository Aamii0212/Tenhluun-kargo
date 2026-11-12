
const SUPABASE_URL = "https://marlhculacividpbfddn.supabase.co";
const SUPABASE_KEY = "sb_publishable_13w76dxEXz7SWRAouotJvw_6Oceh9jh";
const db = window.supabase.createClient(SUPABASE_URL,SUPABASE_KEY);
let customerParcels = [];
let currentPhone = "";
let pendingTrackingCode = "";

function cleanPhone(value){return String(value||"").replace(/\D/g,"")}
function escapeHTML(value){return String(value??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]))}
function showMessage(id,message){const el=document.getElementById(id);if(el)el.textContent=message}
function classifyStatus(status){
 const s=String(status||"").toLowerCase().trim();
 if(s.includes("хүлээж ав")||s.includes("хүлээн ав")||s.includes("авсан")||s.includes("delivered")||s.includes("received")||s.includes("picked"))return "received";
 if(s.includes("монгол")||s.includes("mongol")||s.includes("ub_arrived")||s.includes("arrived_mn")||s.includes("in_mongolia")||s.includes("mn_warehouse"))return "mongolia";
 return "ereen";
}
function statusLabel(group){if(group==="received")return "Хүлээж авсан";if(group==="mongolia")return "Монголд ирсэн";return "Эрээнд ирсэн"}

async function customerLogin(){
 const phone=cleanPhone(document.getElementById("customerPhone").value);
 if(phone.length!==8){showMessage("customerMessage","8 оронтой утасны дугаараа оруулна уу.");return}
 const btn=document.getElementById("customerLoginButton");btn.disabled=true;btn.textContent="ШАЛГАЖ БАЙНА...";showMessage("customerMessage","");
 try{
  const {data,error}=await db.rpc("get_customer_parcels_by_phone",{p_phone:phone});
  if(error)throw error;
  currentPhone=phone;customerParcels=data||[];openCustomerDashboard();
  if(!customerParcels.length)showMessage("customerMessage","Ачааны түүх хоосон байна. Бүртгэл амжилттай нээгдлээ.");
  if(pendingTrackingCode){pendingTrackingCode="";}
 }catch(error){console.error(error);showMessage("customerMessage","Мэдээлэл авахад алдаа гарлаа. Дахин оролдоно уу.")}
 finally{btn.disabled=false;btn.textContent="➜ Нэвтрэх"}
}
function openCustomerDashboard(){
 document.getElementById("publicPage").style.display="none";document.getElementById("pageFooter").style.display="none";
 document.getElementById("customerHeader").style.display="flex";document.getElementById("customerDashboard").style.display="block";
 document.getElementById("customerPhoneLabel").textContent="Утас: "+currentPhone;
 const ereen=customerParcels.filter(p=>classifyStatus(p.parcel_status)==="ereen");
 const mongolia=customerParcels.filter(p=>classifyStatus(p.parcel_status)==="mongolia");
 const received=customerParcels.filter(p=>classifyStatus(p.parcel_status)==="received");
 document.getElementById("countEreen").textContent=ereen.length;document.getElementById("countMongolia").textContent=mongolia.length;document.getElementById("countReceived").textContent=received.length;
 const first=customerParcels.find(p=>p.branch_name||p.branch_address||p.branch_hours||p.branch_location);
 const branchInfo=document.getElementById("branchInfo");
 if(first){branchInfo.style.display="block";branchInfo.innerHTML=`<h3>Холбогдох салбар</h3><p><b>${escapeHTML(first.branch_name||"Салбар")}</b></p><p>${escapeHTML(first.branch_address||"")}</p><p>${escapeHTML(first.branch_hours||"")}</p>${first.branch_location?`<a href="${escapeHTML(first.branch_location)}" target="_blank" rel="noopener">Байршил харах</a>`:""}`}
 else{branchInfo.style.display="none"}
 showTab("ereen");
}
function showTab(tab){
 const tabIds={ereen:"tabEreen",mongolia:"tabMongolia",received:"tabReceived"};
 Object.keys(tabIds).forEach(name=>document.getElementById(tabIds[name]).classList.toggle("active",name===tab));
 const parcels=customerParcels.filter(p=>classifyStatus(p.parcel_status)===tab);const list=document.getElementById("parcelList");
 if(!parcels.length){list.innerHTML='<div class="empty">Энэ хэсэгт одоогоор ачаа байхгүй байна.</div>';return}
 list.innerHTML=parcels.map(p=>`<div class="parcel"><div class="parcel-top"><div class="tracking">${escapeHTML(p.tracking_code||"Трак кодгүй")}</div><span class="status-pill">${statusLabel(tab)}</span></div><div class="details"><div class="detail"><small>Ширхэг</small><b>${escapeHTML(p.piece_number??1)}</b></div><div class="detail"><small>Жин</small><b>${escapeHTML(p.weight_kg??"-")} кг</b></div><div class="detail"><small>Эзлэхүүн</small><b>${escapeHTML(p.volume_m3??"-")} м³</b></div><div class="detail"><small>Төлбөр</small><b>${escapeHTML(p.price_mnt??"-")} ₮</b></div></div>${p.description?`<p>${escapeHTML(p.description)}</p>`:""}${p.arrived_at?`<p class="muted">Ирсэн огноо: ${escapeHTML(new Date(p.arrived_at).toLocaleDateString("mn-MN"))}</p>`:""}</div>`).join("");
}
function customerLogout(){
 currentPhone="";customerParcels=[];pendingTrackingCode="";
 document.getElementById("customerDashboard").style.display="none";document.getElementById("customerHeader").style.display="none";
 document.getElementById("publicPage").style.display="block";document.getElementById("pageFooter").style.display="block";
 document.getElementById("customerPhone").value="";document.getElementById("trackingInput").value="";
 showMessage("customerMessage","");showMessage("trackingMessage","");
}
let siteSettings={kg_price:2500,m3_price:700,open_time:"10:00",close_time:"20:00"};
async function showEreenAddress(){
 const box=document.getElementById("ereenAddressBox");box.style.display=box.style.display==="none"?"block":"none";if(box.style.display==="none")return;
 const el=document.getElementById("ereenAddressText");el.textContent="Хаяг ачаалж байна...";
 try{const {data}=await db.from("site_settings").select("ereen_address,ereen_contact").eq("id",1).maybeSingle();
 el.innerHTML=data?.ereen_address?'<p>'+escapeHTML(data.ereen_address)+'</p><p>'+escapeHTML(data.ereen_contact||"")+'</p>':'Админ хаяг оруулаагүй байна.'}
 catch(e){el.textContent="Хаяг авахад алдаа гарлаа."}
}
async function showBranchLocations(){
 const box=document.getElementById("publicBranches");box.style.display=box.style.display==="none"?"block":"none";if(box.style.display==="none")return;
 const list=document.getElementById("publicBranchList");list.textContent="Ачаалж байна...";
 try{
  const [{data:branches,error:be},{data:settings,error:se}]=await Promise.all([db.from("branches").select("name,address,phone").order("name"),db.from("site_settings").select("open_time,close_time").eq("id",1).maybeSingle()]);
  if(be)throw be;const hours=(settings?.open_time||"10:00")+"–"+(settings?.close_time||"20:00");
  list.innerHTML=(branches||[]).map(b=>'<div style="padding:12px 0;border-bottom:1px solid #eee"><b>'+escapeHTML(b.name)+'</b><p>📍 '+escapeHTML(b.address||"Хаяг удахгүй нэмэгдэнэ")+'</p><p>☎ '+escapeHTML(b.phone||"Утас удахгүй нэмэгдэнэ")+'</p><p>🕒 Ажлын цаг: <b>'+hours+'</b></p></div>').join("")||"<p>Салбарын мэдээлэл одоогоор алга.</p>";
 }catch(e){list.textContent="Салбарын мэдээлэл авахад алдаа гарлаа."}
}
async function searchNoNameParcel(){
 const code=document.getElementById("noNameTrackingInput").value.trim(),out=document.getElementById("noNameTrackingResult");
 if(!code){out.textContent="Трак кодоо оруулна уу.";return}
 out.textContent="Хайж байна...";
 const {data,error}=await db.from("parcels").select("tracking_code,parcel_status,weight,volume,created_at").ilike("tracking_code",code).limit(1).maybeSingle();
 if(error){out.textContent="Хайлт хийхэд алдаа гарлаа.";return}
 if(!data){out.textContent="Энэ трак кодтой ачаа олдсонгүй.";return}
 out.innerHTML="<b>Ачаа олдлоо ✓</b><p>Трак код: "+escapeHTML(data.tracking_code)+"</p><p>Төлөв: "+escapeHTML(data.parcel_status||"Бүртгэлтэй")+"</p><p>Жин: "+escapeHTML(String(data.weight||0))+" кг</p><p>Эзлэхүүн: "+escapeHTML(String(data.volume||0))+" м³</p>";
}
function showNoNameCheck(){const b=document.getElementById("noNameCheckBox");b.style.display=b.style.display==="none"?"block":"none";}
function goPhoneCheck(){document.getElementById("customerPhone").scrollIntoView({behavior:"smooth"});document.getElementById("customerPhone").focus();}
async function showPricing(){
 const box=document.getElementById("publicPricing");box.style.display=box.style.display==="none"?"block":"none";
 try{const {data}=await db.from("site_settings").select("kg_price,m3_price,open_time,close_time").eq("id",1).maybeSingle();
 if(data){document.getElementById("publicKgPrice").textContent=Number(data.kg_price).toLocaleString()+" ₮";document.getElementById("publicM3Price").textContent=Number(data.m3_price).toLocaleString()+" юань";document.getElementById("publicHours").textContent=(data.open_time||"10:00")+"–"+(data.close_time||"20:00");}}
 catch(e){console.error(e)}
}
async function saveEreenAddress(){
 const payload={id:1,ereen_address:document.getElementById("settingEreenAddress").value.trim(),ereen_contact:document.getElementById("settingEreenContact").value.trim(),updated_at:new Date().toISOString()};
 const {error}=await db.from("site_settings").upsert(payload);if(error){showMessage("ereenSettingsInfo","Хадгалах алдаа: "+error.message);return}showMessage("ereenSettingsInfo","Хаяг хадгалагдлаа ✓");
}
async function loadSiteSettings(){
 const {data,error}=await db.from("site_settings").select("*").eq("id",1).maybeSingle();
 if(data){siteSettings={...siteSettings,...data};}
 document.getElementById("settingKg").value=siteSettings.kg_price??2500;
 document.getElementById("settingM3").value=siteSettings.m3_price??700;
 document.getElementById("settingOpen").value=siteSettings.open_time||"10:00";
 document.getElementById("settingClose").value=siteSettings.close_time||"20:00";
 document.getElementById("settingEreenAddress").value=siteSettings.ereen_address||"";document.getElementById("settingEreenContact").value=siteSettings.ereen_contact||"";
 if(error)document.getElementById("settingsInfo").textContent="DB хүснэгт тохируулах шаардлагатай";
}
async function saveSiteSettings(){
 const payload={id:1,kg_price:Number(document.getElementById("settingKg").value||0),m3_price:Number(document.getElementById("settingM3").value||0),open_time:document.getElementById("settingOpen").value||"10:00",close_time:document.getElementById("settingClose").value||"20:00",updated_at:new Date().toISOString()};
 const {error}=await db.from("site_settings").upsert(payload);
 if(error){showMessage("settingsInfo","Хадгалж чадсангүй: "+error.message);return}
 siteSettings=payload;showMessage("settingsInfo","Хадгалагдлаа ✓");
}
async function adminLogin(){
 const email=document.getElementById("adminEmail").value.trim(),password=document.getElementById("adminPassword").value;
 const msg=document.getElementById("adminMessage");msg.textContent="Нэвтэрч байна...";
 try{
  if(!email||!password){msg.textContent="Имэйл, нууц үгээ оруулна уу.";return}
  const {data,error}=await db.auth.signInWithPassword({email,password});
  if(error)throw error;
  const user=data?.user;if(!user)throw new Error("Auth хэрэглэгч олдсонгүй");
  const {data:profile,error:pe}=await db.from("profiles").select("role").eq("id",user.id).maybeSingle();
  if(pe)throw pe;
  if(profile?.role!=="admin"){await db.auth.signOut();msg.textContent="Админы эрх олгогдоогүй байна (profiles.role = admin).";return}
  document.getElementById("publicPage").style.display="none";
  document.getElementById("pageFooter").style.display="none";
  document.getElementById("customerHeader").style.display="none";
  document.getElementById("adminLogin").style.display="none";
  const dash=document.getElementById("adminDashboard");dash.classList.remove("hidden");dash.style.display="block";
  dash.scrollIntoView({behavior:"instant",block:"start"});
  await loadSiteSettings();
  await loadAdminParcels();
 }catch(e){console.error("Admin login/dashboard:",e);msg.textContent="Алдаа: "+(e.message||"Админ нэвтрэх боломжгүй");}
}
async function adminLogout(){await db.auth.signOut();document.getElementById("adminDashboard").style.display="none";document.getElementById("adminLogin").style.display="block"}

let adminParcels=[],editingParcelId=null,adminBranches=[];
function adminStatusLabel(s){return s==="received"?"Хүлээж авсан":s==="mongolia"?"Монголд ирсэн":"Эрээнд ирсэн"}
async function loadAdminParcels(){
 const body=document.getElementById("adminParcelRows");body.innerHTML='<tr><td colspan="6">Ачаалж байна...</td></tr>';
 const {data,error}=await db.from("parcels").select("*").order("created_at",{ascending:false}).limit(1000);
 if(error){console.error(error);body.innerHTML='<tr><td colspan="6">Ачаа татахад алдаа. Supabase дээр parcels хүснэгт болон RLS admin эрхийг шалгана уу.</td></tr>';showMessage("adminNotice",error.message);return}
 adminParcels=data||[];await loadBranches();renderAdminRows(adminParcels);showMessage("adminNotice",""); 
}
function updateAdminStats(){
 const total=adminParcels.length,ereen=adminParcels.filter(p=>classifyStatus(p.parcel_status)==="ereen").length,mongolia=adminParcels.filter(p=>classifyStatus(p.parcel_status)==="mongolia").length,received=adminParcels.filter(p=>classifyStatus(p.parcel_status)==="received"),revenue=received.reduce((sum,p)=>sum+Number(p.price_mnt||0),0),today=new Date().toLocaleDateString("en-CA");
 const paidToday=adminParcels.filter(p=>p.paid_at&&new Date(p.paid_at).toLocaleDateString("en-CA")===today),cash=paidToday.filter(p=>p.payment_method==="cash").reduce((s,p)=>s+Number(p.price_mnt||0),0),transfer=paidToday.filter(p=>p.payment_method==="transfer").reduce((s,p)=>s+Number(p.price_mnt||0),0);
 document.getElementById("statTotal").textContent=total;document.getElementById("statToday").textContent=adminParcels.filter(p=>p.created_at&&new Date(p.created_at).toLocaleDateString("en-CA")===today).length;document.getElementById("statEreen").textContent=ereen;document.getElementById("statMongolia").textContent=mongolia;document.getElementById("statReceived").textContent=received.length;document.getElementById("statRevenue").textContent=revenue.toLocaleString()+" ₮";
 const cashEl=document.getElementById("statCash"),transferEl=document.getElementById("statTransfer"),todayEl=document.getElementById("statTodayPaid");if(cashEl)cashEl.textContent=cash.toLocaleString()+" ₮";if(transferEl)transferEl.textContent=transfer.toLocaleString()+" ₮";if(todayEl)todayEl.textContent=(cash+transfer).toLocaleString()+" ₮";
}
function exportAdminCSV(){const rows=[["Салбар","Трак код","Нэр","Утас","Төлөв","Жин кг","М³","Үнэ ₮","Бүртгэсэн"],...adminParcels.map(p=>[adminBranches.find(b=>String(b.id)===String(p.branch_id))?.name||"",p.tracking_code,p.customer_name||p.name,p.customer_phone||p.phone,statusLabel(classifyStatus(p.parcel_status)),p.weight,p.volume,p.price_mnt,p.created_at])];const csv="\\uFEFF"+rows.map(r=>r.map(v=>'"'+String(v??"").replace(/"/g,'""')+'"').join(",")).join("\\r\\n");const blob=new Blob([csv],{type:"text/csv;charset=utf-8;"}),url=URL.createObjectURL(blob),a=document.createElement("a");a.href=url;a.download="tenhluun-parcels.csv";a.click();URL.revokeObjectURL(url)}
function exportPaymentsCSV(){
 const rows=[["Трак код","Салбар","Үнэ ₮","Төлбөр","Хүлээлгэн өгсөн ажилтан","Огноо"],...adminParcels.filter(p=>p.paid_at).map(p=>[p.tracking_code,adminBranches.find(b=>String(b.id)===String(p.branch_id))?.name||"",p.price_mnt,p.payment_method==="cash"?"Бэлэн":"Шилжүүлэг",p.received_by,p.paid_at])];
 const csv="\\uFEFF"+rows.map(r=>r.map(v=>'"'+String(v??"").replace(/"/g,'""')+'"').join(",")).join("\\r\\n");
 const blob=new Blob([csv],{type:"text/csv;charset=utf-8;"}),url=URL.createObjectURL(blob),a=document.createElement("a");a.href=url;a.download="tenhluun-payments.csv";a.click();URL.revokeObjectURL(url);
}
function renderAdminRows(rows){
 updateAdminStats();
 const body=document.getElementById("adminParcelRows");
 if(!rows.length){body.innerHTML='<tr><td colspan="7">Бүртгэлтэй ачаа алга.</td></tr>'}
 else body.innerHTML=rows.map(p=>'<tr><td>'+escapeHTML(adminBranches.find(b=>String(b.id)===String(p.branch_id))?.name||"-")+'</td><td><b>'+escapeHTML(p.tracking_code||"-")+'</b></td><td>'+escapeHTML(p.customer_name||p.name||"-")+'<br><small>'+escapeHTML(p.customer_phone||p.phone||"-")+'</small></td><td><span class="status-admin">'+adminStatusLabel(classifyStatus(p.parcel_status))+'</span></td><td>'+escapeHTML(p.weight_kg??"-")+' кг</td><td>'+escapeHTML(p.price_mnt??"-")+' ₮</td><td>'+(classifyStatus(p.parcel_status)!=="received"?'<button class="primary" onclick="handoverParcel(\''+String(p.id).replace(/'/g,"\\'")+'\')">Хүлээлгэн өгөх</button>':'<b>✓ Өгсөн</b>')+' <button class="edit-btn" onclick="editParcel(\''+String(p.id).replace(/'/g,"\\'")+'\')">Засах</button><button class="delete-btn" onclick="deleteParcel(\''+String(p.id).replace(/'/g,"\\'")+'\')">Устгах</button></td></tr>').join("");
 document.getElementById("adminCount").textContent="Нийт "+rows.length+" ачаа";
}
function filterAdminRows(){const q=document.getElementById("adminSearch").value.toLowerCase().trim(),bid=document.getElementById("adminBranchFilter").value,st=document.getElementById("adminStatusFilter").value;renderAdminRows(adminParcels.filter(p=>(!bid||String(p.branch_id||"")===bid)&&(!st||classifyStatus(p.parcel_status)===st)&&[p.tracking_code,p.customer_name,p.name,p.customer_phone,p.phone].some(v=>String(v||"").toLowerCase().includes(q))))}
async function loadBranches(){const {data,error}=await db.from("branches").select("*").order("name");if(error){showMessage("adminNotice","Салбарын хүснэгт үүсгээгүй байна. SQL зааврыг README-д нэмсэн.");return}adminBranches=data||[];const opts='<option value="">Салбар сонгох</option>'+adminBranches.map(b=>'<option value="'+escapeHTML(b.id)+'">'+escapeHTML(b.name)+'</option>').join("");document.getElementById("editBranch").innerHTML=opts;document.getElementById("adminBranchFilter").innerHTML='<option value="">Бүх салбар</option>'+adminBranches.map(b=>'<option value="'+escapeHTML(b.id)+'">'+escapeHTML(b.name)+'</option>').join("");document.getElementById("branchList").innerHTML=adminBranches.map(b=>'<div style="padding:8px;border-bottom:1px solid #eee">'+escapeHTML(b.name)+' — '+escapeHTML(b.address||"Хаяггүй")+' <button onclick="renameBranch(\''+String(b.id)+'\')" class="edit-btn">Нэр/мэдээлэл засах</button> <button onclick="removeBranch(\''+String(b.id)+'\')" class="delete-btn">Устгах</button></div>').join("")||"Салбар нэмээгүй байна."}
async function addBranch(){const name=document.getElementById("newBranchName").value.trim();if(!name){showMessage("adminNotice","Салбарын нэр оруулна уу.");return}const {error}=await db.from("branches").insert({name,address:document.getElementById("newBranchAddress").value.trim(),phone:document.getElementById("newBranchPhone").value.trim()});if(error){showMessage("adminNotice","Салбар нэмэх алдаа: "+error.message);return}document.getElementById("newBranchName").value="";document.getElementById("newBranchAddress").value="";document.getElementById("newBranchPhone").value="";await loadBranches();showMessage("adminNotice","Салбар нэмлээ.")}
async function renameBranch(id){const b=adminBranches.find(x=>String(x.id)===String(id));if(!b)return;const name=prompt("Салбарын нэр:",b.name);if(name===null||!name.trim())return;const address=prompt("Салбарын хаягийг гараар оруулна уу:",b.address||"");if(address===null)return;const phone=prompt("Салбарын утас:",b.phone||"");if(phone===null)return;const {error}=await db.from("branches").update({name:name.trim(),address,phone}).eq("id",id);if(error){showMessage("adminNotice","Засах алдаа: "+error.message);return}await loadBranches()}
async function removeBranch(id){const b=adminBranches.find(x=>String(x.id)===String(id));if(!b||!confirm(b.name+" салбарыг устгах уу? Салбарын ачаа branch_id-гүй болно."))return;const {error}=await db.from("branches").delete().eq("id",id);if(error){showMessage("adminNotice","Устгах алдаа: "+error.message);return}await loadBranches();await loadAdminParcels()}
function newParcelForm(){editingParcelId=null;document.getElementById("editorTitle").textContent="Шинэ ачаа бүртгэх";["editTracking","editName","editPhone","editPieces","editWeight","editVolume","editPrice","editDescription"].forEach(id=>document.getElementById(id).value="");document.getElementById("editPieces").value="1";document.getElementById("editStatus").value="ereen";document.getElementById("editBranch").value="";document.getElementById("parcelEditor").style.display="block";document.getElementById("parcelEditor").scrollIntoView({behavior:"smooth"})}
function editParcel(id){const p=adminParcels.find(x=>String(x.id)===String(id));if(!p)return;editingParcelId=p.id;document.getElementById("editorTitle").textContent="Ачаа засах";document.getElementById("editTracking").value=p.tracking_code||"";document.getElementById("editName").value=p.customer_name||p.name||"";document.getElementById("editPhone").value=p.customer_phone||p.phone||"";document.getElementById("editPieces").value=p.piece_number??1;document.getElementById("editWeight").value=p.weight_kg??"";document.getElementById("editVolume").value=p.volume_m3??"";document.getElementById("editPrice").value=p.price_mnt??"";document.getElementById("editStatus").value=classifyStatus(p.parcel_status);document.getElementById("editDescription").value=p.description||"";document.getElementById("editBranch").value=p.branch_id||"";document.getElementById("parcelEditor").style.display="block";document.getElementById("parcelEditor").scrollIntoView({behavior:"smooth"})}
function cancelParcelForm(){document.getElementById("parcelEditor").style.display="none";editingParcelId=null}
async function saveParcel(){
 const tracking=document.getElementById("editTracking").value.trim(),phone=cleanPhone(document.getElementById("editPhone").value);
 if(!tracking||phone.length!==8){showMessage("adminNotice","Трак код болон 8 оронтой утас заавал оруулна.");return}
 const payload={tracking_code:tracking,customer_name:document.getElementById("editName").value.trim(),customer_phone:phone,piece_number:Number(document.getElementById("editPieces").value||1),weight_kg:Number(document.getElementById("editWeight").value||0),volume_m3:Number(document.getElementById("editVolume").value||0),price_mnt:Number(document.getElementById("editPrice").value||((Number(document.getElementById("editWeight").value||0)*siteSettings.kg_price)+(Number(document.getElementById("editVolume").value||0)*siteSettings.m3_price*500))),parcel_status:document.getElementById("editStatus").value,branch_id:document.getElementById("editBranch").value||null,description:document.getElementById("editDescription").value.trim()};
 showMessage("adminNotice","Хадгалж байна...");
 let result=editingParcelId?await db.from("parcels").update(payload).eq("id",editingParcelId):await db.from("parcels").insert(payload);
 if(result.error){showMessage("adminNotice","Хадгалах алдаа: "+result.error.message);return}
 cancelParcelForm();await loadAdminParcels();showMessage("adminNotice","Амжилттай хадгаллаа.");
}
async async async function handoverParcel(id){
 const p=adminParcels.find(x=>String(x.id)===String(id));if(!p)return;
 if(!confirm((p.tracking_code||"Ачаа")+"-г хүлээлгэн өгч, төлбөр бүртгэх үү?"))return;
 const staff=prompt("Хүлээлгэн өгсөн ажилтны нэр:");if(!staff||!staff.trim())return;
 const method=prompt("Төлбөрийн хэлбэр:\\n1 = Бэлэн\\n2 = Шилжүүлэг","1");if(method!=="1"&&method!=="2"){alert("1 эсвэл 2 сонгоно уу.");return}
 const {error}=await db.from("parcels").update({parcel_status:"received",paid_at:new Date().toISOString(),payment_method:method==="1"?"cash":"transfer",received_by:staff.trim()}).eq("id",id);
 if(error){showMessage("adminNotice","Хүлээлгэн өгөх алдаа. SQL баганууд нэмэгдсэн эсэхийг шалгана уу: "+error.message);return}
 await loadAdminParcels();showMessage("adminNotice","Хүлээлгэн өгч, төлбөр бүртгэлээ.");
}

function deleteParcel(id){const p=adminParcels.find(x=>String(x.id)===String(id));if(!p||!confirm((p.tracking_code||"Энэ ачаа")+" устгах уу?"))return;const {error}=await db.from("parcels").delete().eq("id",id);if(error){showMessage("adminNotice","Устгах алдаа: "+error.message);return}await loadAdminParcels();showMessage("adminNotice","Ачааг устгалаа.")}

document.getElementById("customerPhone").addEventListener("keydown",e=>{if(e.key==="Enter")customerLogin()});
if(location.hash==="#admin"){
 document.getElementById("publicPage").style.display="none";document.getElementById("pageFooter").style.display="none";
 document.getElementById("adminLogin").classList.remove("hidden");
}
