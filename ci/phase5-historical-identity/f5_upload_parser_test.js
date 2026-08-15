const ExcelJS=require('../../app/node_modules/exceljs');
const f5=require('../../app/f5-historical-upload');
(async()=>{
 const wb=new ExcelJS.Workbook(),ws=wb.addWorksheet('Hoja 1');
 ws.addRow(f5.HEADERS);
 const row={};for(const h of f5.HEADERS)row[h]='';
 Object.assign(row,{'F. creación de paciente':'2024-03-01','ID del paciente':'SRC-123','Teléfono':'+51 999 111 222','Nombres':'Ána María','Apellidos':'Pérez','Email':'ANA@EXAMPLE.COM','N° documento':'12345678','Sexo':'F','Fecha de nacimiento':'1990-02-03','Dirección':'Av. Uno 123, Pueblo Libre, Lima, Lima','Ocupación':'Arquitecta','Etiquetas':'HIFU, DETOX','Última cita':'2026-01-15','Último presupuesto':'300/500'});
 ws.addRow(f5.HEADERS.map(h=>row[h]));
 const buf=Buffer.from(await wb.xlsx.writeBuffer()),out=await f5.parseAndNormalize(buf),r=out.rows[0];
 function ok(c,m){if(!c)throw new Error(m)}
 ok(out.rows.length===1,'one row expected');ok(r.phone_key==='999111222'&&r.phone_type==='PERU_9','phone normalization');ok(r.document_key==='12345678'&&r.document_type==='DNI8','DNI normalization');ok(r.email_key==='ana@example.com','email normalization');ok(r.name_key==='ANA MARIA PEREZ','name normalization');ok(r.district==='Pueblo Libre'&&r.province==='Lima'&&r.department==='Lima','address right parse');ok(r.birth_date==='1990-02-03'&&r.birth_quality==='VALID','DOB parse');ok(r.budget_num_a===300&&r.budget_num_b===500,'budget evidence parse');ok(/^[0-9a-f]{64}$/.test(r.row_content_hash)&&/^[0-9a-f]{64}$/.test(r.identity_seed_hash),'hashes');ok(r.raw_payload['Nombres']==='Ána María','raw evidence retained');
 const rerun=await f5.parseAndNormalize(buf);ok(rerun.sourceSha===out.sourceSha&&rerun.rows[0].row_content_hash===r.row_content_hash,'deterministic hashes');
 console.log('F5 XLSX parser test: PASS');
})().catch(e=>{console.error(e);process.exit(1)});
