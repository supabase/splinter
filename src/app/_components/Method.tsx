const WA_LINK = "https://wa.me/5511940347276";

const pillars = [
  {
    icon: "◎",
    title: "Decisão Clara",
    desc: "Transformamos sua confusão em uma pergunta de decisão bem definida",
  },
  {
    icon: "⚖",
    title: "Critérios + Trade-offs",
    desc: "Explicitamos o que importa para você e o que você está disposto a abrir mão",
  },
  {
    icon: "→",
    title: "Próximos Passos",
    desc: "Saímos com ações testáveis e executáveis — não com mais teoria",
  },
];

const steps = [
  {
    n: "01",
    title: "Aplicação",
    desc: "Você preenche o formulário de intake com sua situação atual e o que busca resolver.",
  },
  {
    n: "02",
    title: "Diagnóstico",
    desc: "Identificamos a decisão real e a trava. Às vezes o problema declarado não é o problema real.",
  },
  {
    n: "03",
    title: "Sessões",
    desc: "Trabalhamos com o Decision Canvas e kits específicos para cada tipo de decisão.",
  },
  {
    n: "04",
    title: "Encerramento",
    desc: "Você sai com autonomia para decidir sozinho. Sem dependência, sem prolongamento artificial.",
  },
];

export function Method() {
  return (
    <>
      {/* Mid CTA */}
      <section className="bg-white px-4 py-16 text-center border-y border-[#e2e8f0]" aria-label="CTA intermediário">
        <div className="max-w-md mx-auto flex flex-col items-center gap-4">
          <h2 className="text-2xl font-extrabold text-[#0f172a]">Quer parar de girar em círculos?</h2>
          <p className="text-[#64748b]">Primeira sessão de diagnóstico gratuita. Sem compromisso.</p>
          <a
            href={WA_LINK}
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-2 bg-[#22c55e] hover:bg-[#16a34a] text-white font-bold px-8 py-4 rounded-full transition-colors w-full max-w-xs justify-center"
          >
            <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24" aria-hidden="true">
              <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347z" /><path d="M12 0C5.373 0 0 5.373 0 12c0 2.123.554 4.118 1.528 5.852L0 24l6.335-1.508A11.95 11.95 0 0012 24c6.627 0 12-5.373 12-12S18.627 0 12 0zm0 22c-1.885 0-3.65-.49-5.19-1.352l-.37-.214-3.762.896.953-3.67-.242-.384A9.944 9.944 0 012 12C2 6.477 6.477 2 12 2s10 4.477 10 10-4.477 10-10 10z" />
            </svg>
            Conversar no WhatsApp
          </a>
          <p className="text-[#64748b] text-sm underline cursor-pointer">Ou preencha o formulário</p>
        </div>
      </section>

      {/* O Método */}
      <section id="metodo" className="bg-[#f8fafc] px-4 py-20" aria-label="O método Decision Canvas">
        <div className="max-w-2xl mx-auto">
          <div className="text-center mb-12">
            <p className="text-[#64748b] text-xs font-semibold tracking-widest uppercase mb-3">O Método</p>
            <h2 className="text-3xl font-extrabold text-[#0f172a] mb-4">
              Overthinking não é ansiedade. É ausência de método.
            </h2>
            <p className="text-[#64748b] leading-relaxed">
              Quanto mais você pesquisa sem critérios explícitos, mais longe fica de decidir.
              O <strong className="text-[#0f172a]">Decision Canvas</strong> é o framework que
              separa clareza de confusão — transformando dilemas em perguntas respondíveis.
            </p>
          </div>
          <div className="flex flex-col gap-8 mb-12">
            {pillars.map(({ icon, title, desc }) => (
              <div key={title} className="text-center flex flex-col items-center gap-2">
                <span className="text-[#3b82f6] text-3xl">{icon}</span>
                <h3 className="font-bold text-[#0f172a] text-lg">{title}</h3>
                <p className="text-[#64748b] max-w-xs">{desc}</p>
              </div>
            ))}
          </div>
          <p className="text-center italic text-[#64748b]">&ldquo;Autonomia, não dependência.&rdquo;</p>
        </div>
      </section>

      {/* Como funciona */}
      <section className="bg-white px-4 py-20" aria-label="Como funciona a mentoria">
        <div className="max-w-2xl mx-auto">
          <div className="text-center mb-12">
            <h2 className="text-3xl font-extrabold text-[#0f172a] mb-2">Como funciona</h2>
            <p className="text-[#64748b]">Um processo simples e direto</p>
          </div>
          <div className="flex flex-col gap-4">
            {steps.map(({ n, title, desc }) => (
              <div key={n} className="bg-white rounded-2xl p-6 border border-[#e2e8f0] shadow-sm">
                <p className="text-[#3b82f6] font-bold text-sm mb-2">{n}</p>
                <h3 className="font-bold text-[#0f172a] text-lg mb-1">{title}</h3>
                <p className="text-[#64748b] text-sm">{desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>
    </>
  );
}
