'use strict';
const $ = (selector, root = document) => root.querySelector(selector);
const main = $('#main');
const state = { docs: [], archives: [], archiveMode: false, token: '', dirty: false, search: '', group: '全部', date: localDate(), selected: new Set(), graphFocus: '数据.md#unit-swordsman' };
const statusNames = ['待安排', '进行中', '待验收', '已完成', '阻塞', '取消'];
const icons = { unit: '⚔', building: '⌂', tag: '#', task: '☑', issue: '!', journal: '◷' };
const labels = { today: '今日工作台', library: '知识库', tasks: '任务与问题', graph: '关联地图', units: '单位对比', journal: '开发日历' };
function localDate() { const d = new Date(); return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`; }
function esc(v) { return String(v ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])); }
function doc(path) { return [...state.docs,...state.archives].find(d => d.path === path); }
function docLink(path) { return '#doc=' + encodeURIComponent(path); }
function bare(content) { return content.replace(/^---\r?\n[\s\S]*?\r?\n---(?:\r?\n|$)/, '').replace(/<!-- record\r?\n[\s\S]*?-->/g,'').replace(/<!-- 配置快照(?:开始|结束) -->/g,''); }
function excerpt(d, max = 95) { return bare(d.content).replace(/```[\s\S]*?```/g,'').replace(/\{#[a-z0-9-]+\}/g,'').replace(/[#*`>|]/g,'').replace(/\[([^\]]+)\]\([^)]+\)/g,'$1').replace(/\s+/g,' ').trim().slice(0,max); }
function group(d) { return d.file ? d.file.replace('.md','')+'条目' : d.path.includes('/') ? '归档' : d.path.replace('.md',''); }
function normalized(base, target) {
  const parts = (base.slice(0, base.lastIndexOf('/')+1) + target).split('/'), result = [];
  for (const p of parts) { if (p === '..') { if (result.length && result.at(-1) !== '..') result.pop(); else result.push(p); } else if (p && p !== '.') result.push(p); }
  return result.join('/');
}
function resolveLink(base, url) {
  let value; try { value = decodeURIComponent(url.replace(/^<|>$/g,'')); } catch { return {type:'invalid'}; }
  if (/^https?:\/\//i.test(value)) return {type:'external', value};
  const baseFile=base.split('#')[0];
  if (value.startsWith('#')) { const target=baseFile+value;return doc(target)?{type:'doc',value:target}:{type:'anchor',value}; }
  if (/^[a-z]+:/i.test(value) || value.startsWith('/')) return {type:'invalid'};
  const [path, anchor] = value.split('#');
  const resolved = normalized(baseFile,path);
  if(anchor&&doc(resolved+'#'+anchor))return {type:'doc',value:resolved+'#'+anchor};
  if(resolved.startsWith('归档/'))return {type:'doc',value:resolved,anchor};
  if (doc(resolved)) return {type:'doc', value:resolved, anchor};
  const sourceBase=baseFile.startsWith('归档/')?baseFile.slice(3):baseFile;
  return {type:'source', value:normalized('docs/'+sourceBase,path)};
}
function linked(base, title, url) {
  const link = resolveLink(base, url);
  if (link.type === 'doc') return `<a href="${esc(docLink(link.value))}"${link.anchor ? ` data-anchor="${esc(link.anchor)}"` : ''}>${esc(title)}</a>`;
  if (link.type === 'external') return `<a href="${esc(link.value)}" target="_blank" rel="noopener noreferrer">${esc(title)} ↗</a>`;
  if (link.type === 'anchor') return `<a href="${esc(link.value)}" data-in-page="true">${esc(title)}</a>`;
  if (link.type === 'source') return `<button class="text-link" data-source="${esc(link.value)}">${esc(title)} ↗</button>`;
  return esc(title);
}
function inline(text, base) {
  const slots = [];
  const hold = html => { slots.push(html); return `\u0000${slots.length-1}\u0000`; };
  let value = text.replace(/`([^`]+)`/g, (_, code) => hold(`<code>${esc(code)}</code>`));
  value = value.replace(/!?\[([^\]]+)\]\(([^)]+)\)/g, (_, label, url) => hold(linked(base,label,url)));
  value = esc(value).replace(/\*\*([^*]+)\*\*/g,'<strong>$1</strong>').replace(/\*([^*]+)\*/g,'<em>$1</em>').replace(/~~([^~]+)~~/g,'<del>$1</del>');
  return value.replace(/\u0000(\d+)\u0000/g, (_, i) => slots[Number(i)]);
}
function markdown(content, base) {
  const lines = bare(content).replace(/\r/g,'').split('\n'), output = [];
  let i = 0;
  const row = line => line.trim().replace(/^\||\|$/g,'').split(/(?<!\\)\|/).map(s => s.trim());
  while (i < lines.length) {
    const line = lines[i];
    if (!line.trim()) { i++; continue; }
    if (/^```/.test(line)) {
      const code = []; i++; while (i < lines.length && !/^```/.test(lines[i])) code.push(lines[i++]); i++;
      output.push(`<pre><code>${esc(code.join('\n'))}</code></pre>`); continue;
    }
    const heading = /^(#{1,6})\s+(.+)$/.exec(line);
    if (heading) { const level = heading[1].length,anchor=/^(.*?) \{#([a-z0-9-]+)\}$/.exec(heading[2]); output.push(`<h${level} id="${esc(anchor?anchor[2]:heading[2].toLowerCase().replace(/\s+/g,'-'))}">${inline(anchor?anchor[1]:heading[2],base)}</h${level}>`); i++; continue; }
    if (line.includes('|') && i+1 < lines.length && /^\s*\|?\s*:?-{3,}/.test(lines[i+1])) {
      const headings = row(line); i += 2; const rows = [];
      while (i < lines.length && lines[i].includes('|') && lines[i].trim()) rows.push(row(lines[i++]));
      output.push(`<div class="table-scroll"><table><thead><tr>${headings.map(c=>`<th>${inline(c,base)}</th>`).join('')}</tr></thead><tbody>${rows.map(r=>`<tr>${r.map(c=>`<td>${inline(c,base)}</td>`).join('')}</tr>`).join('')}</tbody></table></div>`); continue;
    }
    if (/^\s*(?:[-*+] |\d+\. )/.test(line)) {
      const ordered = /^\s*\d+\./.test(line), items = [];
      while (i < lines.length && /^\s*(?:[-*+] |\d+\. )/.test(lines[i])) {
        let item = lines[i++].replace(/^\s*(?:[-*+] |\d+\. )/,'');
        item = item.replace(/^\[([ xX])\] /, (_, checked)=> checked === ' ' ? '☐ ' : '☑ ');
        items.push(`<li>${inline(item,base)}</li>`);
      }
      output.push(`<${ordered?'ol':'ul'}>${items.join('')}</${ordered?'ol':'ul'}>`); continue;
    }
    if (/^>/.test(line)) { output.push(`<blockquote>${inline(line.replace(/^>\s?/,''),base)}</blockquote>`); i++; continue; }
    if (/^---+$/.test(line)) { output.push('<hr>'); i++; continue; }
    const paragraph = [line]; i++;
    while (i < lines.length && lines[i].trim() && !/^(#{1,6}\s|```|>|\s*[-*+] |\s*\d+\. )/.test(lines[i]) && !(lines[i].includes('|') && /^\s*\|?\s*:?-{3,}/.test(lines[i+1]||''))) paragraph.push(lines[i++]);
    output.push(`<p>${inline(paragraph.join(' '),base)}</p>`);
  }
  return output.join('');
}
function connections(d) {
  const found = new Set(), content = bare(d.content).replace(/```[\s\S]*?```/g,'');
  for (const m of content.matchAll(/(?<!!)\[[^\]]+\]\(([^)]+)\)/g)) {
    const link = resolveLink(d.path,m[1]); if (link.type === 'doc' && link.value !== d.path) found.add(link.value);
  }
  return [...found];
}
function backlinks(path) { return state.docs.filter(d=>connections(d).includes(path)); }
function pill(value, cls='') { return `<span class="pill ${esc(cls)}">${esc(value)}</span>`; }
function pageTitle(kicker, title, description, action='') { return `<div class="page-title"><div><div class="eyebrow">${esc(kicker)}</div><h1>${esc(title)}</h1><p>${esc(description)}</p></div>${action}</div>`; }
function card(d) { return `<a class="doc-card" href="${docLink(d.path)}"><span class="card-symbol">${icons[d.meta.kind]||'▤'}</span><div>${pill(group(d))}<h3>${esc(d.title)}</h3><p>${esc(excerpt(d))}</p><small>${esc(d.path)}</small></div><span class="card-arrow">↗</span></a>`; }
function toast(message, error=false) { const el = $('#toast'); el.textContent = message; el.className = 'visible'+(error?' error':''); clearTimeout(state.toastTimer); state.toastTimer = setTimeout(()=>el.className='',6000); }
async function api(path, body) {
  const response = await fetch(path, body ? {method:'POST',headers:{'Content-Type':'application/json','X-Workbench-Token':state.token},body:JSON.stringify(body)} : {});
  const result = await response.json();
  if (!response.ok) { const error = new Error(result.error || '请求失败'); error.status = response.status; error.current = result.current; throw error; }
  return result;
}
async function save(path, content, rev) {
  const result = await api('/api/save',{path,content,revision:rev});
  await refresh();
  state.dirty = false; toast('已保存到 Markdown'); return result;
}
async function refresh() {
  const result = await api('/api/workspace'); state.docs = [...result.documents,...result.entries]; state.token = result.token;
  $('#project-name').textContent = result.name; document.title = result.name+' · 开发手记';
}
function mayLeave() { return !state.dirty || window.confirm('当前有未保存的修改。放弃草稿并切换？'); }
function openCreate() { if(!mayLeave())return;state.dirty=false;render();$('#create-dialog').showModal(); }
function setDirty() { state.dirty = true; const button = $('#save-doc'); if (button) button.textContent = '保存修改 ●'; }
function dailyPath() { return `日志.md#day-${state.date}`; }
const dailySections = ['助手总结','我的复盘','验证与遗留','明日计划'];
function section(content, heading) {
  const match = new RegExp('^## '+heading+'\\r?\\n([\\s\\S]*?)(?=^## |$(?![\\s\\S]))','m').exec(content);
  return match ? match[1].trim() : '';
}
function replaceSection(content, heading, value) {
  const re = new RegExp('(^## '+heading+'\\r?\\n)[\\s\\S]*?(?=^## |$(?![\\s\\S]))','m');
  if (re.test(content)) return content.replace(re, () => `## ${heading}\n\n${value.trim()}\n\n`);
  return content.trimEnd()+`\n\n## ${heading}\n\n${value.trim()}\n`;
}
function dailyEditor() {
  const current = doc(dailyPath());
  return `<section class="panel daily-panel"><div class="panel-heading"><div><h2>收工复盘</h2><p>助手先写总结，你再补充感受和明天的安排。</p></div><input id="day-date" type="date" value="${state.date}" aria-label="记录日期"></div><div class="daily-tabs">${dailySections.map((s,i)=>`<button class="${i===0?'active':''}" data-daily-tab="${i}">${String(i+1).padStart(2,'0')} ${s}</button>`).join('')}</div>${dailySections.map((s,i)=>`<div class="daily-section ${i===0?'active':''}" data-daily-section="${i}"><label>${s}<textarea rows="7" id="daily-${i}" placeholder="${['由助手依据今天实际工作填写；没有记录时留空。','今天有什么体会？哪些地方需要调整？','测试方式、结果和仍未确认的事情。','下一次先做什么？写下目标和完成条件。'][i]}">${esc(section(current?.content||'',s))}</textarea></label></div>`).join('')}<div class="panel-bottom"><span>${current?'已有记录，可继续补充':'尚未创建，填写后保存'} · <code>${esc(dailyPath())}</code></span><button class="primary" id="save-daily">保存收工记录</button></div></section>`;
}
function bindDaily() {
  const baseline = doc(dailyPath());
  const revision = baseline?.revision ?? doc('日志.md')?.revision ?? null, original = baseline?.content || `---\nkind: journal\ndate: ${state.date}\n---\n\n# ${state.date} 开发记录\n`;
  $('#day-date').onchange = e => { if (!mayLeave()) { e.target.value=state.date; return; } state.date=e.target.value||localDate(); state.dirty=false; render(); };
  document.querySelectorAll('[data-daily-tab]').forEach(b=>b.onclick=()=>{ document.querySelectorAll('[data-daily-tab],[data-daily-section]').forEach(x=>x.classList.remove('active')); b.classList.add('active'); $(`[data-daily-section="${b.dataset.dailyTab}"]`).classList.add('active'); });
  dailySections.forEach((_,i)=>$('#daily-'+i).oninput=setDirty);
  $('#save-daily').onclick = async e => {
    e.target.disabled=true; let content=original;
    dailySections.forEach((heading,i)=>content=replaceSection(content,heading,$('#daily-'+i).value));
    try { await save(dailyPath(),content,revision); render(); } catch (error) { showSaveError(error); } finally { if(e.target.isConnected)e.target.disabled=false; }
  };
}
function showSaveError(error) {
  toast(error.message,true);
  if (error.status===409) {
    $('#source-title').textContent='外部已更新的原文 · 请与当前草稿合并';
    $('#source-content').innerHTML=`<p class="notice">当前草稿保留在原页面。关闭此窗口后可复制草稿，再刷新读取最新文件。</p><pre>${esc(error.current?.content || '文件已被删除。')}</pre>`;
    $('#source-dialog').showModal();
  }
}
function today() {
  const tasks = state.docs.filter(d=>['task','issue'].includes(d.meta.kind));
  const active = tasks.filter(d=>!['已完成','取消'].includes(d.meta.status));
  const day = new Date(state.date+'T12:00:00').toLocaleDateString('zh-CN',{month:'long',day:'numeric',weekday:'long'});
  main.innerHTML = pageTitle('DAILY WORKSPACE', '把今天的进展留下来', `${day} · 今天的记录，是明天开始的地方。`, `<a class="button" href="${docLink('项目.md')}">查看当前工作 ↗</a>`)+
    `<div class="stats"><div><span>项目资料</span><strong>${state.docs.filter(d=>!d.file).length}<small>份 Markdown</small></strong></div><div><span>未完成事项</span><strong>${active.length}<small>项任务与问题</small></strong></div><div><span>数据实体</span><strong>${state.docs.filter(d=>d.file==='数据.md').length}<small>个关联节点</small></strong></div><div><span>每日记录</span><strong>${state.docs.filter(d=>d.meta.kind==='journal').length}<small>天已有记录</small></strong></div></div>`+
    `<div class="dashboard-grid"><div>${dailyEditor()}<section class="panel"><div class="panel-heading"><h2>常用入口</h2><a href="#library">全部资料 →</a></div><div class="quick-links">${[['系统.md','游戏系统','先看各系统怎样连接'],['任务.md','任务与待验收','已有实现，还缺哪些验证'],['决策.md','设计决策','保留现在这样做的原因'],['参考.md','参考与归档','按需回查旧资料']].filter(([p])=>doc(p)).map(([p,t,s])=>`<a href="${docLink(p)}"><strong>${t} ↗</strong><span>${s}</span></a>`).join('')}</div></section></div><aside class="dashboard-aside"><section class="panel"><div class="panel-heading"><h2>当前事项</h2><button class="text-link" id="new-task">＋ 新增</button></div>${active.length?active.slice(0,5).map(d=>`<a class="task-preview" href="${docLink(d.path)}">${pill(d.meta.status||'待安排')}<h3>${esc(d.title)}</h3><span>${esc(d.meta.id||'')} · ${esc(d.meta.verification||'未验证')}</span></a>`).join(''):'<p class="empty">还没有结构化任务，可以先记录一项。</p>'}<a class="panel-more" href="#tasks">查看任务看板 →</a></section><section class="relationship-teaser"><span class="eyebrow">CONNECTED KNOWLEDGE</span><h2>数据不再是孤立的数字</h2><div class="mini-chain"><span>剑士</span><i>↔</i><span>剑士营</span><i>↔</i><span>主动迎战</span></div><p>从单位出发，找到训练建筑、标签和相关系统规则。</p><a href="#graph">探索关联地图 →</a></section><div class="daily-tip"><span>✧</span><p>记录完成程度，也记录证据。<br>“写完代码”与“试玩通过”可以是两件事。</p></div></aside></div>`;
  bindDaily(); $('#new-task').onclick=openCreate;
}
function library() {
  const source=state.archiveMode?state.archives:state.docs.filter(d=>!d.file);
  const groups=['全部',...new Set(source.map(group))];
  const filtered=source.filter(d=>(state.group==='全部'||group(d)===state.group)&&(!state.search||(d.title+' '+d.content).toLowerCase().includes(state.search.toLowerCase())));
  main.innerHTML=pageTitle('PROJECT KNOWLEDGE',state.archiveMode?'归档资料':'知识库',state.archiveMode?'保留原文，只读回查。旧状态不能自动成为当前任务。':'固定七份主文档。单位、任务和每日记录都保存在文档内部。',`<button id="archive-toggle" class="button">${state.archiveMode?'← 返回七份主文档':'查看归档资料'}</button>`)+`<div class="library-tools"><input id="library-search" placeholder="⌕ 搜索标题或正文" value="${esc(state.search)}" aria-label="筛选资料"><span>${filtered.length} 份资料</span></div><div class="filter-chips">${groups.map(g=>`<button data-group="${esc(g)}" class="${g===state.group?'active':''}">${esc(g)}</button>`).join('')}</div><div class="document-grid">${filtered.map(card).join('')||'<div class="empty">没有匹配的资料。</div>'}</div>`;
  $('#library-search').oninput=e=>{state.search=e.target.value;const start=e.target.selectionStart;library();$('#library-search').focus();$('#library-search').setSelectionRange(start,start);};
  document.querySelectorAll('[data-group]').forEach(b=>b.onclick=()=>{state.group=b.dataset.group;library();});
  $('#archive-toggle').onclick=async()=>{try{if(!state.archiveMode){const r=await api('/api/archive');state.archives=r.documents;}state.archiveMode=!state.archiveMode;state.group='全部';state.search='';library();}catch(error){toast(error.message,true);}};
}

