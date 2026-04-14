import { createClient } from "@/lib/supabase-server";
import type { MentoradoMaterial, Material } from "@/types/portal";

const typeLabels: Record<string, string> = {
  pdf: "PDF",
  video: "Vídeo",
  template: "Template",
  link: "Link",
};

const typeColors: Record<string, string> = {
  pdf: "bg-red-50 text-red-600 border-red-100",
  video: "bg-blue-50 text-[#1E88E5] border-blue-100",
  template: "bg-orange-50 text-[#F97316] border-orange-100",
  link: "bg-[#F7F8FC] text-[#64748b] border-[#e2e8f0]",
};

function TypeIcon({ type }: { type: string }) {
  if (type === "pdf")
    return <svg className="w-6 h-6 text-red-500" fill="none" stroke="currentColor" strokeWidth={1.5} viewBox="0 0 24 24" aria-hidden="true"><path strokeLinecap="round" strokeLinejoin="round" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" /></svg>;
  if (type === "video")
    return <svg className="w-6 h-6 text-[#1E88E5]" fill="none" stroke="currentColor" strokeWidth={1.5} viewBox="0 0 24 24" aria-hidden="true"><path strokeLinecap="round" strokeLinejoin="round" d="M15 10l4.553-2.069A1 1 0 0121 8.87v6.26a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" /></svg>;
  if (type === "template")
    return <svg className="w-6 h-6 text-[#F97316]" fill="none" stroke="currentColor" strokeWidth={1.5} viewBox="0 0 24 24" aria-hidden="true"><path strokeLinecap="round" strokeLinejoin="round" d="M4 5a1 1 0 011-1h14a1 1 0 011 1v2a1 1 0 01-1 1H5a1 1 0 01-1-1V5zM4 13a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H5a1 1 0 01-1-1v-6zM16 13a1 1 0 011-1h2a1 1 0 011 1v6a1 1 0 01-1 1h-2a1 1 0 01-1-1v-6z" /></svg>;
  return <svg className="w-6 h-6 text-[#64748b]" fill="none" stroke="currentColor" strokeWidth={1.5} viewBox="0 0 24 24" aria-hidden="true"><path strokeLinecap="round" strokeLinejoin="round" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" /></svg>;
}

export default async function MateriaisPage() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return null;

  // Fetch materials assigned to this mentee
  const { data: pivot } = await supabase
    .from("mentorado_materiais")
    .select("*, material:materiais(*)")
    .order("unlocked_at", { ascending: false });

  // Fetch global materials
  const { data: globalMaterials } = await supabase
    .from("materiais")
    .select("*")
    .eq("is_global", true)
    .order("created_at", { ascending: false });

  const assigned = (pivot ?? []) as MentoradoMaterial[];
  const globals = (globalMaterials ?? []) as Material[];

  // Merge: assigned + global (deduplicated)
  const assignedIds = new Set(assigned.map((p) => p.material_id));
  const allMaterials: Array<{ material: Material; seen_at: string | null; pivotId?: string }> = [
    ...assigned.map((p) => ({ material: p.material!, seen_at: p.seen_at, pivotId: p.id })),
    ...globals.filter((g) => !assignedIds.has(g.id)).map((g) => ({ material: g, seen_at: null })),
  ];

  const types = ["all", "pdf", "video", "template", "link"] as const;

  return (
    <div className="max-w-3xl mx-auto">
      <div className="mb-8">
        <p className="text-[#1E88E5] text-xs font-semibold tracking-widest uppercase mb-1">Biblioteca</p>
        <h1 className="text-2xl sm:text-3xl font-extrabold text-[#0f172a]">Materiais</h1>
        <p className="text-[#64748b] text-sm mt-1">Recursos compartilhados pelo mentor para sua jornada.</p>
      </div>

      {allMaterials.length === 0 ? (
        <div className="bg-white rounded-2xl border border-[#e2e8f0] p-10 text-center">
          <p className="text-[#64748b] text-sm">Nenhum material disponível ainda.</p>
          <p className="text-[#94a3b8] text-xs mt-1">O mentor compartilhará recursos conforme a mentoria avançar.</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          {allMaterials.map(({ material, seen_at }) => (
            <a
              key={material.id}
              href={material.url}
              target="_blank"
              rel="noopener noreferrer"
              className="bg-white rounded-2xl border border-[#e2e8f0] shadow-sm p-5 flex gap-4 hover:border-[#1E88E5]/40 hover:shadow-md transition group"
            >
              <div className="w-12 h-12 rounded-xl bg-[#F7F8FC] border border-[#e2e8f0] flex items-center justify-center shrink-0 group-hover:bg-blue-50 transition">
                <TypeIcon type={material.type} />
              </div>
              <div className="min-w-0 flex-1">
                <div className="flex items-start justify-between gap-2">
                  <p className="text-[#0f172a] font-semibold text-sm leading-snug line-clamp-2">{material.title}</p>
                  {!seen_at && (
                    <span className="shrink-0 text-[10px] font-bold text-white bg-[#1E88E5] px-2 py-0.5 rounded-full">Novo</span>
                  )}
                </div>
                {material.description && (
                  <p className="text-[#64748b] text-xs mt-1 line-clamp-2">{material.description}</p>
                )}
                <span className={`inline-block text-[10px] font-bold px-2 py-0.5 rounded-full border mt-2 ${typeColors[material.type]}`}>
                  {typeLabels[material.type]}
                </span>
              </div>
            </a>
          ))}
        </div>
      )}
    </div>
  );
}
