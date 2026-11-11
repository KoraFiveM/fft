const $ = id => document.getElementById(id);
const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'fft';
const TEMPLATE = '@review\nFeature: Describe the behaviour\n\n  Scenario: Describe the expected outcome\n    # Insert existing steps from the catalogue.\n';
const store = {
  get(key){try{return localStorage.getItem(key);}catch{return null;}},
  set(key,value){try{localStorage.setItem(key,value);}catch{/* storage unavailable: the draft lives for this session only */}},
};

function action(name, data = {}){
  const body = name==='run' ? {...data, stepDelayMs:Number($('pace').value)} : data;
  return fetch(`https://${resource}/action`, {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({action:name,data:body})})
    .catch(e => notice(e.message,true));
}
function notice(message,error=false,busy=false){
  $('notice').textContent=message;$('notice').classList.toggle('error',error);$('notice').classList.toggle('busy',busy);
}
function node(tag,text,cls){const n=document.createElement(tag);n.textContent=text;if(cls)n.className=cls;return n;}
function tab(name){
  document.querySelectorAll('.tab').forEach(n=>n.hidden=n.id!==name);
  document.querySelectorAll('[data-tab]').forEach(n=>n.classList.toggle('active',n.dataset.tab===name));
  if(name==='writer'&&!definitions){$('definitions').replaceChildren(node('p','Loading step catalogue…','muted'));action('definitions');}
}
function exportText(name,text){
  const a=document.createElement('a');const url=URL.createObjectURL(new Blob([text],{type:'text/plain'}));
  a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
  notice(`Download requested: ${name}. If the FiveM browser blocks downloads, use Copy or the file saved on the server.`);
}
async function copy(text){
  try{await navigator.clipboard.writeText(text);}
  catch{
    const t=document.createElement('textarea');t.value=text;document.body.append(t);t.select();
    const ok=document.execCommand('copy');t.remove();
    if(!ok){notice('Clipboard unavailable: select and copy the text manually.',true);return;}
  }
  notice('Copied.');
}
function lua(value){
  if(value===null||value===undefined)return 'nil';
  if(typeof value==='string')return JSON.stringify(value);
  if(typeof value==='object')return '{ '+Object.entries(value).map(([k,v])=>`${k} = ${lua(v)}`).join(', ')+' }';
  return String(value);
}
const plural=(n,word)=>`${n} ${word}${n===1?'':'s'}`;

// ---- Step and scenario rendering -------------------------------------------
function failure(message){
  const full=String(message||'Unknown failure');
  const first=full.split('\n').find(line=>line.trim()&&!line.startsWith('stack traceback:'))||full;
  return first.replace(/^\s+/, '');
}
function diagnostic(message){
  const full=String(message||'Unknown failure');
  const wrap=node('div','', 'diagnostic');
  wrap.append(node('p',failure(full),'failure-summary'));
  if(full.includes('\n')){
    const details=document.createElement('details');
    details.append(node('summary','Stack trace'),node('pre',full,'failed'));
    wrap.append(details);
  }
  return wrap;
}
function stepRow(step,uri){
  const row=node('div','',`step ${step.status||''}`);
  const elapsed=Number.isFinite(step.duration)?` · ${(step.duration/1000).toFixed(2)}s`:'';
  row.append(node('div',`${step.status||step.realm||''} · ${step.text}${elapsed}`));
  if(step.location)row.append(node('small',`${step.realm||''} · ${uri||''}:${step.location.line}`));
  if(step.error)row.append(diagnostic(step.error));
  if(step.assertion)row.append(node('pre',`Expected: ${JSON.stringify(step.assertion.expected)}\nActual: ${JSON.stringify(step.assertion.actual)}`));
  return row;
}
function scenarioBody(s){
  const parts=(s.steps||[]).map(step=>stepRow(step,s.uri));
  if(s.error)parts.push(diagnostic(s.error));
  for(const h of s.hooks||[]){const row=node('div',`Hook ${h.name}: ${h.status}`,h.status);if(h.error)row.append(diagnostic(h.error));parts.push(row);}
  if(s.cleanupErrors?.length){const row=node('div','Cleanup failed','failed');for(const error of s.cleanupErrors)row.append(diagnostic(error));parts.push(row);}
  return parts;
}
function renderScenario(s,container){
  const box=node('article','', 'scenario'), head=node('header',''), title=node('div','');
  title.append(node('h2',s.name),node('span',`${s.uri||''} ${s.tags?.join(' ')||''}`, 'muted'));
  head.append(title,node('span',s.status||'running',s.status));
  box.append(head,...scenarioBody(s));
  container.append(box);
}

