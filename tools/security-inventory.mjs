#!/usr/bin/env node
// Static review aid, NOT execution/coverage proof. Reads production source only.
import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
const repo=path.resolve(import.meta.dirname,'..');
const destination=process.argv[2];
if(!destination)throw new Error('Usage: node tools/security-inventory.mjs NEW_OUTPUT_JSON');
if(fs.existsSync(destination))throw new Error('Destination exists');
const normal=JSON.parse(fs.readFileSync(path.join(repo,'tools/repro/normal-build-functions.json')));
const runtime=new Map(normal.map(m=>[m.module,new Set(m.normalBuildFunctions)]));
const records=[];
function visit(dir){for(const e of fs.readdirSync(dir,{withFileTypes:true})){const file=path.join(dir,e.name);if(e.isDirectory()){visit(file);continue;}if(!e.name.endsWith('.move'))continue;
  const source=fs.readFileSync(file,'utf8');
  // Blank comments/quoted contents while retaining character offsets and newlines.
  const lexical=source.replace(/\/\*[\s\S]*?\*\/|\/\/[^\n]*|"(?:\\.|[^"\\])*"/g,s=>s.replace(/[^\n]/g,' '));
  const moduleName=/\bmodule\s+\w+::(\w+)/.exec(lexical)?.[1];
  const names=runtime.get(moduleName);if(!names)continue;
  const regex=/\b(public(?:\s*\(\s*friend\s*\))?\s+)(?:entry\s+)?fun\s+(\w+)([^\{]*)\{/g;
  for(const m of lexical.matchAll(regex)){
    const name=m[2];if(!names.has(name))continue;
    const start=m.index,open=start+m[0].length-1;let depth=1,end=open+1;
    for(;end<lexical.length&&depth;end++){if(lexical[end]==='{')depth++;if(lexical[end]==='}')depth--;}
    if(depth)throw new Error('Unbalanced function body '+file+':'+name);
    const header=source.slice(start,open),body=source.slice(open+1,end-1),cleanBody=lexical.slice(open+1,end-1);
    const parameterStart=header.indexOf('(',header.indexOf('fun '));let parameterEnd=parameterStart+1,parameterDepth=1;
    for(;parameterEnd<header.length&&parameterDepth;parameterEnd++){if(header[parameterEnd]==='(')parameterDepth++;if(header[parameterEnd]===')')parameterDepth--;}
    const parameters=header.slice(parameterStart,parameterEnd);
    const capabilities=[...parameters.matchAll(/\b(PoolFactoryAdminCap|RewardManagerAdminCap|PartnerAdminCap|PartnerCap|TurbosPositionNFT)\b/g)].map(x=>x[1]);
    const roles=[...cleanBody.matchAll(/\bcheck_(clmm_manager|reward_manager|claim_protocol_fee_manager|pause_pool_manager)_role\s*\(/g)].map(x=>x[1]);
    const assertions=[...body.matchAll(/assert!\(([\s\S]*?)\);/g)].map(x=>x[1].replace(/\s+/g,' ').trim());
    records.push({file:path.relative(repo,file),module:moduleName,function:name,line:source.slice(0,start).split('\n').length,visibility:m[1].includes('friend')?'friend':'public',capabilityParameters:[...new Set(capabilities)],aclChecks:[...new Set(roles)],versionCheck:/\bcheck_version\s*\(/.test(cleanBody),retiredAbortZero:/^\s*abort\s*\(\s*0\s*\)\s*;?\s*$/.test(cleanBody),assertions,reviewStatus:'Inventory only; map to positive/negative execution tests separately'});
  }
}}
visit(path.join(repo,'sources'));
const result={generatedAt:new Date().toISOString(),scope:'Public/friend normal-build functions only; source inspection, not coverage or proof of safe access control',sourceAnchors:records.length,functions:records};
fs.writeFileSync(destination,JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({functions:records.length,aclGated:records.filter(r=>r.aclChecks.length).length,capabilityParameters:records.filter(r=>r.capabilityParameters.length).length,retiredZeroAbort:records.filter(r=>r.retiredAbortZero).length,output:destination}));
