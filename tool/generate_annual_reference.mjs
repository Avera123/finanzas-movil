import {pathToFileURL} from 'node:url';
import {writeFileSync} from 'node:fs';
if (!process.argv[2]) throw new Error('Pass pinned finance.js: 7a8380f999850900e4ed8cb5802cf92964bf16dd');
const {monthly} = await import(pathToFileURL(process.argv[2]));
const data = {version:1, usd:1000, rate:4, inc:{'2026-12':0}, acc:[], living:600,
  debts:[{id:'d',startM:'2026-10',total:2000,rate:2,mode:'fixed',cuota:400}],
  loans:[{id:'l',total:900,lentOn:'2026-10-15',dueOn:'2026-12-10',acc:'a'},
    {id:'late',total:300,lentOn:'2026-09-01',dueOn:'2026-10-01',acc:null}],
  loanPay:[{loanId:'l',on:'2026-11-02',amt:100},{loanId:'late',on:'2026-10-02',amt:50}],
  savings:[{id:'s',start:200,startM:'2026-10',endM:'2027-12',members:[{id:'me',mine:true,monthly:100},{id:'other',mine:false,monthly:200}]}],
  contrib:[{savingId:'s',memberId:'me',m:'2026-10',amt:100,done:false},
    {savingId:'s',memberId:'me',m:'2026-11',amt:100,done:true},
    {savingId:'s',memberId:'other',m:'2026-11',amt:200,done:true},
    {savingId:'s',memberId:'me',m:'2026-12',amt:100,done:false}],
  exp:[{m:'2026-10',amt:400,debtId:'d',cat:'Deuda',name:'Cuota',paid:true},
    {m:'2026-11',amt:400,debtId:'d',cat:'Deuda',name:'Cuota',paid:false},
    {m:'2026-12',amt:400,debtId:'d',cat:'Deuda',name:'Cuota',paid:false},
    {m:'2026-10',amt:50,investId:'i',cat:'Inversión',name:'Fondo',paid:false},
    {m:'2026-11',amt:80,investId:'i',cat:'Inversión',name:'Fondo',paid:true},
    {m:'2026-12',amt:90,investId:'i',cat:'Inversión',name:'Fondo',paid:false},
    {m:'2026-10',amt:500,cat:'Casa',name:'Mercado',paid:true},
    {m:'2026-12',amt:200,cat:'Casa',name:'Mercado',paid:false}]};
const now='2026-11';
const cases=['2026-09','2026-10','2026-11','2026-12','2027-01','2027-12'].map(month=>({month,expected:monthly(data,month,now)}));
writeFileSync('test/fixtures/annual_reference.json',JSON.stringify({source:'7a8380f999850900e4ed8cb5802cf92964bf16dd/src/finance.js',data,now,cases},null,2)+'\n');
