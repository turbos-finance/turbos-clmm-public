#!/usr/bin/env node
// Checks a narrowly scoped source-to-executed-test mapping. Not a formal proof,
// full invariant inventory, or an inference from a coverage percentage.
import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';

const repo=path.resolve(import.meta.dirname,'..');
const [runArgument,versionArgument,outputArgument]=process.argv.slice(2);
if(!outputArgument)throw new Error('Usage: node tools/check-security-witnesses.mjs PASSING_FULL_RUN PASSING_VERSION_RUN NEW_OUTPUT_JSON');
const run=path.resolve(runArgument),versions=path.resolve(versionArgument),output=path.resolve(outputArgument);
if(fs.existsSync(output))throw new Error('Refusing overwrite');
const result=JSON.parse(fs.readFileSync(path.join(run,'evidence/result.json')));
const version=JSON.parse(fs.readFileSync(path.join(versions,'result.json')));
if(result.fullSuite.failed||!result.fullSuiteTraced||result.traceExclusions.length||
    result.fullSuite.passed!==result.securityTraceCount||version.tests.failed||
    version.baselineSourceTreeSha256!==result.sourceTreeSha256||!version.allNormalModulesStillMatch)
  throw new Error('Complete passing runs required');
for(const h of JSON.parse(fs.readFileSync(path.join(run,'evidence/source-hashes.json'))))
  if(createHash('sha256').update(fs.readFileSync(path.join(repo,h.file))).digest('hex')!==h.sha256)
    throw new Error('Test/source drift: '+h.file);
const inventoryFile=output+'.entry-inventory.json';
execFileSync(process.execPath,[path.join(repo,'tools/security-inventory.mjs'),inventoryFile]);
const inventory=JSON.parse(fs.readFileSync(inventoryFile));
function passing(file){const names=[...fs.readFileSync(file,'utf8').matchAll(/\[ PASS\s+\]\s+(\S+)/g)].map(m=>m[1]);
  if(new Set(names).size!==names.length)throw new Error('Duplicate test names');return new Set(names);}
const baseline=passing(path.join(run,'evidence/full-tests.log'));
const traced=passing(path.join(run,'evidence/traced-tests.log'));
const versionPassed=passing(path.join(versions,'tests.log'));
const acl=inventory.functions.filter(f=>f.aclChecks.length&&!f.retiredAbortZero);
if(acl.length!==14||acl.some(f=>f.aclChecks.length!==1))throw new Error('ACL surface changed; manual review required');
const aclWitnesses=acl.map(f=>{
  const name=f.function.replace(/_v2$/,'');
  const tests=['allows_required_role','rejects_missing_role','rejects_other_roles','rejects_revoked_role']
    .map(s=>'turbos_clmm::security_entrypoint_tests::'+name+'_'+s);
  for(const name of tests)if(!baseline.has(name)||!traced.has(name))throw new Error('Missing ACL witness '+name);
  return {entry:f.module+'::'+f.function,file:f.file,line:f.line,roleCheck:f.aclChecks[0],tests,
    observation:'Reviewed test mapping: one positive and three exact-module/abort-code negative execution cases. Names checked against both unfiltered runs.'};
});
const addedModules=['security_partner_router_tests','security_factory_return_tests','security_quote_cross_tests','security_exit_obligation_tests','security_math_guard_tests'];
const boundaryWitnesses=addedModules.map(module=>{
  const prefix='turbos_clmm::'+module+'::';
  const names=[...baseline].filter(n=>n.startsWith(prefix));
  if(!names.length||names.some(n=>!traced.has(n)))throw new Error('Missing boundary witnesses '+module);
  return {module,tests:names,scope:'Cases listed by exact executed name; this module is not an exhaustive list of all protocol invariants.'};
});
const futureVersionWitnesses=[...versionPassed].filter(n=>n.includes('::future_version_blocks_'));
if(futureVersionWitnesses.length<26)throw new Error('Future-version boundary witnesses missing');
const data={generatedAt:new Date().toISOString(),sourceTreeSha256:result.sourceTreeSha256,
  scope:'Executed witness validation for all 14 live ACL-gated factory/reward entries and the explicitly listed boundary/version tests. Not exhaustive package-wide authorization/invariant coverage.',
  aclEntryCount:acl.length,aclRuntimeCases:aclWitnesses.length*4,aclWitnesses,boundaryWitnesses,
  futureVersionWitnesses,versionFixtureTests:version.tests,
  limitations:['Object capability ownership is a shared Sui input rule; compiler-negative and ownership tests are separate evidence, not arbitrary unauthorized business calls.',
    'Retired/private helpers, initialization-only wrappers and uncovered mathematical/state branches remain visible in coverage. A branch hit alone is not a positive/negative assertion witness.',
    'Final acceptance of the requested requirement is not decided by this script.']};
fs.writeFileSync(output,JSON.stringify(data,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({aclEntries:acl.length,aclRuntimeCases:acl.length*4,boundaryCases:boundaryWitnesses.reduce((n,m)=>n+m.tests.length,0),futureVersionEntries:futureVersionWitnesses.length,output}));
