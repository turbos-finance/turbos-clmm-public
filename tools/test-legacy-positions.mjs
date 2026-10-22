#!/usr/bin/env node
// Explicit compatibility-state fixture. Never modifies repository production sources.
import fs from 'node:fs';import path from 'node:path';import {createHash} from 'node:crypto';
import {execFileSync,spawnSync} from 'node:child_process';
const repo=path.resolve(import.meta.dirname,'..');
const [baselineArgument,destination]=process.argv.slice(2);
if(!baselineArgument||!destination)throw new Error('Usage: SUI_BINARY=/path/to/sui node tools/test-legacy-positions.mjs PASSING_SECURITY_RUN_ROOT NEW_DIRECTORY');
const baseline=path.resolve(baselineArgument),root=path.resolve(destination);
if(fs.existsSync(root))throw new Error('Refusing overwrite');
const binary=process.env.SUI_BINARY||'sui';
if(execFileSync(binary,['--version'],{encoding:'utf8'}).trim()!=='sui 1.66.2-a9a6825eaf62')throw new Error('Use recorded original toolchain');
const sha=b=>createHash('sha256').update(b).digest('hex');
const result=JSON.parse(fs.readFileSync(path.join(baseline,'evidence/result.json')));
const hashes=JSON.parse(fs.readFileSync(path.join(baseline,'evidence/source-hashes.json')));
if(result.fullSuite.status!=='OK'||result.fullSuite.failed||!result.normalBytecodeReference.allMatch)throw new Error('Passing baseline required');
for(const h of hashes)if(sha(fs.readFileSync(path.join(repo,h.file)))!==h.sha256)throw new Error('Baseline drift');
fs.mkdirSync(root,{recursive:true});const pkg=path.join(root,'package');fs.mkdirSync(pkg);
for(const part of ['sources','tests','Move.toml','Published.toml'])if(fs.existsSync(path.join(baseline,'package',part)))fs.cpSync(path.join(baseline,'package',part),path.join(pkg,part),{recursive:true});
const source=fs.readFileSync(path.join(pkg,'sources/pool.move'),'utf8');
if(source!==fs.readFileSync(path.join(repo,'sources/pool.move'),'utf8')||source.includes('security_rekey_position_fixture'))throw new Error('Unexpected pool source');
const hook=fs.readFileSync(path.join(repo,'tools/legacy-fixtures/pool-rekey-hook.move.inc'),'utf8');
const end=source.lastIndexOf('}');if(end<0)throw new Error('Unexpected source shape');
const instrumented=source.slice(0,end)+hook+source.slice(end);
fs.writeFileSync(path.join(pkg,'sources/pool.move'),instrumented);
const fixture=fs.readFileSync(path.join(repo,'tools/legacy-fixtures/legacy_position_fixture_tests.move'));
fs.writeFileSync(path.join(pkg,'tests/legacy_position_fixture_tests.move'),fixture);
const expected=[...fixture.toString().matchAll(/#\[test(?:\s*,[^\]]*)?\]\s*fun\s+(\w+)\s*\(/g)].map(m=>'turbos_clmm::legacy_position_fixture_tests::'+m[1]);
if(!expected.length||new Set(expected).size!==expected.length)throw new Error('Invalid fixture inventory');
const env={...process.env,SUI_CONFIG_DIR:path.join(baseline,'isolated-client'),RUST_MIN_STACK:'536870912'};
function run(args,name){const r=spawnSync(binary,args,{env,encoding:'utf8',timeout:180000,maxBuffer:20*1024**2});const text=(r.stdout||'')+(r.stderr||'');fs.writeFileSync(path.join(root,name),text);if(r.status!==0||r.error){console.log(text.slice(-12000));throw new Error(name+' failed');}return text;}
const log=run(['move','test','--path',pkg,'--build-env','mainnet','--no-lint','--silence-warnings','--gas-limit','1000000000','--threads','1','legacy_position_fixture_tests'],'tests.log');
const passed=[...log.matchAll(/\[ PASS\s+\]\s+(\S+)/g)].map(m=>m[1]);
const summary=log.match(/Test result: OK\. Total tests: (\d+); passed: (\d+); failed: 0/);
if(!summary||Number(summary[1])!==expected.length||Number(summary[2])!==expected.length||passed.length!==expected.length||new Set(passed).size!==passed.length||expected.some(n=>!passed.includes(n)))throw new Error('Fixture test inventory mismatch');
run(['move','build','--path',pkg,'--build-env','mainnet','--no-lint','--silence-warnings'],'normal-build-with-hook.log');
const modules=result.normalBytecodeReference.modules.map(m=>({...m,instrumentedNormalSha256:sha(fs.readFileSync(path.join(pkg,'build/TurbosCLMM/bytecode_modules',m.module+'.mv')))}));
if(modules.some(m=>m.instrumentedNormalSha256!==m.deployedSha256)||fs.readdirSync(path.join(pkg,'build/TurbosCLMM/bytecode_modules')).filter(f=>f.endsWith('.mv')).length!==modules.length)throw new Error('Overlay leaked into normal bytecode');
for(const h of hashes)if(sha(fs.readFileSync(path.join(repo,h.file)))!==h.sha256||sha(fs.readFileSync(path.join(pkg,h.file)))!==(h.file==='sources/pool.move'?sha(Buffer.from(instrumented)):h.sha256))throw new Error('Unexpected source drift');
let tracing=null;
if(process.env.SUI_TRACE_BINARY){
 const traceBinary=process.env.SUI_TRACE_BINARY;
 const version=execFileSync(traceBinary,['--version'],{encoding:'utf8'}).trim();
 if(version!=='sui 1.81.1-e04cf9aa915c')throw new Error('Use recorded tracing runtime');
 const args=['move','test','--path',pkg,'--build-env','mainnet','--coverage','--trace','--no-lint','--silence-warnings','--gas-limit','1000000000','--threads','1','legacy_position_fixture_tests'];
 const traced=spawnSync(traceBinary,args,{env,encoding:'utf8',timeout:180000,maxBuffer:20*1024**2});
 const log=(traced.stdout||'')+(traced.stderr||'');fs.writeFileSync(path.join(root,'traced-tests.log'),log);
 if(traced.status!==0||traced.error){console.log(log.slice(-7000));throw new Error('Legacy tracing failed');}
 const names=[...log.matchAll(/\[ PASS\s+\]\s+(\S+)/g)].map(m=>m[1]);
 const files=fs.readdirSync(path.join(pkg,'traces')).filter(n=>n.endsWith('.json.zst'));
 if(names.length!==expected.length||new Set(names).size!==expected.length||files.length!==expected.length||expected.some(n=>!names.includes(n)||!files.some(f=>f.startsWith(n.replaceAll('::','__')+'.'))))throw new Error('Incomplete legacy traces');
 tracing={toolchain:version,tests:names.length,perTestTraceCount:files.length,allTestsTraced:true,filter:'legacy_position_fixture_tests',scope:'Synthetic compatibility overlay only; not merged into normal-source production coverage'};
}
for(const h of hashes)if(sha(fs.readFileSync(path.join(repo,h.file)))!==h.sha256||sha(fs.readFileSync(path.join(pkg,h.file)))!==(h.file==='sources/pool.move'?sha(Buffer.from(instrumented)):h.sha256))throw new Error('Unexpected source drift after tracing');
const output={generatedAt:new Date().toISOString(),baselineSourceTreeSha256:result.sourceTreeSha256,toolchain:execFileSync(binary,['--version'],{encoding:'utf8'}).trim(),tests:{total:expected.length,passed:passed.length,failed:0},executedTestNames:passed,tracing,testOnlyOverlay:{file:'sources/pool.move',originalSha256:sha(Buffer.from(source)),hookSha256:sha(Buffer.from(hook)),instrumentedSha256:sha(Buffer.from(instrumented)),testModuleSha256:sha(fixture),description:'Only an extra #[test_only] helper relocates an actually minted Position to an owner-address dynamic-field key, preserving the Position bytes and pool fields. No production assertion, guard or arithmetic is replaced.'},allNormalModulesStillMatch:true,modules,scope:'Synthetic compatibility state, reported separately from normal-source unit tests and coverage. Not a mainnet object survey, replay of a historical package, or proof all legacy NFTs transfer their underlying positions.'};
fs.writeFileSync(path.join(root,'result.json'),JSON.stringify(output,null,2)+'\n');
console.log(JSON.stringify({tests:output.tests,allNormalModulesStillMatch:true,testOnlyOverlay:true}));
