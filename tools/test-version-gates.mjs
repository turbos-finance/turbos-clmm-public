#!/usr/bin/env node
// Explicit test-only private-state fixture. The production repository is never modified.
import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {execFileSync,spawnSync} from 'node:child_process';
const repo=path.resolve(import.meta.dirname,'..');
const [baselineArgument,destination]=process.argv.slice(2);
if(!baselineArgument||!destination)throw new Error('Usage: SUI_BINARY=/path/to/sui node tools/test-version-gates.mjs PASSING_SECURITY_RUN_ROOT NEW_DIRECTORY');
const baseline=path.resolve(baselineArgument),root=path.resolve(destination);
if(fs.existsSync(root))throw new Error('Destination exists; refusing to overwrite');
const binary=process.env.SUI_BINARY||'sui';
if(!execFileSync(binary,['--version'],{encoding:'utf8'}).includes('1.66.2-a9a6825eaf62'))throw new Error('Use recorded CLI');
const result=JSON.parse(fs.readFileSync(path.join(baseline,'evidence/result.json')));
if(result.fullSuite.status!=='OK'||result.fullSuite.failed||!result.normalBytecodeReference.allMatch)throw new Error('Passing baseline required');
const sha=b=>createHash('sha256').update(b).digest('hex');
const hashes=JSON.parse(fs.readFileSync(path.join(baseline,'evidence/source-hashes.json')));
for(const h of hashes)if(sha(fs.readFileSync(path.join(repo,h.file)))!==h.sha256)throw new Error('Baseline drift');
fs.mkdirSync(root,{recursive:true});
const pkg=path.join(root,'package');fs.mkdirSync(pkg);
for(const part of ['sources','tests','Move.toml','Published.toml'])if(fs.existsSync(path.join(baseline,'package',part)))fs.cpSync(path.join(baseline,'package',part),path.join(pkg,part),{recursive:true});
const original=fs.readFileSync(path.join(pkg,'sources/pool.move'),'utf8');
if(original!==fs.readFileSync(path.join(repo,'sources/pool.move'),'utf8'))throw new Error('Original pool source mismatch');
const hook=fs.readFileSync(path.join(repo,'tools/version-fixtures/pool-hook.move.inc'),'utf8');
const end=original.lastIndexOf('}');if(end<0||original.includes('security_version_fixture'))throw new Error('Unexpected source shape');
const instrumented=original.slice(0,end)+hook+original.slice(end);
fs.writeFileSync(path.join(pkg,'sources/pool.move'),instrumented);
const fixture=fs.readFileSync(path.join(repo,'tools/version-fixtures/security_version_fixture_tests.move'));
fs.writeFileSync(path.join(pkg,'tests/security_version_fixture_tests.move'),fixture);
const env={...process.env,SUI_CONFIG_DIR:path.join(baseline,'isolated-client'),RUST_MIN_STACK:'536870912'};
function run(args,name){const r=spawnSync(binary,args,{env,encoding:'utf8',timeout:180000,maxBuffer:20*1024**2});const text=(r.stdout||'')+(r.stderr||'');fs.writeFileSync(path.join(root,name),text);if(r.status!==0||r.error){console.log(text.slice(-7000));throw new Error(name+' failed');}return text;}
const log=run(['move','test','--path',pkg,'--build-env','mainnet','--no-lint','--silence-warnings','--gas-limit','1000000000','--threads','1','security_version_fixture_tests'],'tests.log');
if(!/Test result: OK\. Total tests: 29; passed: 29; failed: 0/.test(log))throw new Error('Version fixture test count mismatch');
run(['move','build','--path',pkg,'--build-env','mainnet','--no-lint','--silence-warnings'],'normal-build-with-hook.log');
const modules=result.normalBytecodeReference.modules.map(m=>({...m,instrumentedNormalSha256:sha(fs.readFileSync(path.join(pkg,'build/TurbosCLMM/bytecode_modules',m.module+'.mv')))}));
if(modules.some(m=>m.instrumentedNormalSha256!==m.deployedSha256)||fs.readdirSync(path.join(pkg,'build/TurbosCLMM/bytecode_modules')).filter(f=>f.endsWith('.mv')).length!==modules.length)throw new Error('Test-only hook leaked into production bytecode');
for(const h of hashes){const expected=h.file==='sources/pool.move'?sha(Buffer.from(instrumented)):h.sha256;if(sha(fs.readFileSync(path.join(pkg,h.file)))!==expected||sha(fs.readFileSync(path.join(repo,h.file)))!==h.sha256)throw new Error('Unexpected source drift');}
const output={generatedAt:new Date().toISOString(),baselineSourceTreeSha256:result.sourceTreeSha256,tests:{total:29,passed:29,failed:0},testOnlyOverlay:{file:'sources/pool.move',originalSha256:sha(Buffer.from(original)),hookSha256:sha(Buffer.from(hook)),instrumentedSha256:sha(Buffer.from(instrumented)),testModuleSha256:sha(fixture),description:'Only an extra #[test_only] Versioned constructor, inserted into a disposable source copy. No production assertions/constants/logic changed.'},allNormalModulesStillMatch:true,modules,scope:'Private-state version-gate fixture only, reported separately from unmodified-source unit suite; not an on-chain rollout or a real historical package compatibility test'};
fs.writeFileSync(path.join(root,'result.json'),JSON.stringify(output,null,2)+'\n');
console.log(JSON.stringify({tests:output.tests,allNormalModulesStillMatch:true,testOnlyOverlay:true}));
