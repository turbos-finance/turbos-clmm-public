#!/usr/bin/env node
// Review aid only. Executing an assertion line is NOT proof of both outcomes.
import fs from 'node:fs';import path from 'node:path';import {createHash} from 'node:crypto';
const repo=path.resolve(import.meta.dirname,'..');
const [evidenceArgument,outputArgument]=process.argv.slice(2);
if(!outputArgument)throw new Error('Usage: node tools/security-guard-inventory.mjs PASSING_FULL_EVIDENCE NEW_JSON');
const evidence=path.resolve(evidenceArgument),output=path.resolve(outputArgument);
if(fs.existsSync(output))throw new Error('Refusing overwrite');
const run=JSON.parse(fs.readFileSync(path.join(evidence,'result.json')));
if(run.fullSuite.failed||!run.fullSuiteTraced||run.traceExclusions.length)throw new Error('Full passing evidence required');
const normal=JSON.parse(fs.readFileSync(path.join(evidence,'normal-build-functions.json')));
const coverage=JSON.parse(fs.readFileSync(path.join(evidence,'production-coverage.json')));
const lcov=fs.readFileSync(path.join(evidence,'production-lcov.info'),'utf8').split('end_of_record').map(s=>s.trim().split('\n'));
const functions=[];
for(const module of normal){
 const file=path.join(repo,module.source),source=fs.readFileSync(file,'utf8');
 if(createHash('sha256').update(source).digest('hex')!==module.normalSourceSha256)throw new Error('Production source drift');
 const lexical=source.replace(/\/\*[\s\S]*?\*\/|\/\/[^\n]*|"(?:\\.|[^"\\])*"/g,s=>s.replace(/[^\n]/g,' '));
 const wanted=new Set(module.normalBuildFunctions),found=new Set();
 const record=lcov.find(r=>r.some(l=>l==='SF:'+module.source||(l.startsWith('SF:')&&l.endsWith('/'+module.source))));
 if(!record)throw new Error('Missing LCOV '+module.source);
 const hits=new Map(record.filter(l=>l.startsWith('DA:')).map(l=>l.slice(3).split(',').map(Number)));
 const meta=coverage.files.find(f=>f.module===module.module);if(!meta)throw new Error('Missing coverage module');
 const regex=/\b(?:(public(?:\s*\(\s*friend\s*\))?)\s+)?(?:entry\s+)?fun\s+(\w+)[^{]*\{/g;
 for(const match of lexical.matchAll(regex)){
  const name=match[2];if(!wanted.has(name))continue;
  if(found.has(name))throw new Error('Duplicate function '+name);found.add(name);
  const open=match.index+match[0].length-1;let end=open+1,depth=1;
  for(;end<lexical.length&&depth;end++){if(lexical[end]==='{')depth++;if(lexical[end]==='}')depth--;}
  if(depth)throw new Error('Unbalanced function');
  const header=source.slice(match.index,open),body=lexical.slice(open+1,end-1);
  const line=offset=>source.slice(0,offset).split('\n').length;
  const guards=[];
  for(const assertion of body.matchAll(/\bassert!\s*\(/g)){
   const begin=open+1+assertion.index;let stop=begin+assertion[0].length,nesting=1;
   for(;stop<end&&nesting;stop++){if(lexical[stop]==='(')nesting++;if(lexical[stop]===')')nesting--;}
   if(nesting)throw new Error('Unbalanced assertion');
   const at=line(begin);guards.push({kind:'assertion',line:at,expression:source.slice(begin,stop).replace(/\s+/g,' ').trim(),lineExecuted:(hits.get(at)||0)>0,positiveAndNegativeWitnesses:'Not inferred; review against named tests'});
  }
  for(const check of body.matchAll(/\b(?:\w+::)?check_(?:version|clmm_manager_role|reward_manager_role|claim_protocol_fee_manager_role|pause_pool_manager_role)\s*\(/g)){
   const at=line(open+1+check.index);guards.push({kind:'authorization/version call',line:at,call:check[0].slice(0,-1).trim(),lineExecuted:(hits.get(at)||0)>0,positiveAndNegativeWitnesses:'Not inferred; see executed witness mapping or explicit version fixture'});
  }
  const retiredAbortZero=/^\s*abort\s*\(\s*0\s*\)\s*;?\s*$/.test(body);
  if(!retiredAbortZero)for(const stop of body.matchAll(/\babort\s*(?:\([^;\n]*?\)|\w+)/g)){
   const offset=open+1+stop.index,at=line(offset);
   const lineStart=source.lastIndexOf('\n',offset)+1;
   guards.push({kind:'explicit abort',line:at,expression:source.slice(lineStart,offset+stop[0].length).trim(),lineExecuted:(hits.get(at)||0)>0,positiveAndNegativeWitnesses:'Not inferred; inspect the surrounding conditional and named rejection test'});
  }
  const paramsStart=header.indexOf('(',header.indexOf('fun '));let paramsEnd=paramsStart+1,pdepth=1;
  for(;paramsEnd<header.length&&pdepth;paramsEnd++){if(header[paramsEnd]==='(')pdepth++;if(header[paramsEnd]===')')pdepth--;}
  const params=header.slice(paramsStart,paramsEnd);
  const capabilities=[...params.matchAll(/\b(?:PoolFactoryAdminCap|RewardManagerAdminCap|PartnerAdminCap|PartnerCap|TurbosPositionNFT|TurbosPositionBurnNFT|FlashSwapReceiptPartner|FlashSwapReceipt)\b/g)].map(m=>m[0]);
  functions.push({module:module.module,function:name,file:module.source,startLine:line(match.index),endLine:line(end),visibility:match[1]?.includes('friend')?'friend':match[1]?'public':'private',capabilityInputs:[...new Set(capabilities)],retiredAbortZero,lifecycleInitializer:name==='init',functionExecuted:!meta.uncoveredFunctions.includes(name),uncoveredLines:meta.uncoveredLines.filter(n=>n>=line(match.index)&&n<=line(end)),guards,reviewStatus:'Inventory only; not automatic requirement closure'});
 }
 if(found.size!==wanted.size)throw new Error('Function inventory mismatch '+module.module+': '+[...wanted].filter(n=>!found.has(n)).join(','));
}
const expected=normal.reduce((n,m)=>n+m.normalBuildFunctions.length,0);
if(functions.length!==expected||expected!==coverage.totals.functionsFound)throw new Error('Normal function count mismatch');
const outputData={generatedAt:new Date().toISOString(),sourceTreeSha256:run.sourceTreeSha256,scope:'Every normal-build production function, source assertions, explicit non-retired abort statements and direct role/version calls. Static inventory plus line-execution observations only; not semantic proof, exhaustive invariant discovery, or positive/negative closure.',summary:{productionFunctions:functions.length,assertions:functions.reduce((n,f)=>n+f.guards.filter(g=>g.kind==='assertion').length,0),directRoleVersionCalls:functions.reduce((n,f)=>n+f.guards.filter(g=>g.kind==='authorization/version call').length,0),explicitNonRetiredAborts:functions.reduce((n,f)=>n+f.guards.filter(g=>g.kind==='explicit abort').length,0),capabilityInputFunctions:functions.filter(f=>f.capabilityInputs.length).length,retiredAbortZeroFunctions:functions.filter(f=>f.retiredAbortZero).length,lifecycleInitializers:functions.filter(f=>f.lifecycleInitializer).length},functions};
fs.writeFileSync(output,JSON.stringify(outputData,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify(outputData.summary));
