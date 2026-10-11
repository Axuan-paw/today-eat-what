// T6 逻辑层独立验证 —— HP 用 Node 复现（不依赖浏览器、不装任何库）
const fs = require('fs');
const vm = require('vm');

const html = fs.readFileSync('D:/projects/today-eat-what/frontend/index.html', 'utf8');
const m = html.match(/<script>([\s\S]*?)<\/script>/);
if (!m) { console.error('未找到 script 块'); process.exit(1); }
const code = m[1];

// 用 Proxy 造一个"万能假 DOM"，任何 DOM 操作都不会让它崩
const makeAny = () => new Proxy(function () {}, {
  get(t, k) {
    if (k === Symbol.toPrimitive) return () => '';
    if (k === 'length') return 0;
    if (k === 'checked' || k === 'disabled') return false;
    if (k === 'value' || k === 'textContent' || k === 'innerHTML') return '';
    if (typeof k === 'symbol') return undefined;
    return makeAny();
  },
  set() { return true; },
  apply() { return makeAny(); },
});

const store = {};
const localStorage = {
  getItem: (k) => (k in store ? store[k] : null),
  setItem: (k, v) => { store[k] = String(v); },
  removeItem: (k) => { delete store[k]; },
  clear: () => { Object.keys(store).forEach((k) => delete store[k]); },
};

const sandbox = {
  console,
  localStorage,
  structuredClone,
  setTimeout, clearTimeout, setInterval, clearInterval,
  document: {
    getElementById: () => makeAny(),
    querySelectorAll: () => [],
    addEventListener: () => {},
  },
};
sandbox.window = sandbox;
sandbox.globalThis = sandbox;
vm.createContext(sandbox);
vm.runInContext(
  code + '\n;globalThis.__api = { recommend, scoreDish, filterDishes, mergeAvoid, state };',
  sandbox,
  { filename: 'index-script.js' }
);

const api = sandbox.__api;
const recommend = api.recommend;

const results = [];
const ok = (n, pass, note = '') => results.push({ 测试项: n, 结果: pass ? 'PASS' : 'FAIL', 备注: note });
const P0 = structuredClone(api.state.profile);
const D0 = api.state.dishes;
const reset = () => { api.state.profile = structuredClone(P0); api.state.dishes = D0; };

async function hitCount(word, n, opts, patch) {
  api.state.profile = Object.assign(structuredClone(P0), patch);
  let hit = 0;
  for (let i = 0; i < n; i++) {
    const r = await recommend(api.state.profile, api.state.dishes, opts);
    if (r.dish && (r.dish.name + ' ' + (r.dish.tags || []).join(' ')).includes(word)) hit++;
  }
  return hit;
}

(async () => {
  ok('T-5  本人硬忌口 x20', await hitCount('沙拉', 20, { history: [] }, { avoidHard: ['沙拉'] }) === 0);
  ok('T-11 搭子硬忌口 x20', await hitCount('沙拉', 20, { history: [] }, { diningCompanions: [{ name: '小明', avoid: ['沙拉'] }] }) === 0);
  ok('T-12 强制探索仍无忌口', await hitCount('沙拉', 20, { history: [], exploreRate: 1 }, { avoidHard: ['沙拉'] }) === 0);

  reset();
  let allExploit = true;
  for (let i = 0; i < 20; i++) {
    const r = await recommend(api.state.profile, api.state.dishes, { history: [], exploreRate: 0 });
    if (r.strategy !== 'exploit') allExploit = false;
  }
  ok('T-14 exploreRate=0 恒 exploit', allExploit);

  reset();
  const r19 = await recommend(api.state.profile, api.state.dishes, { history: [], exploreRate: 1 });
  ok('T-19 history 空 + 探索', r19.dish !== null && r19.strategy === 'explore', 'strategy=' + r19.strategy);

  reset();
  const r17 = await recommend(Object.assign({}, api.state.profile, { cuisine: '川湘' }), api.state.dishes, { history: ['麻辣烫'], exploreRate: 1 });
  ok('T-17 池子只剩一道 + 探索', r17.dish !== null && r17.strategy === 'exploit', 'strategy=' + r17.strategy + ' dish=' + (r17.dish && r17.dish.name));

  reset();
  const r18 = await recommend(api.state.profile, api.state.dishes, { history: api.state.dishes.map((d) => d.name), exploreRate: 1 });
  ok('T-18 全部吃过', r18.dish !== null && r18.strategy === 'exploit', 'strategy=' + r18.strategy);

  reset();
  const r6 = await recommend(Object.assign({}, api.state.profile, { budget: 1 }), api.state.dishes, { history: [] });
  ok('T-6  预算 1 元', r6.dish !== null, r6.dish ? r6.dish.name : 'null');

  reset();
  const r9 = await recommend(api.state.profile, [], { history: [] });
  ok('T-9  空菜单', r9.dish === null && r9.source === 'none', 'source=' + r9.source);

  reset();
  const r20 = await recommend(api.state.profile, [D0[0]], { history: [] });
  ok('T-20 菜单只有一道', r20.dish !== null, r20.dish ? r20.dish.name : 'null');

  reset();
  const pass = results.filter((r) => r.结果 === 'PASS').length;
  console.log(JSON.stringify(results, null, 1));
  console.log('\n合计 ' + pass + '/' + results.length + ' 通过');
  process.exit(pass === results.length ? 0 : 1);
})();
