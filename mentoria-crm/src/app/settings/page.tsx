"use client"

export const dynamic = "force-dynamic"

import { useState } from "react"
import { Plus, Trash2, Edit3, GripVertical, Settings } from "lucide-react"
import { supabase } from "@/lib/supabase"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { useStages } from "@/hooks/useStages"
import { useProducts } from "@/hooks/useProducts"
import { useSources } from "@/hooks/useSources"
import { formatCurrency } from "@/lib/utils"
import type { Stage, Product, Source } from "@/types"

// Stage type labels
const stageTypeLabels = { normal: "Normal", won: "Fechado", lost: "Perdido" }

export default function SettingsPage() {
  return (
    <div className="max-w-4xl mx-auto">
      <div className="flex items-center gap-3 mb-6">
        <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-slate-100">
          <Settings className="h-5 w-5 text-slate-600" />
        </div>
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Configurações</h1>
          <p className="text-sm text-slate-500">Gerencie estágios, produtos e origens</p>
        </div>
      </div>

      <div className="flex flex-col gap-6">
        <StagesSection />
        <ProductsSection />
        <SourcesSection />
        <WhatsAppSection />
      </div>
    </div>
  )
}

// ============ STAGES ============
function StagesSection() {
  const { stages, refetch } = useStages()
  const [showAdd, setShowAdd] = useState(false)
  const [editStage, setEditStage] = useState<Stage | null>(null)
  const [form, setForm] = useState({ name: "", color: "#6366f1", type: "normal" as Stage["type"] })
  const [saving, setSaving] = useState(false)

  const openAdd = () => { setForm({ name: "", color: "#6366f1", type: "normal" }); setShowAdd(true) }
  const openEdit = (s: Stage) => { setEditStage(s); setForm({ name: s.name, color: s.color, type: s.type }); setShowAdd(true) }
  const closeDialog = () => { setShowAdd(false); setEditStage(null) }

  const save = async () => {
    if (!form.name.trim()) return
    setSaving(true)
    if (editStage) {
      await supabase.from("stages").update({ name: form.name, color: form.color, type: form.type }).eq("id", editStage.id)
    } else {
      const maxOrder = stages.length > 0 ? Math.max(...stages.map((s) => s.order)) + 1 : 1
      await supabase.from("stages").insert({ name: form.name, color: form.color, type: form.type, order: maxOrder })
    }
    setSaving(false)
    closeDialog()
    refetch()
  }

  const remove = async (id: string) => {
    if (!confirm("Tem certeza? Os leads nesse estágio ficarão sem estágio.")) return
    await supabase.from("stages").delete().eq("id", id)
    refetch()
  }

  return (
    <>
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle>Estágios do Pipeline</CardTitle>
            <Button size="sm" onClick={openAdd}><Plus className="h-4 w-4 mr-1" /> Novo estágio</Button>
          </div>
        </CardHeader>
        <CardContent>
          <div className="flex flex-col gap-2">
            {stages.map((stage) => (
              <div key={stage.id} className="flex items-center gap-3 p-3 rounded-lg border border-slate-100 bg-slate-50 group">
                <GripVertical className="h-4 w-4 text-slate-300" />
                <div className="h-4 w-4 rounded-full border border-white shadow-sm flex-shrink-0" style={{ backgroundColor: stage.color }} />
                <div className="flex-1">
                  <span className="text-sm font-medium text-slate-800">{stage.name}</span>
                  <span className="ml-2 text-xs text-slate-400">{stageTypeLabels[stage.type]}</span>
                </div>
                <div className="flex gap-1 opacity-0 group-hover:opacity-100 transition">
                  <Button size="icon" variant="ghost" className="h-7 w-7" onClick={() => openEdit(stage)}>
                    <Edit3 className="h-3.5 w-3.5" />
                  </Button>
                  <Button size="icon" variant="ghost" className="h-7 w-7 text-red-400 hover:text-red-600" onClick={() => remove(stage.id)}>
                    <Trash2 className="h-3.5 w-3.5" />
                  </Button>
                </div>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>

      <Dialog open={showAdd} onOpenChange={(v) => { if (!v) closeDialog() }}>
        <DialogContent onClose={closeDialog}>
          <DialogHeader>
            <DialogTitle>{editStage ? "Editar Estágio" : "Novo Estágio"}</DialogTitle>
          </DialogHeader>
          <div className="flex flex-col gap-4">
            <Input label="Nome do estágio" value={form.name} onChange={(e) => setForm((p) => ({ ...p, name: e.target.value }))} />
            <div className="flex flex-col gap-1.5">
              <label className="text-sm font-medium text-slate-700">Cor</label>
              <div className="flex items-center gap-3">
                <input
                  type="color"
                  value={form.color}
                  onChange={(e) => setForm((p) => ({ ...p, color: e.target.value }))}
                  className="h-10 w-16 rounded-lg border border-slate-200 cursor-pointer"
                />
                <span className="text-sm text-slate-500">{form.color}</span>
              </div>
            </div>
            <div className="flex flex-col gap-1.5">
              <label className="text-sm font-medium text-slate-700">Tipo</label>
              <div className="flex gap-2">
                {(["normal", "won", "lost"] as Stage["type"][]).map((t) => (
                  <button
                    key={t}
                    onClick={() => setForm((p) => ({ ...p, type: t }))}
                    className={`px-3 py-1.5 rounded-lg text-sm font-medium border transition ${
                      form.type === t ? "bg-indigo-600 text-white border-indigo-600" : "bg-white text-slate-600 border-slate-200 hover:border-indigo-300"
                    }`}
                  >
                    {stageTypeLabels[t]}
                  </button>
                ))}
              </div>
            </div>
            <div className="flex gap-2 justify-end pt-2">
              <Button variant="outline" onClick={closeDialog}>Cancelar</Button>
              <Button onClick={save} disabled={saving}>{saving ? "Salvando..." : "Salvar"}</Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>
    </>
  )
}

// ============ PRODUCTS ============
function ProductsSection() {
  const { products, refetch } = useProducts()
  const [showAdd, setShowAdd] = useState(false)
  const [editProduct, setEditProduct] = useState<Product | null>(null)
  const [form, setForm] = useState({ name: "", price: "", description: "" })
  const [saving, setSaving] = useState(false)

  const openAdd = () => { setForm({ name: "", price: "", description: "" }); setShowAdd(true) }
  const openEdit = (p: Product) => {
    setEditProduct(p)
    setForm({ name: p.name, price: p.price?.toString() || "", description: p.description || "" })
    setShowAdd(true)
  }
  const closeDialog = () => { setShowAdd(false); setEditProduct(null) }

  const save = async () => {
    if (!form.name.trim()) return
    setSaving(true)
    const payload = {
      name: form.name.trim(),
      price: form.price ? parseFloat(form.price) : null,
      description: form.description.trim() || null,
    }
    if (editProduct) {
      await supabase.from("products").update(payload).eq("id", editProduct.id)
    } else {
      await supabase.from("products").insert(payload)
    }
    setSaving(false)
    closeDialog()
    refetch()
  }

  const remove = async (id: string) => {
    if (!confirm("Remover produto?")) return
    await supabase.from("products").update({ active: false }).eq("id", id)
    refetch()
  }

  return (
    <>
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle>Produtos de Mentoria</CardTitle>
            <Button size="sm" onClick={openAdd}><Plus className="h-4 w-4 mr-1" /> Novo produto</Button>
          </div>
        </CardHeader>
        <CardContent>
          <div className="flex flex-col gap-2">
            {products.map((p) => (
              <div key={p.id} className="flex items-center gap-3 p-3 rounded-lg border border-slate-100 bg-slate-50 group">
                <div className="flex-1">
                  <span className="text-sm font-medium text-slate-800">{p.name}</span>
                  {p.price && <span className="ml-2 text-sm font-semibold text-emerald-600">{formatCurrency(p.price)}</span>}
                  {p.description && <p className="text-xs text-slate-400 mt-0.5">{p.description}</p>}
                </div>
                <div className="flex gap-1 opacity-0 group-hover:opacity-100 transition">
                  <Button size="icon" variant="ghost" className="h-7 w-7" onClick={() => openEdit(p)}>
                    <Edit3 className="h-3.5 w-3.5" />
                  </Button>
                  <Button size="icon" variant="ghost" className="h-7 w-7 text-red-400 hover:text-red-600" onClick={() => remove(p.id)}>
                    <Trash2 className="h-3.5 w-3.5" />
                  </Button>
                </div>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>

      <Dialog open={showAdd} onOpenChange={(v) => { if (!v) closeDialog() }}>
        <DialogContent onClose={closeDialog}>
          <DialogHeader>
            <DialogTitle>{editProduct ? "Editar Produto" : "Novo Produto"}</DialogTitle>
          </DialogHeader>
          <div className="flex flex-col gap-4">
            <Input label="Nome do produto" value={form.name} onChange={(e) => setForm((p) => ({ ...p, name: e.target.value }))} />
            <Input label="Valor (R$)" type="number" step="0.01" value={form.price} onChange={(e) => setForm((p) => ({ ...p, price: e.target.value }))} placeholder="0,00" />
            <Input label="Descrição" value={form.description} onChange={(e) => setForm((p) => ({ ...p, description: e.target.value }))} placeholder="Opcional..." />
            <div className="flex gap-2 justify-end pt-2">
              <Button variant="outline" onClick={closeDialog}>Cancelar</Button>
              <Button onClick={save} disabled={saving}>{saving ? "Salvando..." : "Salvar"}</Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>
    </>
  )
}

// ============ SOURCES ============
function SourcesSection() {
  const { sources, refetch } = useSources()
  const [showAdd, setShowAdd] = useState(false)
  const [name, setName] = useState("")
  const [saving, setSaving] = useState(false)

  const save = async () => {
    if (!name.trim()) return
    setSaving(true)
    await supabase.from("sources").insert({ name: name.trim() })
    setName("")
    setSaving(false)
    setShowAdd(false)
    refetch()
  }

  const remove = async (id: string) => {
    if (!confirm("Remover origem?")) return
    await supabase.from("sources").delete().eq("id", id)
    refetch()
  }

  return (
    <>
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle>Origens de Leads</CardTitle>
            <Button size="sm" onClick={() => setShowAdd(true)}><Plus className="h-4 w-4 mr-1" /> Nova origem</Button>
          </div>
        </CardHeader>
        <CardContent>
          <div className="flex flex-wrap gap-2">
            {sources.map((s) => (
              <div key={s.id} className="flex items-center gap-1.5 px-3 py-1.5 bg-slate-100 rounded-full group">
                <span className="text-sm text-slate-700">{s.name}</span>
                <button onClick={() => remove(s.id)} className="text-slate-400 hover:text-red-500 transition opacity-0 group-hover:opacity-100">
                  <Trash2 className="h-3 w-3" />
                </button>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>

      <Dialog open={showAdd} onOpenChange={setShowAdd}>
        <DialogContent onClose={() => setShowAdd(false)}>
          <DialogHeader>
            <DialogTitle>Nova Origem</DialogTitle>
          </DialogHeader>
          <div className="flex flex-col gap-4">
            <Input label="Nome da origem" value={name} onChange={(e) => setName(e.target.value)} placeholder="Ex: Instagram, Indicação..." />
            <div className="flex gap-2 justify-end">
              <Button variant="outline" onClick={() => setShowAdd(false)}>Cancelar</Button>
              <Button onClick={save} disabled={saving}>{saving ? "Salvando..." : "Salvar"}</Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>
    </>
  )
}

// ============ WHATSAPP ============
function WhatsAppSection() {
  const [phone, setPhone] = useState(process.env.NEXT_PUBLIC_CALLMEBOT_PHONE || "")
  const [apiKey, setApiKey] = useState("")
  const [testing, setTesting] = useState(false)
  const [result, setResult] = useState("")

  const testNotif = async () => {
    setTesting(true)
    setResult("")
    const res = await fetch("/api/notify", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        leadName: "Teste",
        meetingTitle: "Reunião de Teste",
        date: new Date().toISOString().split("T")[0],
        time: "10:00",
        link: null,
      }),
    })
    setResult(res.ok ? "✅ Mensagem enviada com sucesso!" : "❌ Erro ao enviar. Verifique as configurações.")
    setTesting(false)
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>Notificações WhatsApp</CardTitle>
      </CardHeader>
      <CardContent>
        <p className="text-sm text-slate-500 mb-4">
          Configure o CallMeBot para receber lembretes de reuniões no WhatsApp.{" "}
          <a href="https://www.callmebot.com/blog/free-api-whatsapp-messages/" target="_blank" rel="noopener noreferrer" className="text-indigo-600 underline">
            Como ativar →
          </a>
        </p>
        <div className="flex flex-col gap-4 max-w-sm">
          <div className="bg-amber-50 border border-amber-200 rounded-lg p-3 text-xs text-amber-700">
            Configure <code className="bg-amber-100 px-1 rounded">CALLMEBOT_PHONE</code> e{" "}
            <code className="bg-amber-100 px-1 rounded">CALLMEBOT_API_KEY</code> no arquivo{" "}
            <code className="bg-amber-100 px-1 rounded">.env.local</code> para habilitar as notificações.
          </div>
          <Button variant="outline" onClick={testNotif} disabled={testing}>
            {testing ? "Enviando..." : "Enviar mensagem de teste"}
          </Button>
          {result && <p className="text-sm">{result}</p>}
        </div>
      </CardContent>
    </Card>
  )
}
