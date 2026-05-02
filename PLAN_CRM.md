# Plano: CRM de Mentoria

## Stack Definida
- **Frontend:** Next.js 14 (App Router)
- **Banco de dados:** Supabase (PostgreSQL)
- **UI:** Tailwind CSS + shadcn/ui (visual elaborado)
- **Drag & Drop:** `@dnd-kit/core` (kanban)
- **Notificações WhatsApp:** CallMeBot API (gratuito, pessoal) ou Twilio
- **Moeda:** R$ (BRL)
- **Acesso:** Solo user, local por enquanto

---

## Estrutura de Páginas

| Rota | Descrição |
|------|-----------|
| `/` | Dashboard com métricas |
| `/kanban` | Quadro Kanban com drag & drop |
| `/leads` | Lista/tabela com filtros e busca |
| `/leads/[id]` | Detalhe do lead + timeline + reuniões |
| `/settings` | Configurar estágios, produtos, origens |

---

## Schema do Banco de Dados (Supabase)

### Tabela `stages`
```sql
- id (uuid, PK)
- name (text) — ex: "Primeiro Contato"
- color (text) — cor hex para o kanban
- order (int) — ordem no kanban
- type (enum: 'normal' | 'won' | 'lost') — para lógica de "Fechado" e "Perdido"
- created_at (timestamp)
```

### Tabela `products`
```sql
- id (uuid, PK)
- name (text) — ex: "Mentoria 3 meses"
- price (numeric) — valor padrão
- description (text, nullable)
- active (boolean)
- created_at (timestamp)
```

### Tabela `sources`
```sql
- id (uuid, PK)
- name (text) — ex: "Instagram", "Indicação", "YouTube"
- created_at (timestamp)
```

### Tabela `leads`
```sql
- id (uuid, PK)
- name (text)
- phone (text)
- email (text, nullable)
- stage_id (uuid, FK → stages)
- source_id (uuid, FK → sources, nullable)
- product_id (uuid, FK → products, nullable)
- proposal_value (numeric, nullable) — R$
- payment_method (text, nullable) — ex: "3x R$ 500"
- notes (text, nullable) — campo livre adicional
- created_at (timestamp)
- updated_at (timestamp)
```

### Tabela `meetings`
```sql
- id (uuid, PK)
- lead_id (uuid, FK → leads)
- title (text)
- date (date)
- time (time)
- link (text, nullable) — link Zoom/Meet
- notified (boolean) — se a notificação WhatsApp foi enviada
- created_at (timestamp)
```

### Tabela `interactions` (timeline)
```sql
- id (uuid, PK)
- lead_id (uuid, FK → leads)
- type (enum: 'note' | 'stage_change' | 'meeting' | 'proposal')
- content (text)
- created_at (timestamp)
```

---

## Estágios Iniciais (seed)
1. **Primeiro Contato** — cor azul claro, type: normal
2. **Sessão de Diagnóstico** — cor amarelo, type: normal
3. **Criação de Proposta** — cor laranja, type: normal
4. **Proposta Enviada** — cor roxo, type: normal
5. **Fechado** — cor verde, type: won
6. **Não Fechado / Perdido** — cor vermelho/cinza, type: lost

---

## Funcionalidades por Página

### Dashboard (`/`)
- Cards de métricas:
  - Total de leads ativos
  - Leads por estágio (barra/donut chart)
  - Valor total em proposta (R$)
  - Taxa de conversão (Fechados / Total)
  - Reuniões das próximas 7 dias
- Lista rápida de próximas reuniões

### Kanban (`/kanban`)
- Colunas por estágio com cores
- Cards de lead: nome, telefone, valor proposta, próxima reunião
- Drag & drop entre colunas (atualiza estágio no banco)
- Ao mudar de estágio, registra na timeline do lead
- Botão para adicionar lead direto no kanban

### Lista de Leads (`/leads`)
- Tabela com: nome, telefone, estágio, próxima reunião, valor, origem
- Busca por nome/telefone/email
- Filtros: por estágio, por origem, por produto
- Ordenação por data de criação / próxima reunião
- Botão "Novo Lead"

### Detalhe do Lead (`/leads/[id]`)
- Formulário de edição dos dados do lead
- Seletor de estágio
- Seção de proposta: produto, valor, forma de pagamento
- Seção de próxima reunião: data, horário, link + botão de notificação WhatsApp
- Timeline de interações (histórico de notas, mudanças de estágio, reuniões)
- Adicionar nota/interação manualmente

### Configurações (`/settings`)
- Gerenciar estágios (nome, cor, ordem) — add/edit/reorder/delete
- Gerenciar produtos (nome, valor padrão, descrição)
- Gerenciar origens de leads
- Configurar número WhatsApp para notificações

---

## Notificações WhatsApp
- **Solução:** CallMeBot (API gratuita para uso pessoal)
  - O usuário se cadastra uma vez no CallMeBot com seu WhatsApp
  - Recebe uma API key
  - O sistema envia alertas HTTP para reuniões com menos de 24h
- **Trigger:** Cron job via Next.js API Route + Vercel Cron / ou roda local com `node-cron`
- **Mensagem exemplo:** "📅 Lembrete: Reunião com João Silva amanhã às 15h - [link Meet]"

---

## Ordem de Implementação

### Fase 1 — Base
1. Setup Next.js 14 + Supabase + Tailwind + shadcn/ui
2. Schema do banco + seed dos estágios iniciais
3. Autenticação básica (single user com Supabase Auth)

### Fase 2 — CRUD de Leads
4. Página de lista de leads com filtros/busca
5. Formulário de criação/edição de lead
6. Página de detalhe do lead
7. Timeline de interações

### Fase 3 — Kanban
8. Página Kanban com colunas por estágio
9. Drag & drop entre colunas
10. Registro automático de mudança de estágio na timeline

### Fase 4 — Dashboard
11. Métricas: totais, conversão, valor em proposta
12. Lista de próximas reuniões

### Fase 5 — Notificações e Configurações
13. Página de configurações (estágios, produtos, origens)
14. Integração com CallMeBot para WhatsApp
15. Cron job de lembretes de reuniões

---

## Estrutura de Diretórios (Next.js)

```
mentoria-crm/
├── app/
│   ├── (dashboard)/
│   │   └── page.tsx          # Dashboard principal
│   ├── kanban/
│   │   └── page.tsx          # Kanban
│   ├── leads/
│   │   ├── page.tsx          # Lista de leads
│   │   └── [id]/
│   │       └── page.tsx      # Detalhe do lead
│   ├── settings/
│   │   └── page.tsx          # Configurações
│   └── api/
│       └── notify/
│           └── route.ts      # API de notificação WhatsApp
├── components/
│   ├── kanban/               # Componentes do kanban
│   ├── leads/                # Componentes de leads
│   ├── dashboard/            # Componentes do dashboard
│   └── ui/                   # shadcn/ui components
├── lib/
│   ├── supabase.ts           # Client Supabase
│   └── whatsapp.ts           # Integração CallMeBot
└── types/
    └── index.ts              # Tipos TypeScript
```
