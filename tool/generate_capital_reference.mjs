import {pathToFileURL} from 'node:url';
import {writeFileSync} from 'node:fs';
if(!process.argv[2]) throw new Error('Pass finance.js from pinned commit 7a8380f999850900e4ed8cb5802cf92964bf16dd');
const f=await import(pathToFileURL(process.argv[2]));
const base={usd:1000,rate:4,inc:{'2026-12':2000},acc:[],exp:[],cats:[],meths:['Transferencia']};
const inv={id:'i',name:'Fixture',mode:'fixed',value:100,months:4,startM:'2026-11',rate:12};
const investmentCases=[
  {name:'fixed',data:base,inv},
  {name:'percent',data:base,inv:{...inv,mode:'percent',value:10}},
  {name:'paid',data:{...base,exp:[{m:'2026-11',amt:80,paid:true,investId:'i'}]},inv},
  {name:'deferred',data:base,inv:{...inv,resumeM:'2027-02'}},
].map(c=>{const rows=f.planInvestment(c.data,c.inv,'2026-11');const status=f.investStatus({...c.data,exp:[...c.data.exp,...rows.map(r=>({...r,paid:false,investId:'i'}))]},c.inv,'2026-11');return {...c,now:'2026-11',expectedRows:rows,expectedPath:status.path};});
const fund={id:'s',name:'Fixture fund',start:500,startM:'2026-11',target:5000,isOwner:true,acc:'b',members:[{id:'me',name:'Me',email:'me@example.test',mine:true,monthly:100,acc:'a'},{id:'other',name:'Other',email:'other@example.test',mine:false,monthly:150,acc:null}]};
const data={acc:[{id:'a',name:'Source',type:'Ahorros',bal:1000},{id:'b',name:'Fund',type:'Ahorros',bal:500}],savings:[fund],contrib:[{id:'c',savingId:'s',memberId:'me',m:'2026-11',amt:100,done:false,extra:false}]};
const contributionCases=[{name:'different-accounts',data},{name:'same-account',data:{...data,savings:[{...fund,acc:'a'}]}}].map(c=>{const expected=structuredClone(c.data);f.setContribution(expected,'c',true);f.setContribution(expected,'c',true);return {...c,expected};});
const reconcileInput={...data,contrib:[{id:'foreign',savingId:'s',memberId:'other',m:'2026-11',amt:150,done:true,extra:false}]};
const reconcileExpected=structuredClone(reconcileInput);f.reconcileShared(reconcileExpected);f.reconcileShared(reconcileExpected);
const goals=[{target:1200,months:12,annual:0},{target:5000,months:24,annual:12}].map(c=>({...c,expected:f.cuotaForGoal(c.target,c.months,c.annual)}));
writeFileSync('test/fixtures/capital_reference.json',JSON.stringify({source:'7a8380f999850900e4ed8cb5802cf92964bf16dd/src/finance.js',investmentCases,contributionCases,reconcileInput,reconcileExpected,goals},null,2)+'\n');
console.log('Generated investment plans, goals, contribution and reconciliation fixtures from pinned JS.');