// ---- Tests tab ---------------------------------------------------------------
// The list holds one line per scenario, grouped by feature. Steps arrive on
// demand ('detail') the first time a scenario is expanded. Search and tag
// filters are resolved by the server ('search'), which also sees step text.
const stepCache=new Map(), openFeatures=new Set(), openScenarios=new Set();
let features=[], filter=null, listed=false, definitions=null, searchTimer=null;
const filterInputs=()=>({query:$('search').value.trim(),tags:$('tags').value.trim()});
function fillSteps(holder,uri,steps){holder.replaceChildren(...(steps.length?steps.map(step=>stepRow(step,uri)):[node('p','No steps.','muted')]));}
function showSteps(holder,id,uri){
  holder.hidden=false;
  if(stepCache.has(id))fillSteps(holder,uri,stepCache.get(id));
  else{holder.replaceChildren(node('p','Loading steps…','muted'));action('detail',{id});}
}
function listScenario(s,uri){
  const box=node('article','', 'scenario'), head=node('header',''), title=node('button','', 'scenario-title'), steps=node('div','', 'steps');
  box.dataset.id=s.id;steps.hidden=true;
  title.append(node('h2',s.name),node('span',`${s.tags?.join(' ')||''} · ${plural(s.steps,'step')}`, 'muted'));
  if(s.problems)title.append(node('span',` · ${s.problems} undefined or ambiguous`, 'failed'));
  title.onclick=()=>{
    if(steps.hidden){openScenarios.add(s.id);showSteps(steps,s.id,uri);}
    else{openScenarios.delete(s.id);steps.hidden=true;}
  };
  const run=node('button','Run','primary');run.onclick=()=>action('run',{id:s.id});
  head.append(title,run);box.append(head,steps);
  if(openScenarios.has(s.id))showSteps(steps,s.id,uri);
  return box;
}
function renderList(){
  const shown=features.map(f=>({uri:f.uri,scenarios:filter?f.scenarios.filter(s=>filter.has(s.id)):f.scenarios})).filter(f=>f.scenarios.length);
  const total=shown.reduce((n,f)=>n+f.scenarios.length,0), all=features.reduce((n,f)=>n+f.scenarios.length,0);
  $('countTests').textContent=total;
  $('scenarios').replaceChildren(...shown.map(f=>{
    const group=document.createElement('details');group.className='feature';
    group.open=openFeatures.has(f.uri)||shown.length===1||(filter&&total<=25);
    const problems=f.scenarios.reduce((n,s)=>n+(s.problems||0),0);
    const summary=node('summary',f.uri.split('/').pop());
    summary.append(node('span',` · ${plural(f.scenarios.length,'scenario')}`, 'muted'));
    if(problems)summary.append(node('span',` · ${plural(problems,'step problem')}`, 'failed'));
    group.append(summary,...f.scenarios.map(s=>listScenario(s,f.uri)));
    group.addEventListener('toggle',()=>group.open?openFeatures.add(f.uri):openFeatures.delete(f.uri));
    return group;
  }));
  if(!shown.length)$('scenarios').append(node('p',all?'No scenario matches the search and tags. Clear them to see everything.':'No features are registered.','muted'));
  if(filter)return `${total} of ${plural(all,'scenario')} match. "Run matching" runs exactly these.`;
  return all?`${plural(all,'scenario')} in ${plural(features.length,'feature')}. Choose a scenario or write a feature to get started.`:'Choose a scenario or write a feature to get started.';
}
function renderChips(){
  const counts=new Map();
  for(const f of features)for(const s of f.scenarios)for(const t of s.tags||[])counts.set(t,(counts.get(t)||0)+1);
  const top=[...counts].sort((a,b)=>b[1]-a[1]||a[0].localeCompare(b[0])).slice(0,14);
  const active=$('tags').value.split(/\s+/);
  $('chips').hidden=!top.length;
  $('chips').replaceChildren(node('span','Tags','muted'),...top.map(([tag,count])=>{
    const chip=node('button',tag,'chip');chip.title=plural(count,'scenario');
    chip.classList.toggle('on',active.includes(tag));chip.setAttribute('aria-pressed',active.includes(tag));
    chip.onclick=()=>{
      const words=$('tags').value.trim().split(/\s+/).filter(Boolean), at=words.indexOf(tag);
      if(at<0)$('tags').value=words.length?`${words.join(' ')} and ${tag}`:tag;
      else{
        // Drop the tag together with the 'and'/'or' that joined it.
        const joiner=w=>w==='and'||w==='or';
        if(at>0&&joiner(words[at-1]))words.splice(at-1,2);else if(joiner(words[at+1]||''))words.splice(at,2);else words.splice(at,1);
        $('tags').value=words.join(' ');
      }
      applyFilter();
    };
    return chip;
  }));
}
function applyFilter(){
  renderChips();
  const {query,tags}=filterInputs();
  if(!query&&!tags){filter=null;if(listed)notice(renderList());return;}
  notice('Filtering…',false,true);action('search',{query,tags});
}

