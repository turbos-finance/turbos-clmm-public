#!/usr/bin/env node
// Narrow semantic witness map: every direct version-check call in normal code.
// Does not infer other authorization or invariant outcomes from line coverage.
import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
const repo=path.resolve(import.meta.dirname,'..');
const [runArg,versionArg,guardsArg,outputArg]=process.argv.slice(2);
if(!outputArg)throw new Error('Usage: node tools/check-version-surface.mjs FULL_RUN VERSION_RUN GUARD_INVENTORY NEW_JSON');
const run=path.join(path.resolve(runArg),'evidence'),versions=path.resolve(versionArg),output=path.resolve(outputArg);
if(fs.existsSync(output))throw new Error('Refusing overwrite');
const read=file=>JSON.parse(fs.readFileSync(file));
const r=read(path.join(run,'result.json')),v=read(path.join(versions,'result.json')),g=read(path.resolve(guardsArg));
const sha=b=>createHash('sha256').update(b).digest('hex');
if(!r.fullSuiteTraced||r.fullSuite.failed||r.traceExclusions.length||r.securityTraceCount!==r.fullSuite.passed||
 v.tests.failed||!v.allNormalModulesStillMatch||v.baselineSourceTreeSha256!==r.sourceTreeSha256||g.sourceTreeSha256!==r.sourceTreeSha256)
 throw new Error('Matching full passing evidence required');
