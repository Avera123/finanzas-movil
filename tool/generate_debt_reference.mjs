import {pathToFileURL} from 'node:url';
if (!process.argv[2]) throw new Error('Pass the local path of finance.js from pinned backend commit 7a8380f999850900e4ed8cb5802cf92964bf16dd');
const {schedule, cuotaForN, impliedRate} = await import(pathToFileURL(process.argv[2]));
import {writeFileSync} from 'node:fs';
const base = {acc:[],exp:[],usd:1000,rate:4,inc:{},living:500,cats:[],meths:['Transferencia']};
const debt = {id:'d',name:'Fixture',total:5000,rate:0,cuota:1667,startM:'2026-11',mode:'fixed'};
const cases = [];
for(const item of [
  {name:'zero',debt},
  {name:'interest',debt:{...debt,total:1000,rate:2,cuota:100}},
  {name:'insufficient',debt:{...debt,rate:10,cuota:1}},
  {name:'open',debt:{...debt,total:0,mode:'open',cuota:50}},
  {name:'deferred-interest',debt:{...debt,total:1000,rate:2,cuota:100,resumeM:'2027-02'}},
  {name:'fast',debt:{...debt,mode:'fast'}},
  {name:'paid',debt,data:{...base,exp:[{id:'e',debtId:'d',m:'2026-11',amt:1667,paid:true}]}},
  {name:'past-start',debt:{...debt,startM:'2026-09',rate:2}},
]) { const data = item.data || structuredClone(base); cases.push({name:item.name,data,debt:item.debt,now:'2026-11',expected:schedule(data,item.debt,'2026-11')}); }
const formulas=[{balance:5000,rate:0,months:3},{balance:1000,rate:2,months:12}].map(v=>({...v,expected:cuotaForN(v.balance,v.rate,v.months)}));
const implied=[{total:1000,payment:100,months:12},{total:1200,payment:100,months:12},{total:1500,payment:100,months:12}].map(v=>({...v,expected:impliedRate(v.total,v.payment,v.months)}));
writeFileSync('test/fixtures/debt_reference.json',JSON.stringify({source:'7a8380f999850900e4ed8cb5802cf92964bf16dd/src/finance.js',cases,formulas,implied},null,2)+'\n');
console.log(`Generated ${cases.length} schedules and ${formulas.length+implied.length} formula cases from pinned JS.`);