// ---- Status: a small card while the panel is closed, the notice line while open
let panelOpen=false, status=null, finishedRun=null, stepKey='F6';
function paintStatus(){
  $('hud').hidden=!status||panelOpen;
  $('debugBar').hidden=!status?.paused;
  $('sessionState').textContent=status?(status.paused?'Paused in debugger':status.loading?'Loading':'Run in progress'):'Interactive session';
  if(!status)return;
  const d=status, loading=!!d.loading, paused=!!d.paused;
  const title=loading?'Loading tests':d.total&&d.index?`${paused?'Paused · ':''}Scenario ${d.index} of ${d.total}`:'Functional tests';
  const stepLine=loading?(d.total?`Parsing feature ${d.index} of ${d.total}`:'Parsing features')
    :d.step?`${paused?'Next: step':'Step'} ${d.stepIndex} of ${d.stepTotal} · ${d.step}`:`${d.phase}…`;
  const done=loading?(d.total?d.index/d.total:0):d.total&&d.index?(d.index-1+(d.stepTotal?(d.stepIndex-1)/d.stepTotal:0))/d.total:0;
  $('hud').classList.toggle('paused',paused);
  $('hudTitle').textContent=title;
  $('hudCounts').replaceChildren();
  if(!loading&&d.total)$('hudCounts').append(node('span',`✓ ${d.passed||0}`,'passed'),node('span',`✗ ${d.failed||0}`,d.failed?'failed':'muted'));
  $('hudScenario').textContent=d.scenario||'';$('hudScenario').hidden=!d.scenario;
  $('hudStep').textContent=stepLine;
  $('hudPrev').hidden=!(paused&&d.previous);
  if(paused&&d.previous){$('hudPrev').textContent=`Previous step ${d.previous.status}`;$('hudPrev').className=d.previous.status;}
  $('hudHint').textContent=paused?`${stepKey} runs the next step · /fft to open the panel or stop`:'/fft to view progress or stop';
  $('hudBar').style.width=`${Math.round(Math.min(1,Math.max(0,done))*100)}%`;
  if(panelOpen)notice([title,d.scenario,stepLine].filter(Boolean).join(' · '),false,!paused);
}
function setStatus(next){
  if(next&&next.id&&next.id===finishedRun)return; // a late update for a run that has already reported
  status=next;paintStatus();
}