const hashes=read(path.join(run,'source-hashes.json'));
for(const h of hashes)if(sha(fs.readFileSync(path.join(repo,h.file)))!==h.sha256)throw new Error('Source/test drift: '+h.file);
const fixture=fs.readFileSync(path.join(repo,'tools/version-fixtures/security_version_fixture_tests.move'),'utf8');
if(sha(fixture)!==v.testOnlyOverlay.testModuleSha256)throw new Error('Version fixture drift');
function passing(file){return new Set([...fs.readFileSync(file,'utf8').matchAll(/\[ PASS\s+\]\s+(\S+)/g)].map(m=>m[1]));}
const passed=passing(path.join(versions,'tests.log'));
if(passed.size!==v.tests.passed)throw new Error('Version log count mismatch');
// In the normal source/test tree Versioned can only be constructed in init as
// VERSION=18; upgrade sets the same constant. Therefore a normal guard-line hit
// is a current-version pass, not merely an unknown-outcome assertion-line hit.
const pool=fs.readFileSync(path.join(repo,'sources/pool.move'),'utf8');
if(!/const VERSION: u64 = 18;/.test(pool)||!pool.includes('version: VERSION')||!pool.includes('versioned.version = VERSION'))throw new Error('Review version-state reasoning');
const constructors=hashes.flatMap(h=>{
 const text=fs.readFileSync(path.join(repo,h.file),'utf8').replace(/\/\*[\s\S]*?\*\/|\/\/[^\n]*/g,'');
 return [...text.matchAll(/\bVersioned\s*\{/g)].map(()=>h.file);
});
// One struct definition plus one constructor in pool.move. Struct definitions
// are not captured if they have abilities; check the actual source inventory.
if(constructors.length!==1||constructors[0]!=='sources/pool.move')throw new Error('Unexpected normal Versioned constructor');
const map={};
function add(module,pairs){for(const [fn,test] of Object.entries(pairs))map[module+'::'+fn]=test;}
add('pool',Object.fromEntries(['flash_swap','flash_swap_partner','repay_flash_swap','repay_flash_swap_partner'].map(n=>[n,n])));
add('pool_factory',{
 deploy_pool:'deploy_pool',deploy_pool_and_mint:'deploy_and_mint',deploy_pool_and_mint_with_return_:'deploy_and_mint_return',
 ...Object.fromEntries(['set_fee_tier','set_fee_protocol','update_pool_fee_protocol','collect_protocol_fee','collect_protocol_fee_with_return','toggle_pool_status','update_nft_name','update_nft_description','update_nft_img_url'].map(n=>[n+'_v2',n])),
 ...Object.fromEntries(['add_role','remove_member','remove_role','set_roles'].map(n=>[n,n])),
});
add('pool_fetcher',{compute_swap_result:'quote',fetch_ticks:'fetch_ticks'});
add('position_manager',{
 mint:'position_mint',mint_with_return_:'position_mint_return',burn:'position_burn',
 increase_liquidity:'increase',increase_liquidity_with_return_:'increase_return',
 decrease_liquidity:'decrease',decrease_liquidity_with_return_:'decrease_return',
 collect:'position_collect',collect_with_return_:'position_collect_return',
 collect_reward:'position_reward',collect_reward_with_return_:'position_reward_return',
 burn_position_nft_with_return_:'burn_proof_conversion',burn_nft_collect_reward_with_return_:'burn_proof_reward',
});
add('reward_manager',Object.fromEntries(['init_reward','reset_reward','add_reward','remove_reward','update_reward_emissions'].map(n=>[n+'_v2',n])));
add('swap_router',{
 swap_with_partner:'generic_partner_router',
 ...Object.fromEntries(['a_b','b_a','a_b_b_c','a_b_c_b','b_a_b_c','b_a_c_b'].flatMap(n=>[
  ['swap_'+n,'router_'+n],['swap_'+n+'_with_return_','router_'+n+'_return'],
 ])),
});
function witness(suffix){
 const name='future_version_blocks_'+suffix,full='turbos_clmm::security_version_fixture_tests::'+name;
 if(!passed.has(full)||!new RegExp('#\\[test, expected_failure\\(abort_code = 23, location = turbos_clmm::pool\\)\\]\\s*fun '+name+'\\(').test(fixture))throw new Error('Missing exact pool::23 witness '+full);
 return full;
}
const direct=g.functions.filter(f=>f.guards.some(x=>x.call?.endsWith('check_version')));
if(direct.length!==53||Object.keys(map).length!==53)throw new Error('Version surface changed: re-review mapping');
const rows=direct.map(f=>{
 const entry=f.module+'::'+f.function,guards=f.guards.filter(x=>x.call?.endsWith('check_version'));
 if(!map[entry]||guards.length!==1||!guards[0].lineExecuted)throw new Error('Unmapped/unexecuted version call '+entry);
 return {entry,file:f.file,line:guards[0].line,currentVersion:{value:18,guardPassedInUnmodifiedSuite:true,
  qualification:'Guard-line execution with the only normal Versioned constructor fixed at 18; not a claim that every enclosing operation completed successfully.'},
  futureVersion:{value:19,test:witness(map[entry]),expectedAbort:{module:'pool',code:23}}};
});
const delegates=[
 {entry:'swap_router::swap_a_b_with_partner',test:'a_to_b_partner_router'},
 {entry:'swap_router::swap_b_a_with_partner',test:'b_to_a_partner_router'},
 {entry:'position_manager::burn_nft_collect_fee_with_return_',test:'burn_proof_fee_delegation'},
].map(d=>({...d,test:witness(d.test),scope:'Wrapper delegates to a version-checked function; not an additional direct version call.'}));
const named=[...rows.map(x=>x.futureVersion.test),...delegates.map(x=>x.test)];
if(new Set(named).size!==56||[...passed].filter(n=>n.includes('::future_version_blocks_')).length!==56)throw new Error('Entry witness bijection mismatch');
const data={generatedAt:new Date().toISOString(),sourceTreeSha256:r.sourceTreeSha256,
 scope:'All direct check_version calls in normal production functions, plus three delegated public wrappers. Explicit current/future guard witnesses, not exhaustive authorization/invariant closure.',
 summary:{directVersionCalls:rows.length,currentVersionGuardPasses:rows.length,exactFutureRejections:rows.length,delegatedWrapperRejections:delegates.length,separateStateCases:passed.size-named.length,versionFixtureTotal:passed.size},
 rows,delegates,limitations:['Future states use a disclosed test-only constructor in a disposable copy and are excluded from normal-source coverage.',
 'This is a source-local v18 versus stored-version-19 test, not a deployment or historical package replay.',
 'No version setter custody or mainnet rollout is verified by these tests. Other guard families require their own semantic review.']};
fs.writeFileSync(output,JSON.stringify(data,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify(data.summary));
