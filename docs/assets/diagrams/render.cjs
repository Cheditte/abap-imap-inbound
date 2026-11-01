// Dependency-free SVG diagrams. Run: node docs/assets/diagrams/render.cjs
// Explicit line breaks and plain SVG text avoid HTML-label clipping.
const fs = require('node:fs');
const path = require('node:path');
const esc = s => s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
const card = (x,y,w,h,title,body=[]) => {
  const headings=Array.isArray(title)?title:[title];
  const total=headings.length*28+body.length*25+(body.length?7:0);
  let baseline=y+(h-total)/2+23;
  let out=`<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="12" fill="#edf4fc" stroke="#6e94bc" stroke-width="2"/>`;
  for(const line of headings){out+=`<text x="${x+w/2}" y="${baseline}" font-size="24" font-weight="700">${esc(line)}</text>`;baseline+=28;}
  baseline+=7;
  for(const line of body){out+=`<text x="${x+w/2}" y="${baseline}" font-size="20" fill="#405b78">${esc(line)}</text>`;baseline+=25;}
  return out;
};
const arrow = d => `<path d="${d}" fill="none" stroke="#456b96" stroke-width="2.5" marker-end="url(#arrow)"/>`;
function svg(title,height,content){return `<svg xmlns="http://www.w3.org/2000/svg" width="720" height="${height}" viewBox="0 0 720 ${height}" role="img" aria-labelledby="title"><title id="title">${esc(title)}</title><defs><marker id="arrow" markerWidth="9" markerHeight="9" refX="8" refY="4" orient="auto"><path d="M0 0 L8 4 L0 8 Z" fill="#456b96"/></marker></defs><rect width="720" height="${height}" fill="#fff"/><g font-family="Arial, Helvetica, sans-serif" text-anchor="middle" fill="#183c68">${content}</g></svg>\n`;}
function chain(title,cards){
  const h=116,gap=44,height=40+cards.length*h+(cards.length-1)*gap;
  let body='';
  cards.forEach((c,i)=>{const y=20+i*(h+gap);body+=card(55,y,610,h,c[0],c[1]);if(i<cards.length-1)body+=arrow(`M360 ${y+h} V${y+h+gap-6}`);});
  return svg(title,height,body);
}
const content={
  tr:{
    usage:['Posta sunucusu',['E-postalar ve ekler'],'E-postaları görün',['ve okuyun'],'Ekleri işleyin',['Kendi ABAP kodunuzla']],
    setup:[['1. Posta sunucusu',['Hesap ve IMAP erişimi','Okunacak ve hedef klasör']],[["2. SAP'nin kurulu olduğu",'makine'],['PowerShell, curl ve proje dosyaları']],['3. SAP ERP',['Programlar ve posta ayarları','İlk deneme']]],
    'mail-flow':[['Okunacak posta klasörü',['Varsayılan: INBOX','İsterseniz başka klasör seçin']],['SAP içinde işleme',['E-postayı ve eklerini alın']],['Başarıyla işlenen iletiler',['Hedef: aynı hesapta farklı bir klasör','SAP-Processed adı zorunlu değildir']]],
    'host-prep':[["SAP'nin çalıştığı makine",['Windows veya Linux']],['Gerekli araçlar ve dosyalar',['PowerShell + curl','Projenin sunucu dosyaları']],['Korumalı çalışma klasörü',['E-postalar, ekler ve bağlantı ayarları']]],
    'sap-steps':[['3.1. Programı oluşturun',['SE38 → ZIMAP_INSTALL']],['3.2. Kurulumu çalıştırın',['ZIMAP_INSTALL']],['3.3. Postayı tanımlayın',['ZIMAP_CONFIG']]]
  },
  en:{
    usage:['Mail server',['Emails and attachments'],'View the emails',['and read them'],'Process attachments',['With your ABAP code']],
    setup:[['1. Mail server',['Account and IMAP access','Source and destination folders']],[['2. Machine','running SAP'],['PowerShell, curl and project files']],['3. SAP ERP',['Programs and mailbox settings','First trial']]],
    'mail-flow':[['Source mail folder',['Default: INBOX','Or select another folder']],['Processing in SAP',['Retrieve messages and attachments']],['Destination for successful mail',['A different folder in the same account','The name SAP-Processed is optional']]],
    'host-prep':[['Machine running SAP',['Windows or Linux']],['Required tools and files',['PowerShell + curl','Project server files']],['Protected working folder',['Emails, attachments and connection settings']]],
    'sap-steps':[['3.1. Create the program',['SE38 → ZIMAP_INSTALL']],['3.2. Run the installation',['ZIMAP_INSTALL']],['3.3. Configure the mailbox',['ZIMAP_CONFIG']]]
  }
};
for(const [lang,data] of Object.entries(content)){
  for(const kind of ['setup','mail-flow','host-prep','sap-steps']){
    fs.writeFileSync(path.join(__dirname,`${kind}-${lang}.svg`),chain(`${kind} (${lang})`,data[kind]));
  }
  const u=data.usage;
  const body=card(185,20,350,92,u[0],u[1])+arrow('M360 112 V159')+card(260,165,200,62,'SAP')+
    arrow('M360 227 V255 H185 V294')+arrow('M360 227 V255 H535 V294')+
    card(30,300,310,106,u[2],u[3])+card(380,300,310,106,u[4],u[5]);
  fs.writeFileSync(path.join(__dirname,`usage-${lang}.svg`),svg(`Email and attachment use (${lang})`,426,body));
}
console.log('Wrote 10 SVG diagrams with explicit text lines.');