// ---- Results and error log -----------------------------------------------------
// `errors` mixes both kinds: type 'test' (FFT step, hook, cleanup failures) and
// type 'console' (server console errors seen while the run was active).
let report=null, errors=[], runId=null;
const errorCounts=()=>({test:errors.filter(e=>e.type!=='console').length,console:errors.filter(e=>e.type==='console').length});
function errorLabel(e){return e.type==='console'?`CONSOLE ${e.resource||''}`.trim():`TEST ${e.kind||''}`.trim();}
// Console errors a scenario declared in advance are counted apart from errors.
const expectedConsoleText=sum=>`Expected console errors: ${sum.expectedConsole||0} matched, ${sum.unmatchedConsole||0} never seen.`;
function errorLogText(){
  const c=errorCounts(), r=report&&report.id===runId?report:null, sum=r?.summary;
  const out=[`FFT error log · run ${runId||r?.id||'setup'}${r?.adapter?` · adapter ${r.adapter}`:''}`];
  if(r)out.push(`Started ${r.started} · finished ${r.finished||'in progress'} · status ${r.status}`);
  if(sum)out.push(`Scenarios: ${sum.planned} planned, ${sum.run} run, ${sum.passed} passed, ${sum.failed} failed, ${sum.cancelled} cancelled`);
  out.push(`Errors: ${c.test} test, ${c.console} console${r?.errorsTruncated?' (log was capped)':''}`,
    'TEST = failure reported by a step, hook or cleanup. CONSOLE = error printed to the server console during the run.');
  if(sum&&(sum.expectedConsole||sum.unmatchedConsole))out.push(expectedConsoleText(sum)+' Details are in the saved error log and each scenario\'s expectedConsole.');
  out.push('');
  for(const e of errors){
    out.push(`#${e.n} [${errorLabel(e)}] ${e.time||''}`);
    if(e.scenario)out.push(`    scenario ${e.scenarioIndex}: ${e.scenario} (${e.uri||''}${e.line?':'+e.line:''})`);
    if(e.step)out.push(`    step ${e.stepIndex}/${e.stepTotal}: ${e.step}`);
    out.push(...String(e.message||'').split('\n').map(line=>'    '+line),'');
  }
  return out.join('\n');
}
function renderErrors(){
  const c=errorCounts(), kind=$('errorFilter').value;
  $('countErrors').textContent=errors.length;$('countErrors').classList.toggle('bad',errors.length>0);
  $('errorSummary').textContent=errors.length?`${plural(c.test,'test error')} · ${plural(c.console,'console error')}`:'';
  const shown=errors.filter(e=>kind==='all'||(kind==='console')===(e.type==='console'));
  if(!shown.length){$('errorList').replaceChildren(node('p',errors.length?'No errors of this type.':'No errors recorded.','muted'));return;}
  $('errorList').replaceChildren(...shown.map(e=>{
    const box=node('article','','error-entry'), head=node('header','');
    head.append(node('span',`#${e.n}`),node('b',errorLabel(e),`badge ${e.type==='console'?'console':'test'}`),node('span',e.time||''));
    box.append(head);
    if(e.scenario)box.append(node('p',`${e.scenario}${e.step?` · step ${e.stepIndex}/${e.stepTotal}: ${e.step}`:''}`));
    if(e.uri)box.append(node('small',`${e.uri}${e.line?':'+e.line:''}`));
    box.append(node('pre',e.message||''));
    return box;
  }));
}
function resultRow(s,open){
  const box=document.createElement('details');box.className='result';
  const summary=node('summary','');
  summary.append(node('span',s.status,s.status),node('span',s.name),node('span',(s.uri||'').split('/').pop(),'muted'));
  box.append(summary);
  // Steps are built when a row is first opened: a full run holds thousands.
  const fill=()=>{if(box.childElementCount===1)box.append(...scenarioBody(s));};
  box.addEventListener('toggle',()=>{if(box.open)fill();});
  if(open){fill();box.open=true;}
  return box;
}
// The tester's own archived runs (newest first), fetched from the server by uuid.
let pastRuns=[];
function renderPastRuns(){
  const select=$('pastRuns');
  const first=node('option',pastRuns.length?`Past runs (${pastRuns.length})…`:'No past runs');first.value='';
  select.replaceChildren(first,...pastRuns.map(r=>{
    const sum=r.summary||{};
    const when=String(r.finished||r.started||'').replace('T',' ').replace('Z',' UTC');
    const option=node('option',`${when} · ${r.status||'?'} · ${sum.passed??0} passed, ${sum.failed??0} failed${r.adapter?` · ${r.adapter}`:''}`);
    option.value=r.uuid;
    return option;
  }));
  select.disabled=!pastRuns.length;
  select.value=report?.uuid&&pastRuns.some(r=>r.uuid===report.uuid)?report.uuid:'';
}
function renderReport(){
  const d=report;
  if(!d){$('report').replaceChildren(node('p','No runs yet.','muted'));return;}
  const sum=d.summary||{run:d.scenarios.length,passed:d.scenarios.filter(s=>s.status==='passed').length,failed:d.scenarios.filter(s=>s.status!=='passed').length};
  const head=node('div','','summary');
  head.append(node('b',`Run ${d.status}`,d.status),node('span',`✓ ${sum.passed} passed`,'passed'),node('span',`✗ ${sum.failed} failed`,sum.failed?'failed':'muted'));
  if(sum.cancelled)head.append(node('span',`${sum.cancelled} cancelled`,'muted'));
  if(sum.planned>sum.run)head.append(node('span',`${sum.planned-sum.run} not run`,'muted'));
  if(sum.expectedConsole||sum.unmatchedConsole)head.append(node('span',expectedConsoleText(sum),'muted'));
  if(d.errors?.length){const link=node('button',`${plural(d.errors.length,'error')} in the error log`);link.onclick=()=>tab('errors');head.append(link);}
  const parts=[head];
  if(d.uuid||d.tester?.name)parts.push(node('p',[d.tester?.name&&`Run by ${d.tester.name}`,d.finished&&`finished ${d.finished.replace('T',' ').replace('Z',' UTC')}`,d.uuid&&`report ${d.uuid}`].filter(Boolean).join(' · '),'muted'));
  if(d.phase)parts.push(node('p',`Failed during ${d.phase}, before any scenario step.`, 'failure-summary'));
  if(d.error)parts.push(diagnostic(d.error));
  const failedOnly=$('resultFilter').value==='failed';
  let opened=0;
  for(const s of d.scenarios){
    const bad=s.status!=='passed';
    if(failedOnly&&!bad)continue;
    parts.push(resultRow(s,bad&&opened++<10));
  }
  if(failedOnly&&!d.scenarios.some(s=>s.status!=='passed'))parts.push(node('p','No failed scenarios.','muted'));
  $('report').replaceChildren(...parts);
  $('savedPath').textContent=d.files?`Saved on the server: fft/${d.files.archive||d.files.json} and fft/${d.files.archiveErrors||d.files.errors}`:'';
}
function loadReport(d){
  report=d;runId=d.id||null;errors=d.errors||[];
  $('live').replaceChildren();renderReport();renderErrors();
}

