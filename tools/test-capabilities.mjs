#!/usr/bin/env node
// Compiler-negative cases; no object transfers, wallet access or mainnet execution.
import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {execFileSync,spawnSync} from 'node:child_process';
const repo=path.resolve(import.meta.dirname,'..');
const [baselineArgument,destination]=process.argv.slice(2);
if(!baselineArgument||!destination)throw new Error('Usage: SUI_BINARY=/path/to/sui node tools/test-capabilities.mjs PASSING_SECURITY_RUN_ROOT NEW_DIRECTORY');
const baseline=path.resolve(baselineArgument),root=path.resolve(destination);
if(fs.existsSync(root))throw new Error('Destination exists; refusing to overwrite');
const binary=process.env.SUI_BINARY||'sui';
if(!execFileSync(binary,['--version'],{encoding:'utf8'}).includes('1.66.2-a9a6825eaf62'))throw new Error('Use the recorded Sui CLI');
const result=JSON.parse(fs.readFileSync(path.join(baseline,'evidence/result.json')));
if(result.fullSuite.status!=='OK'||result.fullSuite.failed!==0||!result.normalBytecodeReference.allMatch)throw new Error('Run the security baseline first');
const hashes=JSON.parse(fs.readFileSync(path.join(baseline,'evidence/source-hashes.json')));
const sha=b=>createHash('sha256').update(b).digest('hex');
for(const item of hashes)if(sha(fs.readFileSync(path.join(repo,item.file)))!==item.sha256)throw new Error('Baseline source drift');
const definitions=[
  ['forge_pool_factory_admin','PoolFactoryAdminCap'],
  ['forge_reward_admin','RewardManagerAdminCap'],
  ['forge_partner_admin','PartnerAdminCap'],
  ['forge_partner_cap','PartnerCap'],
  ['drop_flash_receipt','FlashSwapReceipt'],
];
fs.mkdirSync(root,{recursive:true});
const env={...process.env,SUI_CONFIG_DIR:path.join(baseline,'isolated-client'),RUST_MIN_STACK:'536870912'};
const results=[];
for(const [key,type] of definitions){
  const dir=path.join(root,key);fs.mkdirSync(dir);
  for(const part of ['sources','tests','Move.toml','Published.toml'])if(fs.existsSync(path.join(baseline,'package',part)))fs.cpSync(path.join(baseline,'package',part),path.join(dir,part),{recursive:true});
  const fixture=fs.readFileSync(path.join(repo,'tools/compile-fail',key+'.move.fail'));
  fs.writeFileSync(path.join(dir,'tests',key+'.move'),fixture);
  const args=['move','test','--path',dir,'--build-env','mainnet','--no-lint','--silence-warnings','--threads','1'];
  const run=spawnSync(binary,args,{env,encoding:'utf8',timeout:120000,maxBuffer:20*1024**2});
  const text=(run.stdout||'')+(run.stderr||'');
  fs.writeFileSync(path.join(root,key+'.log'),text);
  // Match both the forbidden type and the specific compiler reason, not arbitrary failure.
  const reason=key==='drop_flash_receipt'?/Invalid usage of undroppable value|does not have.*drop|does not have the.*drop|without the.*drop|ability.*drop/is:/Invalid struct instantiation|Invalid construction|can only be constructed|cannot be constructed|only.*defining module/is;
  const accepted=run.status!==null&&run.status!==0&&!run.error&&text.includes(type)&&reason.test(text)&&!text.includes('Running Move unit tests');
  results.push({case:key,type,fixtureSha256:sha(fixture),exitCode:run.status,expectedCompilerRejection:accepted});
  if(!accepted){console.log(text.slice(-6000));throw new Error('Unexpected compiler outcome: '+key);}
}
const output={generatedAt:new Date().toISOString(),scope:'Compiler-negative capability construction and receipt dropping only; not runtime auth execution or on-chain custody verification',baselineSourceTreeSha256:result.sourceTreeSha256,allExpectedRejections:true,results};
fs.writeFileSync(path.join(root,'result.json'),JSON.stringify(output,null,2)+'\n');
console.log(JSON.stringify(output,null,2));
