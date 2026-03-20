"use client"

import { useState } from "react"
import { supabase } from "@/lib/supabase"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Select } from "@/components/ui/select"
import { Textarea } from "@/components/ui/textarea"
import { useStages } from "@/hooks/useStages"
import { useProducts } from "@/hooks/useProducts"
import { useSources } from "@/hooks/useSources"
import type { Lead } from "@/types"

interface LeadFormProps {
  lead?: Lead
  initialStageId?: string
  onSuccess: () => void
  onCancel: () => void
}

export function LeadForm({ lead, initialStageId, onSuccess, onCancel }: LeadFormProps) {
  const { stages } = useStages()
  const { products } = useProducts()
  const { sources } = useSources()
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState("")

  const [form, setForm] = useState({
    name: lead?.name || "",
    phone: lead?.phone || "",
    email: lead?.email || "",
    stage_id: lead?.stage_id || initialStageId || "",
    source_id: lead?.source_id || "",
    product_id: lead?.product_id || "",
    proposal_value: lead?.proposal_value?.toString() || "",
    payment_method: lead?.payment_method || "",
    notes: lead?.notes || "",
  })

  const set = (field: keyof typeof form) => (
    e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>
  ) => setForm((prev) => ({ ...prev, [field]: e.target.value }))

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!form.name.trim() || !form.phone.trim() || !form.stage_id) {
      setError("Nome, telefone e estágio são obrigatórios")
      return
    }
    setLoading(true)
    setError("")

    const payload = {
      name: form.name.trim(),
      phone: form.phone.trim(),
      email: form.email.trim() || null,
      stage_id: form.stage_id,
      source_id: form.source_id || null,
      product_id: form.product_id || null,
      proposal_value: form.proposal_value ? parseFloat(form.proposal_value) : null,
      payment_method: form.payment_method.trim() || null,
      notes: form.notes.trim() || null,
    }

    if (lead) {
      const { error: updateError } = await supabase
        .from("leads")
        .update(payload)
        .eq("id", lead.id)

      if (!updateError && lead.stage_id !== form.stage_id) {
        const stageName = stages.find((s) => s.id === form.stage_id)?.name || ""
        await supabase.from("interactions").insert({
          lead_id: lead.id,
          type: "stage_change",
          content: `Movido para "${stageName}"`,
        })
      }

      if (updateError) {
        setError(updateError.message)
        setLoading(false)
        return
      }
    } else {
      const { data: newLead, error: insertError } = await supabase
        .from("leads")
        .insert(payload)
        .select()
        .single()

      if (insertError) {
        setError(insertError.message)
        setLoading(false)
        return
      }

      const stageName = stages.find((s) => s.id === form.stage_id)?.name || ""
      await supabase.from("interactions").insert({
        lead_id: newLead.id,
        type: "stage_change",
        content: `Lead criado em "${stageName}"`,
      })
    }

    setLoading(false)
    onSuccess()
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-4">
      <div className="grid grid-cols-2 gap-4">
        <div className="col-span-2">
          <Input label="Nome *" value={form.name} onChange={set("name")} placeholder="João Silva" />
        </div>
        <Input label="Telefone *" value={form.phone} onChange={set("phone")} placeholder="(11) 99999-9999" />
        <Input label="E-mail" type="email" value={form.email} onChange={set("email")} placeholder="joao@email.com" />
      </div>

      <div className="grid grid-cols-2 gap-4">
        <Select
          label="Estágio *"
          value={form.stage_id}
          onChange={set("stage_id")}
          placeholder="Selecione..."
          options={stages.map((s) => ({ value: s.id, label: s.name }))}
        />
        <Select
          label="Origem"
          value={form.source_id}
          onChange={set("source_id")}
          placeholder="Selecione..."
          options={sources.map((s) => ({ value: s.id, label: s.name }))}
        />
      </div>

      <Select
        label="Produto ofertado"
        value={form.product_id}
        onChange={set("product_id")}
        placeholder="Selecione um produto..."
        options={products.map((p) => ({ value: p.id, label: `${p.name}${p.price ? ` — R$ ${p.price.toLocaleString("pt-BR")}` : ""}` }))}
      />

      <div className="grid grid-cols-2 gap-4">
        <Input
          label="Valor da proposta (R$)"
          type="number"
          step="0.01"
          value={form.proposal_value}
          onChange={set("proposal_value")}
          placeholder="0,00"
        />
        <Input
          label="Forma de pagamento"
          value={form.payment_method}
          onChange={set("payment_method")}
          placeholder="Ex: 3x R$ 1.000"
        />
      </div>

      <Textarea
        label="Observações"
        value={form.notes}
        onChange={set("notes")}
        placeholder="Notas gerais sobre o lead..."
        rows={3}
      />

      {error && <p className="text-sm text-red-500">{error}</p>}

      <div className="flex gap-3 justify-end pt-2">
        <Button type="button" variant="outline" onClick={onCancel}>
          Cancelar
        </Button>
        <Button type="submit" disabled={loading}>
          {loading ? "Salvando..." : lead ? "Salvar alterações" : "Criar lead"}
        </Button>
      </div>
    </form>
  )
}