// ---- Writer: draft, validation, step catalogue -----------------------------------
let validatedText=null, discardArmed=null;
function draftState(text,cls){$('draftState').textContent=text;$('draftState').className=`state ${cls||''}`;}
function draftChanged(){
  store.set('fft.draft',$('draft').value);
  if(validatedText===null)return draftState('Not validated');
  if($('draft').value===validatedText)return;
  draftState('Changed · validate again','changed');
  // Scenario IDs belong to the validated text; fall back to running everything.
  $('draftScenario').replaceChildren(new Option('All draft scenarios',''));
}
function setDraft(text){$('draft').value=text;validatedText=null;$('validation').replaceChildren();$('draftScenario').replaceChildren(new Option('All draft scenarios',''));draftChanged();}
function runDraft(debug){
  const text=$('draft').value;
  if(!text.trim())return notice('The draft is empty.',true);
  const data={text};
  if($('draftScenario').value)data.id=$('draftScenario').value;
  if(debug)data.debug=true;
  action('run',data);
}
function renderDefinitions(){
  if(!definitions)return;
  const q=$('stepSearch').value.trim().toLowerCase();
  const found=q?definitions.filter(d=>`${d.realm} ${d.pattern} ${d.owner||''}`.toLowerCase().includes(q)):definitions;
  $('defCount').textContent=q?`${found.length} of ${definitions.length}`:plural(definitions.length,'definition');
  const rows=found.slice(0,60).map(d=>{
    const row=node('div','','definition'), text=node('div','');
    text.append(node('span',d.realm,'realm'),node('code',d.pattern));
    const insert=node('button','Insert step');insert.onclick=()=>insertStep(d.pattern);
    row.append(text,insert);return row;
  });
  if(found.length>60)rows.push(node('p',`${found.length-60} more. Refine the search to see them.`,'muted'));
  if(!found.length)rows.push(node('p','No step matches.','muted'));
  $('definitions').replaceChildren(...rows);
}
function insertStep(pattern){
  const area=$('draft'), text=area.value;
  let at=text.indexOf('\n',area.selectionEnd);if(at<0)at=text.length;
  // Continue with 'And' when the scenario above the caret already has a step.
  const before=text.slice(0,at), heads=[...before.matchAll(/^\s*(Scenario|Scenario Outline|Example|Background):/gm)];
  const scenario=before.slice(heads.length?heads[heads.length-1].index:0);
  const keyword=/^\s*(Given|When|Then|And|But|\*) /m.test(scenario)?'And':'Given';
  const line=`    ${keyword} ${pattern}`, lead=at===0||text[at-1]==='\n'?'':'\n';
  area.value=text.slice(0,at)+lead+line+text.slice(at);
  // Select the first parameter so it can be typed over.
  const start=at+lead.length, param=line.match(/\{[^}]*\}/);
  area.focus();
  if(param)area.setSelectionRange(start+param.index,start+param.index+param[0].length);
  else area.setSelectionRange(start+line.length,start+line.length);
  draftChanged();
}

