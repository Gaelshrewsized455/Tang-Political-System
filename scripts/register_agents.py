#!/usr/bin/env python3
"""Register agents to openclaw.json and create agent configs"""
import json
import pathlib
import shutil

def main():
    cfg_path = pathlib.Path.home() / '.openclaw' / 'openclaw.json'
    cfg = json.loads(cfg_path.read_text(encoding='utf-8-sig'))
    
    OCLAW_HOME = pathlib.Path.home() / '.openclaw'
    REPO_DIR = pathlib.Path(__file__).parent.parent
    
    # Agent 配置
    AGENTS = [
        {"id": "main",     "subagents": {"allowAgents": ["emperor", "zhongshu", "menxia", "shangshu", "hubu", "libu", "bingbu", "xingbu", "gongbu", "libu_hr", "zaochao"]}},
        {"id": "emperor",  "subagents": {"allowAgents": ["zhongshu"]}},
        {"id": "zhongshu", "subagents": {"allowAgents": ["menxia", "shangshu"]}},
        {"id": "menxia",   "subagents": {"allowAgents": ["shangshu", "zhongshu"]}},
        {"id": "shangshu", "subagents": {"allowAgents": ["zhongshu", "menxia", "hubu", "libu", "bingbu", "xingbu", "gongbu", "libu_hr"]}},
        {"id": "hubu",     "subagents": {"allowAgents": ["shangshu"]}},
        {"id": "libu",     "subagents": {"allowAgents": ["shangshu"]}},
        {"id": "bingbu",   "subagents": {"allowAgents": ["shangshu"]}},
        {"id": "xingbu",   "subagents": {"allowAgents": ["shangshu"]}},
        {"id": "gongbu",   "subagents": {"allowAgents": ["shangshu"]}},
        {"id": "libu_hr",  "subagents": {"allowAgents": ["shangshu"]}},
        {"id": "zaochao",  "subagents": {"allowAgents": []}},
    ]
    
    agents_cfg = cfg.setdefault('agents', {})
    agents_list = agents_cfg.get('list', [])
    existing = {a['id'] for a in agents_list}
    
    added = 0
    for ag in AGENTS:
        ag_id = ag['id']
        workspace = str(OCLAW_HOME / f'workspace-{ag_id}')
        
        # 1. 创建 workspace 目录
        (OCLAW_HOME / f'workspace-{ag_id}').mkdir(parents=True, exist_ok=True)
        (OCLAW_HOME / f'workspace-{ag_id}' / 'skills').mkdir(parents=True, exist_ok=True)
        
        # 2. 复制 SOUL.md
        soul_src = REPO_DIR / 'agents' / ag_id / 'SOUL.md'
        soul_dst = OCLAW_HOME / f'workspace-{ag_id}' / 'SOUL.md'
        if soul_src.exists():
            content = soul_src.read_text(encoding='utf-8')
            content = content.replace('__REPO_DIR__', str(REPO_DIR))
            soul_dst.write_text(content, encoding='utf-8')
        
        # 3. 创建 openclaw/agents/{id} 目录结构
        agent_dir = OCLAW_HOME / 'agents' / ag_id
        agent_dir.mkdir(parents=True, exist_ok=True)
        (agent_dir / 'sessions').mkdir(parents=True, exist_ok=True)
        
        # 复制 SOUL.md 到 agents 目录
        agent_soul = agent_dir / 'SOUL.md'
        if soul_src.exists() and not agent_soul.exists():
            shutil.copy2(soul_src, agent_soul)
        
        # 4. 注册到 openclaw.json
        if ag_id not in existing:
            entry = {
                'id': ag_id,
                'workspace': workspace,
                'subagents': ag['subagents']
            }
            agents_list.append(entry)
            added += 1
            print(f'  + Registered: {ag_id}')
        else:
            # 更新现有配置
            for existing_ag in agents_list:
                if existing_ag['id'] == ag_id:
                    existing_ag['workspace'] = workspace
                    existing_ag['subagents'] = ag['subagents']
                    break
            print(f'  ~ Updated: {ag_id}')
    
    agents_cfg['list'] = agents_list
    cfg_path.write_text(json.dumps(cfg, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f'Done: {added} new agents registered, {len(AGENTS)} total')

if __name__ == '__main__':
    main()
