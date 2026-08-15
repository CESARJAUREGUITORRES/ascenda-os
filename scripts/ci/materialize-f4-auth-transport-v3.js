'use strict';
const fs=require('fs');
function patch(path,from,to,label){let s=fs.readFileSync(path,'utf8');if(!s.includes(from))throw new Error('missing '+label);s=s.replace(from,to);fs.writeFileSync(path,s,'utf8');}
patch('ci/phase2-cartera/ui_contract.js',"['aos_cartera_gateway','aos_cartera_reconcile'","['/api/f4/cartera-read','aos_cartera_reconcile'",'legacy Cartera gateway marker');
patch('ci/phase1-sales-intelligence/ui_contract.js',"ok(page.includes('aos_sales_intelligence_gateway'), 'missing Sales Intelligence gateway');","ok(page.includes('/api/f4/sales-intelligence-read'), 'missing same-origin Sales Intelligence gateway');",'legacy Sales Intelligence gateway marker');
require('./materialize-f4-auth-transport-v2.js');
if(fs.existsSync(__filename))fs.unlinkSync(__filename);