// ---- Messages from the client script -------------------------------------------
// Posts to another resource's NUI callback exactly as that resource's own page
// would, and hands the answer back to the client script (FFT.nui). Script-fired
// `__cfx_nui:` events are not answered by current clients; a real fetch is.
function nuiFetch(d){
  const done=result=>fetch(`https://${resource}/nuiResult`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({id:d.id,...result})}).catch(()=>{});
  const abort=new AbortController();
  const timer=setTimeout(()=>abort.abort(),Math.max(500,Number(d.timeout)||5000));
  fetch(`https://${d.resource}/${d.name}`,{method:'POST',headers:{'Content-Type':'application/json; charset=UTF-8'},body:JSON.stringify(d.body??{}),signal:abort.signal})
    .then(async r=>{
      const text=await r.text();
      let value=null;
      try{value=text===''?null:JSON.parse(text);}catch{value=text;}
      return r.ok?{ok:true,result:value}:{ok:false,error:`HTTP ${r.status}`};
    })
    .catch(e=>({ok:false,error:e.name==='AbortError'?'timed out':String(e.message||e)}))
    .then(result=>{clearTimeout(timer);done(result);});
}
window.addEventListener('message',({data:m})=>{
  const d=m.data;
  if(m.kind==='nuiFetch'){nuiFetch(d);return;}
  if(m.kind==='visible'){
    panelOpen=!!d;$('panel').hidden=!d;
    if(!d)$('feedbackBox').hidden=true;
    if(d&&!listed&&!status)notice('Loading tests…',false,true);
    paintStatus();
  }
  if(m.kind==='error'){if(status&&!status.id)setStatus(null);notice(failure(d),true);}
  if(m.kind==='status')setStatus(d);
  if(m.kind==='catalogue'){
    $('adapter').textContent=[d.adapter,d.serverAddress].filter(Boolean).join(' · ');
    if(d.stepKey)stepKey=d.stepKey;
    // `features` is omitted when the list already on screen is current.
    let summary=null;
    if(d.features){
      // Expanded scenarios collapse: their steps may have changed, and refetching
      // them all at once would trip the server's request throttle.
      stepCache.clear();openScenarios.clear();features=d.features;definitions=null;
      summary=renderList();renderChips();
      if(!$('writer').hidden){$('definitions').replaceChildren(node('p','Loading step catalogue…','muted'));setTimeout(()=>action('definitions'),150);}
    }
    listed=true;
    $('fixtureText').textContent=d.fixture?`FFTConfig.vending = ${lua(d.fixture)}`:'No fixture captured';
    if(d.report&&!report)loadReport(d.report);
    if(status?.loading)setStatus(null);
    if(!status&&(summary||$('notice').classList.contains('busy')))notice(summary||renderList());
    const {query,tags}=filterInputs();
    if(d.features&&(query||tags))setTimeout(applyFilter,300);
  }
  if(m.kind==='search'){
    const {query,tags}=filterInputs();
    if(status?.loading)setStatus(null);
    if((d.query||'')!==query||(d.tags||'')!==tags)return; // superseded by newer input
    filter=query||tags?new Set(d.ids):null;
    notice(renderList());
  }
  if(m.kind==='detail'){
    stepCache.set(d.id,d.steps);
    const box=[...document.querySelectorAll('#scenarios article')].find(n=>n.dataset.id===d.id);
    const holder=box?.querySelector('.steps');
    if(holder&&!holder.hidden)fillSteps(holder,d.uri,d.steps);
  }
  if(m.kind==='definitions'){definitions=d;renderDefinitions();}
  if(m.kind==='running'){
    runId=d.id;errors=[];renderErrors();$('live').replaceChildren();
    notice(d.debug?`Debugging: the run pauses before each step. Press ${stepKey} for the next step.`:'Running scenarios. Use /fft to view progress or stop.',false,true);
  }
  if(m.kind==='errors'&&d.id===runId&&!(report&&report.id===runId)){errors.push(...d.entries);renderErrors();}
  if(m.kind==='progress'){ $('live').replaceChildren();renderScenario(d,$('live')); }
  if(m.kind==='history'){pastRuns=Array.isArray(d)?d:[];renderPastRuns();}
  if(m.kind==='pastReport'){loadReport(d);renderPastRuns();tab('results');notice(`Loaded report ${d.uuid}.`);}
  if(m.kind==='report'){
    finishedRun=d.id||null;setStatus(null);
    loadReport(d);tab('results');
    const failed=d.scenarios.flatMap(s=>s.steps||[]).filter(step=>step.status==='failed'||step.status==='timed_out');
    const tail=failed.length?` First failure: ${failed[0].text} — ${failure(failed[0].error)}`:d.error?` ${failure(d.error)}`:'';
    notice(`Run ${d.status}.${tail}`,d.status!=='passed');
  }
  if(m.kind==='recordStarted'){ $('indicator').hidden=false;notice('Recording gameplay.'); }
  if(m.kind==='recordStopped')$('indicator').hidden=true;
  if(m.kind==='recording'){
    $('indicator').hidden=true;tab('writer');setDraft(d.draft);$('timelineBox').open=true;
    $('timeline').replaceChildren(...(d.events.length?d.events.map(e=>{const n=node('li',`${(e.time/1000).toFixed(1)}s · ${e.kind} · ${e.authority}`);n.append(node('pre',JSON.stringify(e.data)));return n;}):[node('li','No events were recorded.','muted')]));
    notice(d.truncated?'Recording reached its event limit; review the incomplete draft.':'Draft ready. Review assertions, reduce steps, then validate.',!!d.truncated);
  }
  if(m.kind==='validation'){
    validatedText=$('draft').value;
    const problems=d.reduce((n,s)=>n+s.steps.filter(x=>x.error).length,0);
    $('validation').replaceChildren(...d.flatMap(s=>[node('h3',s.name),...s.steps.map(x=>node('div',x.error?`✗ ${x.error}: ${x.text}`:`✓ ${x.realm}: ${x.text}`,x.error?'failed':'passed'))]));
    $('draftScenario').replaceChildren(new Option('All draft scenarios',''),...d.map(s=>new Option(s.name,s.id)));
    if(!d.length){draftState('No scenarios found','invalid');notice('The draft has no scenarios.',true);}
    else if(problems){draftState(plural(problems,'problem'),'invalid');notice(`${plural(problems,'step')} undefined or ambiguous. Insert steps from the catalogue.`,true);}
    else{draftState(`Valid · ${plural(d.length,'scenario')}`,'valid');notice('Draft is valid. Replay or debug it.');}
  }
  if(m.kind==='feedback'){$('feedbackBox').hidden=true;$('feedbackText').value='';notice(`Feedback saved on the server: fft/${d}`);}
});