function documentView(path) {
  if(path.startsWith('归档/')&&!doc(path)){api('/api/archive').then(r=>{state.archives=r.documents;if(location.hash===docLink(path))documentView(path);}).catch(e=>toast(e.message,true));main.innerHTML='<div class="empty">读取归档原文…</div>';return;}
  const d = doc(path); if (!d) { main.innerHTML=pageTitle('DOCUMENT','没有找到这份文档',path)+`<a href="#library">返回知识库</a>`; return; }
  const outgoing=connections(d).map(doc), incoming=backlinks(path);
  main.innerHTML=`<div class="document-toolbar"><a href="#library">← 知识库</a><span>${esc(d.path)}</span><div><button id="read-mode" class="active">阅读</button><button id="edit-mode">编辑 MD</button><button id="save-doc" class="primary" hidden>保存修改</button></div></div><div class="reading-grid"><section class="panel document-panel"><div id="document-reading" class="prose">${markdown(d.content,d.path)}</div><div id="document-editing" hidden><p class="notice">直接编辑原 Markdown；保存前会检查外部修改。</p><textarea id="md-editor" spellcheck="false" aria-label="Markdown 正文">${esc(d.content)}</textarea><div id="edit-preview" class="prose"></div></div></section><aside><section class="panel related-panel"><div class="eyebrow">CONNECTIONS</div><h2>与这份资料相连</h2><h4>引用了 ${outgoing.length} 份资料</h4>${outgoing.map(x=>`<a href="${docLink(x.path)}">${esc(x.title)} ↗</a>`).join('')||'<p>暂无文档链接</p>'}<h4>被 ${incoming.length} 份资料引用</h4>${incoming.map(x=>`<a href="${docLink(x.path)}">${esc(x.title)} ↗</a>`).join('')||'<p>暂无反向引用</p>'}<button id="doc-graph" class="button">在关联地图中查看</button></section><div class="file-note">${pill(d.meta.kind||group(d))}<p>最近文件修改<br>${new Date(d.modified*1000).toLocaleString('zh-CN')}</p><p>页面内容来自当前文件，不另存一套正文。</p></div></aside></div>`;
  const readonly=d.readonly||d.meta.generated; if(readonly){$('#edit-mode').disabled=true;$('#edit-mode').textContent=d.readonly?'归档只读':'配置快照只读';}
  let editing=false;
  function mode(value) { editing=value; $('#document-reading').hidden=value; $('#document-editing').hidden=!value; $('#save-doc').hidden=!value; $('#read-mode').classList.toggle('active',!value); $('#edit-mode').classList.toggle('active',value); if(!value) $('#document-reading').innerHTML=markdown($('#md-editor').value,path); }
  $('#read-mode').onclick=()=>mode(false); $('#edit-mode').onclick=()=>mode(true);
  $('#md-editor').oninput=()=>{setDirty();$('#edit-preview').innerHTML=markdown($('#md-editor').value,path);};
  $('#save-doc').onclick=async e=>{e.target.disabled=true;try{await save(path,$('#md-editor').value,d.revision);documentView(path);if(editing)$('#edit-mode').click();}catch(error){showSaveError(error);}finally{if(e.target.isConnected)e.target.disabled=false;}};
  $('#doc-graph').onclick=()=>{if(!mayLeave())return;state.dirty=false;state.graphFocus=path;location.hash='graph';};
}
function tasks() {
  const entries=state.docs.filter(d=>['task','issue'].includes(d.meta.kind));
  main.innerHTML=pageTitle('TASKS & ISSUES','把下一步变得清楚','只记录已选择的事项；历史问题仍可在原知识库中查证。','<button class="primary" id="new-task">＋ 记录事项</button>')+`<div class="kanban">${['待安排','进行中','待验收','已完成'].map(status=>`<section class="kanban-column"><h2><i class="status-dot ${status==='已完成'?'done':''}"></i>${status}<span>${entries.filter(d=>d.meta.status===status).length}</span></h2>${entries.filter(d=>d.meta.status===status).map(taskCard).join('')||'<div class="kanban-empty">暂无事项</div>'}</section>`).join('')}</div>${entries.some(d=>['阻塞','取消'].includes(d.meta.status))?`<section class="panel"><h2>阻塞与取消</h2>${entries.filter(d=>['阻塞','取消'].includes(d.meta.status)).map(taskCard).join('')}</section>`:''}<p class="muted">进度与验证分开记录。切换“已完成”不会自动把验证结果改为通过。</p>`;
  $('#new-task').onclick=openCreate;
  document.querySelectorAll('[data-task-status]').forEach(el=>el.onchange=async()=>{
    const d=doc(el.dataset.taskStatus), previous=d.meta.status, next=el.value;
    const content=d.content.replace(/^status:.*$/m,'status: '+next);
    el.disabled=true;try{await save(d.path,content,d.revision);tasks();}catch(error){el.value=previous;showSaveError(error);}finally{if(el.isConnected)el.disabled=false;}
  });
}
function taskCard(d) { return `<article class="task-card"><div class="task-meta">${esc(d.meta.id||'')} ${pill(d.meta.kind==='issue'?'问题':'任务')}</div><a href="${docLink(d.path)}"><h3>${esc(d.title)}</h3></a><p>${esc(excerpt(d,80))}</p><div class="verification">验证：${esc(d.meta.verification||'未验证')}</div><select aria-label="${esc(d.title)}的状态" data-task-status="${esc(d.path)}">${statusNames.map(s=>`<option ${s===d.meta.status?'selected':''}>${s}</option>`).join('')}</select></article>`; }
function graph() {
  const center=doc(state.graphFocus)||doc('项目.md')||state.docs[0]; if(!center)return;
  const outgoing=connections(center), incoming=backlinks(center.path).map(d=>d.path);
  const related=[...new Set([...outgoing,...incoming])], nodes=related.slice(0,18).map(doc), width=880,height=600;
  const positions=nodes.map((d,i)=>({d,x:440+Math.cos(-Math.PI/2+2*Math.PI*i/nodes.length)*300,y:300+Math.sin(-Math.PI/2+2*Math.PI*i/nodes.length)*225}));
  main.innerHTML=pageTitle('CONNECTED KNOWLEDGE','关联地图','链接来自 Markdown 正文。点击节点切换中心，沿关联追踪数据和规则。')+`<div class="graph-layout"><section class="panel graph-panel"><div class="graph-controls"><select id="graph-select" aria-label="选择中心节点">${state.docs.map(d=>`<option value="${esc(d.path)}" ${d.path===center.path?'selected':''}>${esc(d.title)}</option>`).join('')}</select><span>${related.length} 个直接关联${related.length>18?' · 展示前18个':''}</span></div><svg class="graph-svg" viewBox="0 0 ${width} ${height}" role="img" aria-label="${esc(center.title)}的直接关联图"><defs><pattern id="grid" width="24" height="24" patternUnits="userSpaceOnUse"><circle cx="1" cy="1" r="1" fill="#d8e0db"/></pattern></defs><rect width="880" height="600" fill="url(#grid)"/>${positions.map(({d,x,y})=>`<line x1="440" y1="300" x2="${x}" y2="${y}" stroke="${outgoing.includes(d.path)?'#b5cdc2':'#ced6e2'}" stroke-width="1.5"/>`).join('')}${positions.map(({d,x,y})=>`<g class="graph-node ${esc(d.meta.kind||'document')}" data-node="${esc(d.path)}" transform="translate(${x},${y})" tabindex="0" role="button" aria-label="${esc(d.title)}"><circle r="26"/><text y="5" text-anchor="middle" class="node-icon">${icons[d.meta.kind]||'▤'}</text><text y="47" text-anchor="middle" class="node-label">${esc(d.title.length>15?d.title.slice(0,14)+'…':d.title)}</text></g>`).join('')}<g class="graph-center" transform="translate(440,300)"><circle r="47"/><text y="-5" text-anchor="middle">${icons[center.meta.kind]||'▤'}</text><text y="16" text-anchor="middle" class="center-label">${esc(center.title.length>10?center.title.slice(0,9)+'…':center.title)}</text></g></svg><div class="graph-legend"><span><i class="dot"></i>实体／当前中心</span><span>绿色连线：引用 →</span><span>灰色连线：反向引用 ←</span></div></section><aside class="panel graph-detail"><span class="eyebrow">SELECTED NODE</span><h2>${esc(center.title)}</h2>${pill(center.meta.kind||group(center))}<p>${esc(excerpt(center,180))}</p><a class="button primary" href="${docLink(center.path)}">打开资料 ↗</a><h4>直接关联</h4>${related.map(p=>`<button class="related-node" data-node="${esc(p)}"><span>${icons[doc(p).meta.kind]||'▤'}</span>${esc(doc(p).title)} <small>${outgoing.includes(p)?'引用':'被引用'}</small></button>`).join('')||'<p>在正文中添加 Markdown 链接，即可建立关联。</p>'}</aside></div>`;
  $('#graph-select').onchange=e=>{state.graphFocus=e.target.value;graph();};
  document.querySelectorAll('[data-node]').forEach(el=>{ const select=()=>{state.graphFocus=el.dataset.node;graph();};el.onclick=select;el.onkeydown=e=>{if(e.key==='Enter')select();}; });
}
function units() {
  const all=state.docs.filter(d=>d.meta.kind==='unit');
  if(!state.selected.size)(all.filter(d=>['swordsman','militia','archer'].includes(d.meta.unit_id)).length?all.filter(d=>['swordsman','militia','archer'].includes(d.meta.unit_id)):all.slice(0,3)).forEach(d=>state.selected.add(d.path));
  const selected=all.filter(d=>state.selected.has(d.path));
  const fields=[['health','生命'],['attack','基础伤害'],['attack_interval','攻击间隔（秒）'],['attack_range','射程（米）'],['move_speed','移速（米／秒）']];
  main.innerHTML=pageTitle('UNIT COMPARISON','看清每个单位的差异','读取单位 Markdown 的基础配置快照；特性、增益和实战命中不计入比较。')+`<div class="filter-chips">${all.map(d=>`<label class="unit-toggle"><input type="checkbox" data-unit="${esc(d.path)}" ${state.selected.has(d.path)?'checked':''}>${esc(d.title)}</label>`).join('')}</div><div class="unit-cards">${selected.map(d=>`<article class="panel unit-card"><div class="unit-emblem">⚔</div>${pill(d.meta.role||'战斗单位')}<h2><a href="${docLink(d.path)}">${esc(d.title)} ↗</a></h2><p>${esc(d.meta.unit_id||'')}</p><div class="unit-numbers"><div><span>生命</span><strong>${esc(d.meta.health??'—')}</strong></div><div><span>伤害</span><strong>${esc(d.meta.attack??'—')}</strong></div><div><span>射程</span><strong>${esc(d.meta.attack_range??'—')}<small> m</small></strong></div></div><div class="unit-relations">${connections(d).map(p=>`<a href="${docLink(p)}">${esc(doc(p).title)} ↗</a>`).join('')}</div><small>配置核对：${esc(d.meta.checked||'未记录')}</small></article>`).join('')}</div><section class="panel"><div class="panel-heading"><h2>基础数值对照</h2><span>来自当前 Markdown</span></div><div class="table-scroll"><table class="compare-table"><thead><tr><th>属性</th>${selected.map(d=>`<th>${esc(d.title)}</th>`).join('')}</tr></thead><tbody>${fields.map(([field,title])=>{const max=Math.max(...selected.map(d=>Number(d.meta[field])||0));return `<tr><td>${title}</td>${selected.map(d=>`<td><span>${esc(d.meta[field]??'—')}</span><div class="value-track"><i style="width:${max?Math.max(0,Number(d.meta[field])||0)/max*100:0}%"></i></div></td>`).join('')}</tr>`;}).join('')}<tr><td>理论伤害／秒</td>${selected.map(d=>`<td>${Number(d.meta.attack_interval)>0?(Number(d.meta.attack)/Number(d.meta.attack_interval)).toFixed(2):'—'}</td>`).join('')}</tr></tbody></table></div><p class="muted">理论伤害／秒仅为伤害 ÷ 间隔，不能代表实战强弱。横条只比较数值大小，不表示越大越好。修改这些 MD 不会修改 Godot 配置。</p></section>`;
  document.querySelectorAll('[data-unit]').forEach(el=>el.onchange=()=>{if(el.checked)state.selected.add(el.dataset.unit);else state.selected.delete(el.dataset.unit);if(!state.selected.size){toast('至少保留一个单位');state.selected.add(el.dataset.unit);}units();});
}
function journal() {
  const logs=state.docs.filter(d=>d.meta.kind==='journal').sort((a,b)=>String(b.meta.date).localeCompare(String(a.meta.date)));
  main.innerHTML=pageTitle('DEVELOPMENT JOURNAL','开发日历','每一天保留助手总结、你的复盘和下一步。','<button class="primary" id="today-journal">填写今天的记录</button>')+`<div class="journal-layout"><section class="journal-list">${logs.map(d=>`<a class="journal-entry" href="${docLink(d.path)}"><div class="journal-date"><strong>${esc(String(d.meta.date).slice(8))}</strong><span>${esc(String(d.meta.date).slice(0,7))}</span></div><div><h2>${esc(d.title)}</h2><p>${esc(section(d.content,'助手总结').replace(/[#*\n]/g,' ').slice(0,130)||'尚未填写助手总结')}</p><span>查看当天记录 →</span></div></a>`).join('')||'<section class="panel empty">还没有按日期建立的记录。先从今天开始。</section>'}</section><aside class="panel"><h2>收工的四个问题</h2><ol class="journal-guide"><li>今天完成了什么？</li><li>你有什么体会？</li><li>哪些已经验证，哪些还没有？</li><li>明天先做哪一件事？</li></ol><p class="muted">旧开发日志保留在归档；新日记按日期追加到同一份日志.md。</p><a href="${docLink('日志.md')}">打开完整日志.md ↗</a></aside></div>`;
  $('#today-journal').onclick=()=>{state.date=localDate();location.hash='today';};
}
function render() {
  const hash=location.hash.slice(1)||'today', route=hash.startsWith('doc=')?'doc':hash;
  state.lastHash=location.hash;
  $('#crumb').textContent=route==='doc'?'文档阅读':labels[route]||'今日工作台';
  document.querySelectorAll('[data-nav]').forEach(a=>a.classList.toggle('active',a.dataset.nav===(route==='doc'?'library':route)));
  if(route==='doc'){let path;try{path=decodeURIComponent(hash.slice(4));}catch{path='';}documentView(path);}
  else ({today,library,tasks,graph,units,journal}[route]||today)();
}
async function showSource(path) {
  try { const source=await api('/api/source?path='+encodeURIComponent(path)); $('#source-title').textContent=path+' · 只读'; $('#source-content').innerHTML=path.endsWith('.md')?`<article class="prose">${markdown(source.content,'../'+path)}</article>`:`<pre>${esc(source.content)}</pre>`; $('#source-dialog').showModal(); }catch(error){toast(error.message,true);}
}
document.addEventListener('click',e=>{
  const source=e.target.closest('[data-source]'); if(source){showSource(source.dataset.source);return;}
  const close=e.target.closest('[data-close]');if(close){close.closest('dialog').close();return;}
  const anchor=e.target.closest('[data-in-page]');if(anchor){e.preventDefault();document.getElementById(anchor.getAttribute('href').slice(1))?.scrollIntoView();return;}
  const link=e.target.closest('a[href^="#"]');if(link){if(!mayLeave()){e.preventDefault();return;}state.dirty=false;if(location.hash===link.getAttribute('href'))render();if(link.dataset.anchor)setTimeout(()=>document.getElementById(link.dataset.anchor)?.scrollIntoView(),80);}
});
window.addEventListener('hashchange',()=>{
  if(state.restoringHash){state.restoringHash=false;return;}
  if(!mayLeave()){state.restoringHash=true;location.hash=state.lastHash||'today';return;}
  state.dirty=false;render();window.scrollTo(0,0);
});
window.addEventListener('beforeunload',e=>{if(state.dirty){e.preventDefault();e.returnValue='';}});
$('#refresh').onclick=async()=>{if(!mayLeave())return;try{await refresh();state.dirty=false;render();toast('已重新读取文件');}catch(error){toast(error.message,true);}};
$('#search-open').onclick=()=>{$('#search-dialog').showModal();$('#search-input').focus();searchResults();};
function searchResults(){const query=$('#search-input').value.trim().toLowerCase();const results=state.docs.filter(d=>!query||(d.title+' '+d.content).toLowerCase().includes(query)).slice(0,30);$('#search-results').innerHTML=results.map(d=>`<a href="${docLink(d.path)}"><strong>${esc(d.title)}</strong><span>${esc(d.path)}</span></a>`).join('')||'<p class="empty">没有匹配结果</p>';$('#search-results').querySelectorAll('a').forEach(a=>a.onclick=()=>{if(!state.dirty)$('#search-dialog').close();});}
$('#search-input').oninput=searchResults;
document.addEventListener('keydown',e=>{if(e.key==='/'&&!/INPUT|TEXTAREA|SELECT/.test(e.target.tagName)&&!document.querySelector('dialog[open]')){e.preventDefault();$('#search-open').click();}});
$('#create-form').onsubmit=async e=>{
  e.preventDefault();const form=new FormData(e.target),kind=form.get('kind'),title=form.get('title').trim();if(!title)return;
  const prefix=kind==='issue'?'BUG':'TASK';
  const used=state.docs.flatMap(d=>[...d.content.matchAll(new RegExp('\\b'+prefix+'-(\\d+)\\b','g'))].map(m=>Number(m[1])));
  const number=Math.max(0,...used)+1;
  const id=prefix+'-'+String(number).padStart(3,'0'), path='任务.md#'+id.toLowerCase();
  const content=`---\nkind: ${kind}\nid: ${id}\ntitle: ${JSON.stringify(title)}\nstatus: 待安排\nverification: 未验证\ncreated: ${localDate()}\n---\n\n# ${title}\n\n## ${kind==='issue'?'现象与复现条件':'目标与范围'}\n\n${form.get('details').trim()}\n\n## 验收条件\n\n- [ ] 补充具体完成条件\n\n## 验证记录\n\n尚未验证。\n`;
  const button=$('button[type="submit"]',e.target);button.disabled=true;
  try{await save(path,content,doc('任务.md')?.revision??null);e.target.reset();$('#create-dialog').close();if(location.hash===docLink(path))render();else location.hash=docLink(path);}catch(error){showSaveError(error);}finally{button.disabled=false;}
};
refresh().then(render).catch(error=>{main.innerHTML=`<div class="empty"><h2>暂时无法连接资料</h2><p>${esc(error.message)}</p><p>请通过启动脚本打开，并保持服务窗口运行。</p></div>`;});
