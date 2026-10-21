#!/usr/bin/env node
// Local-only security regression evidence. No signing, chain calls or source edits.
import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {execFileSync, spawn} from 'node:child_process';

const repo = path.resolve(import.meta.dirname, '..');
const [destination, option] = process.argv.slice(2);
if (!destination || (option && !['--trace','--trace-partial','--trace-full'].includes(option))) {
  throw new Error('Usage: SUI_BINARY=/path/to/build-sui [SUI_TRACE_BINARY=/path/to/new-tracer] node tools/test-security.mjs NEW_DIRECTORY [--trace|--trace-partial|--trace-full]');
}
const root = path.resolve(destination), pkg = path.join(root, 'package');
const normal = path.join(root, 'normal'), evidence = path.join(root, 'evidence');
if (fs.existsSync(root)) throw new Error('Destination exists; refusing to overwrite');
const binary = process.env.SUI_BINARY || 'sui';
const version = execFileSync(binary, ['--version'], {encoding:'utf8'}).trim();
if (!version.includes('1.66.2-a9a6825eaf62')) throw new Error('Use recorded Sui 1.66.2-a9a6825eaf62');
const fullTrace=option==='--trace-full';
const traceBinary=fullTrace?process.env.SUI_TRACE_BINARY:binary;
if(fullTrace&&!traceBinary)throw new Error('Full capture requires SUI_TRACE_BINARY pointing to verified official Sui 1.81.1-e04cf9aa915c');
const traceVersion=fullTrace?execFileSync(traceBinary,['--version'],{encoding:'utf8'}).trim():version;
if(fullTrace&&traceVersion!=='sui 1.81.1-e04cf9aa915c')throw new Error('Use recorded tracing runtime Sui 1.81.1-e04cf9aa915c');
const hash = data => createHash('sha256').update(data).digest('hex');
function sourceHashes(at) {
  const files = [];
  function visit(dir, relative) {
    for (const entry of fs.readdirSync(dir, {withFileTypes:true})) {
      const full = path.join(dir, entry.name), file = path.join(relative, entry.name);
      if (entry.isDirectory()) visit(full, file);
      else files.push({file, sha256:hash(fs.readFileSync(full))});
    }
  }
  for (const part of ['sources','tests']) visit(path.join(at, part), part);
  return files.sort((a,b) => a.file.localeCompare(b.file));
}
const before = sourceHashes(repo), tree = hash(JSON.stringify(before));
const baseline = JSON.parse(fs.readFileSync(path.join(repo, 'evidence/coverage-2026-10-19/source-hashes.json')));
const production = entries => entries.filter(e => e.file.startsWith('sources/'));
if (JSON.stringify(production(before)) !== JSON.stringify(production(baseline))) {
  throw new Error('Production source differs from verified deployment baseline; review separately');
}
const expectedSecurityNames = [];
const securityFiles = fs.readdirSync(path.join(repo,'tests')).filter(file=>/^security_.*_tests\.move$/.test(file)).sort();
for (const file of securityFiles) {
  const text = fs.readFileSync(path.join(repo,'tests',file),'utf8');
  for (const m of text.matchAll(/#\[test(?:\s*,[^\]]*)?\]\s*(?:#\[[^\]]*\]\s*)*(?:public\s+)?fun\s+(\w+)\s*\(/g)) {
    expectedSecurityNames.push('turbos_clmm::'+file.replace('.move','')+'::'+m[1]);
  }
}
if (!expectedSecurityNames.length) throw new Error('No security tests found');
const partial=option==='--trace-partial';
const exclusions=partial?JSON.parse(fs.readFileSync(path.join(repo,'tools/security-trace-exclusions.json'))).excluded:[];
if(exclusions.some(e=>!expectedSecurityNames.includes(e.test))||new Set(exclusions.map(e=>e.test)).size!==exclusions.length)throw new Error('Trace exclusion list is stale or duplicated');
let selectedNames=expectedSecurityNames.filter(n=>!exclusions.some(e=>e.test===n));
fs.mkdirSync(evidence,{recursive:true});
const config = path.join(root,'isolated-client'); fs.mkdirSync(config);
fs.writeFileSync(path.join(config,'sui.keystore'),'[]\n');
fs.writeFileSync(path.join(config,'client.yaml'),`---\nkeystore:\n  File: ${JSON.stringify(path.join(config,'sui.keystore'))}\nexternal_keys: ~\nenvs:\n  - alias: mainnet\n    rpc: "https://fullnode.mainnet.sui.io:443"\n    ws: ~\n    basic_auth: ~\n    chain_id: 35834a8a\nactive_env: mainnet\nactive_address: ~\n`);
const env = {...process.env,SUI_BINARY:binary,SUI_CONFIG_DIR:config,RUST_MIN_STACK:'536870912'};
async function run(command,args,name) {
  const fd=fs.openSync(path.join(evidence,name),'wx'); let text='',timedOut=false,diskStopped=false;
  const child=spawn(command,args,{env,stdio:['ignore','pipe','pipe'],detached:process.platform!=='win32'});
  const stop=()=>{try {process.platform==='win32'?child.kill('SIGTERM'):process.kill(-child.pid,'SIGTERM');} catch {}};
  for(const stream of [child.stdout,child.stderr]) stream.on('data',b=>{fs.writeSync(fd,b);text=(text+b).slice(-2000000);});
  const guard=setInterval(()=>{const s=fs.statfsSync(root);if(s.bavail*s.bsize<5*1024**3){diskStopped=true;stop();}},1000);
  const timeout=setTimeout(()=>{timedOut=true;stop();},1200000);
  let code;
  try { code=await new Promise((resolve,reject)=>{child.on('error',reject);child.on('close',resolve);}); }
  finally {clearInterval(guard);clearTimeout(timeout);fs.closeSync(fd);}
  fs.writeFileSync(path.join(evidence,name+'.result.json'),JSON.stringify({command:[command,...args].map(s=>s.replaceAll(root,'DISPOSABLE_DIRECTORY')),exitCode:code,timedOut,diskStopped},null,2)+'\n');
  if(code!==0||timedOut||diskStopped) {console.log(text.slice(-8000));throw new Error(name+' failed; logs retained');}
  return text;
}
await run(process.execPath,[path.join(repo,'tools/test-current.mjs'),pkg],'full-suite-runner.log');
const full=JSON.parse(fs.readFileSync(path.join(pkg,'test-result.json')));
if(full.sourceTreeSha256!==tree||!full.sourceAndTestsUnchanged||full.testResult.failed)throw new Error('Full-suite source/result mismatch');
const passedNames=[...fs.readFileSync(path.join(pkg,'tests.log'),'utf8').matchAll(/\[ PASS\s+\]\s+(\S+)/g)].map(m=>m[1]);
if(passedNames.length!==full.testResult.total||new Set(passedNames).size!==passedNames.length||expectedSecurityNames.some(n=>!passedNames.includes(n)))throw new Error('Full suite omitted security tests or has duplicate names');
fs.mkdirSync(normal);
for(const part of ['sources','tests','Move.toml','Published.toml'])if(fs.existsSync(path.join(repo,part)))fs.cpSync(path.join(repo,part),path.join(normal,part),{recursive:true});
await run(binary,['move','build','--path',normal,'--build-env','mainnet','--no-lint','--silence-warnings'],'normal-build.log');
const reference=JSON.parse(fs.readFileSync(path.join(repo,'evidence/tests-current-2026-10-15/normal-bytecode.json')));
const modules=reference.modules.map(m=>({module:m.module,builtSha256:hash(fs.readFileSync(path.join(normal,'build/TurbosCLMM/bytecode_modules',m.module+'.mv'))),deployedSha256:m.deployedSha256}));
const actualFiles=fs.readdirSync(path.join(normal,'build/TurbosCLMM/bytecode_modules')).filter(f=>f.endsWith('.mv'));
if(!reference.allMatch||actualFiles.length!==modules.length||modules.some(m=>m.builtSha256!==m.deployedSha256))throw new Error('Normal-build root bytecode differs from recorded deployment');
const commit=execFileSync('git',['-C',repo,'rev-parse','HEAD'],{encoding:'utf8'}).trim();
const identity={commit,sourceTreeSha256:tree,sourceHashes:before,workingTreeMayContainUncommittedTests:true};
fs.writeFileSync(path.join(root,'identity.json'),JSON.stringify(identity,null,2)+'\n');
const result={generatedAt:new Date().toISOString(),baseCommit:commit,sourceTreeSha256:tree,fullSuite:full.testResult,securityTestsPassed:expectedSecurityNames.length,securityModules:securityFiles,expectedSecurityNames,productionSourcesUnchanged:true,normalBytecodeReference:{allMatch:true,modules,scope:'Recorded immutable deployed-module hashes, not a fresh chain read or dependency audit'},traceRequested:Boolean(option),partialSecurityTrace:partial,traceExclusions:exclusions,fullSuiteTraced:fullTrace,toolchain:traceVersion,productionBuildToolchain:version};
fs.copyFileSync(path.join(pkg,'tests.log'),path.join(evidence,'full-tests.log'));
fs.writeFileSync(path.join(evidence,'source-hashes.json'),JSON.stringify(before,null,2)+'\n');
fs.writeFileSync(path.join(evidence,'normal-bytecode.json'),JSON.stringify(result.normalBytecodeReference,null,2)+'\n');
if(option) {
  if(fullTrace)selectedNames=passedNames;
  const filter=fullTrace?null:partial?'('+selectedNames.map(n=>n.replace('turbos_clmm::','')).join('|')+')$':securityFiles.map(file=>file.replace('.move','')).join('|');
  const text=await run(traceBinary,['move','test','--path',pkg,'--build-env','mainnet','--coverage','--trace','--no-lint','--silence-warnings','--gas-limit','1000000000','--threads','1',...(filter?[filter]:[])],'traced-tests.log');
  const traced=[...text.matchAll(/\[ PASS\s+\]\s+(\S+)/g)].map(m=>m[1]);
  const summary=text.match(/Test result: OK\. Total tests: (\d+); passed: (\d+); failed: 0/);
  const traces=fs.readdirSync(path.join(pkg,'traces')).filter(f=>f.endsWith('.json.zst'));
  if(!summary||Number(summary[1])!==selectedNames.length||traced.length!==selectedNames.length||new Set(traced).size!==traced.length||traces.length!==selectedNames.length||selectedNames.some(n=>!traced.includes(n)||!traces.some(f=>f.startsWith(n.replaceAll('::','__')+'.'))))throw new Error('Selected tracing incomplete; refusing a complete-capture claim');
  await run(traceBinary,['move','coverage','--path',pkg,'--build-env','mainnet','lcov','--silence-warnings','--no-lint'],'lcov-generation.log');
  fs.copyFileSync(path.join(pkg,'lcov.info'),path.join(evidence,'raw-lcov.info'));
  fs.writeFileSync(path.join(evidence,'run.json'),JSON.stringify({sourceCommit:commit,sourceTreeSha256:tree,total:traced.length,passed:traced.length,failed:0,filter,fullSuiteTests:full.testResult.total,fullSuitePassed:full.testResult.passed,securityRegressionTests:expectedSecurityNames.length,traceExclusions:exclusions,fullSuiteTraced:fullTrace,perTestTraceCount:traces.length,allTracedTestsHaveTrace:true,allPassingTestsHaveTrace:fullTrace,toolchain:traceVersion,productionBuildToolchain:version,scope:fullTrace?'Full current unit-test suite, no filter or exclusions; original compiler verifies deployed bytecode, newer runtime compiles source for tracing only':'Selected security regression tests; NOT all current CLMM tests'},null,2)+'\n');
  await run(process.execPath,[path.join(repo,'tools/summarize-current-coverage.mjs'),'clmm',pkg,normal,evidence],'production-summary.log');
  const reportFile=path.join(evidence,'production-coverage.json'),report=JSON.parse(fs.readFileSync(reportFile));
  report.toolchain=traceVersion;report.productionBuildToolchain=version;
  report.testRuntimeNote='Coverage runtime may emit a newer bytecode format. It is not a deployment build; deployed-bytecode verification remains on the original compiler.';
  fs.writeFileSync(reportFile,JSON.stringify(report,null,2)+'\n');
  result.securityTraceCount=traces.length;
}
if(JSON.stringify(before)!==JSON.stringify(sourceHashes(repo))||JSON.stringify(before)!==JSON.stringify(sourceHashes(pkg)))throw new Error('Source/tests changed during run');
fs.writeFileSync(path.join(evidence,'result.json'),JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({evidence,fullSuite:result.fullSuite,securityTestsPassed:result.securityTestsPassed,normalBytecodeAllMatch:true,securityTraceCount:result.securityTraceCount??null,fullSuiteTraced:fullTrace},null,2));