// ---- Controls ---------------------------------------------------------------------
document.querySelectorAll('[data-tab]').forEach(n=>n.onclick=()=>tab(n.dataset.tab));
$('close').onclick=()=>action('close');
document.addEventListener('keydown',e=>{
  if(e.key!=='Escape')return;
  if(!$('feedbackBox').hidden)$('feedbackBox').hidden=true;else action('close');
});
$('refresh').onclick=()=>{notice('Loading tests…',false,true);action('list');};
$('search').addEventListener('input',()=>{clearTimeout(searchTimer);searchTimer=setTimeout(applyFilter,350);});
$('tags').addEventListener('keydown',e=>{if(e.key==='Enter')applyFilter();});
$('tags').addEventListener('change',applyFilter);
$('runAll').onclick=()=>{const {query,tags}=filterInputs();action('run',{tags,search:query});};
document.querySelectorAll('.stop').forEach(n=>n.onclick=()=>action('stop'));
// Steps act on the game, so stepping hands focus back to it.
$('stepNext').onclick=()=>{action('close');action('continue');};
$('stepAll').onclick=()=>{action('close');action('continue',{all:true});};

$('fixture').onclick=()=>action('fixture');$('recordStart').onclick=()=>action('record');
$('newFeature').onclick=()=>{
  const current=$('draft').value;
  if(current.trim()&&current!==TEMPLATE&&!discardArmed){
    $('newFeature').textContent='Discard current draft?';
    discardArmed=setTimeout(()=>{discardArmed=null;$('newFeature').textContent='New feature';},4000);
    return;
  }
  clearTimeout(discardArmed);discardArmed=null;$('newFeature').textContent='New feature';
  setDraft(TEMPLATE);$('draft').focus();notice('New feature started.');
};
$('draft').addEventListener('input',draftChanged);
$('draft').addEventListener('keydown',e=>{
  if(e.key!=='Tab'||e.shiftKey)return;
  e.preventDefault();const a=$('draft'), at=a.selectionStart;
  a.value=a.value.slice(0,at)+'  '+a.value.slice(a.selectionEnd);a.setSelectionRange(at+2,at+2);draftChanged();
});
$('validate').onclick=()=>action('validate',{text:$('draft').value});
$('replay').onclick=()=>runDraft(false);$('debugDraft').onclick=()=>runDraft(true);
$('copyDraft').onclick=()=>copy($('draft').value);$('copyFixture').onclick=()=>copy($('fixtureText').textContent);
$('exportDraft').onclick=()=>exportText('draft.feature',$('draft').value);
$('stepSearch').addEventListener('input',renderDefinitions);

const stamp=()=>(report?.uuid||report?.stamp||runId||'run').replaceAll(':','-');
$('pastRuns').onchange=e=>{
  const uuid=e.target.value;
  if(!uuid||uuid===report?.uuid)return;
  if(status){notice('Wait for the current run to finish before loading a past report.',true);renderPastRuns();return;}
  notice('Loading report…',false,true);action('loadReport',{uuid});
};
$('exportReport').onclick=()=>report?exportText(`fft-${stamp()}.json`,JSON.stringify(report,null,2)):notice('No report yet.');
$('copyReport').onclick=()=>report?copy(JSON.stringify(report,null,2)):notice('No report yet.');
$('resultFilter').onchange=renderReport;
$('exportErrors').onclick=()=>errors.length?exportText(`fft-${stamp()}-errors.log`,errorLogText()):notice('No errors recorded.');
$('copyErrors').onclick=()=>errors.length?copy(errorLogText()):notice('No errors recorded.');
$('errorFilter').onchange=renderErrors;

$('feedback').onclick=()=>{$('feedbackBox').hidden=false;$('feedbackText').focus();};
$('feedbackCancel').onclick=()=>{$('feedbackBox').hidden=true;};
$('feedbackSend').onclick=()=>$('feedbackText').value.trim()?action('feedback',{text:$('feedbackText').value}):notice('Write some feedback first.',true);

$('draft').value=store.get('fft.draft')||TEMPLATE;
