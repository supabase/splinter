const WA_LINK = "https://wa.me/5511940347276";

const plans = [
  {
    type: "Sessão Única",
    name: "Decisão",
    price: "R$ 600",
    period: null,
    highlight: "Não tem certeza se o Ciclo Travessia é para você? Comece aqui.",
    desc: "Para uma decisão específica que você precisa resolver agora",
    note: "A Sessão Única é a porta de entrada para o Ciclo Travessia. Muitos clientes começam aqui e entendem, ao vivo, o que é possível em mais profundidade.",
    features: [
      "1 sessão de 90 minutos",
      "Foco em 1 decisão real",
      "Aplicação do Decision Canvas",
      "Sem suporte assíncrono",
    ],
    result: "clareza sobre a decisão + próximo passo concreto.",
    recommended: false,
    buttonStyle: "bg-[#0f172a] hover:bg-[#1e293b] text-white",
  },
  {
    type: "Ciclo 1:1",
    name: "Travessia",
    price: "R$ 2.000",
    period: null,
    highlight: "Escolha este se você está em transição ou tem múltiplas decisões conectadas.",
    desc: "Para quem precisa de mais tempo e acompanhamento",
    note: null,
    features: [
      "4 sessões de 60 minutos",
      "Duração: 4 a 6 semanas",
      "Suporte assíncrono leve (foco em decisão)",
      "Kits específicos por tipo de decisão",
    ],
    result: "plano de ação completo + critérios claros para decidir.",
    recommended: true,
    buttonStyle: "bg-[#3b82f6] hover:bg-[#2563eb] text-white",
  },
  {
    type: "Mentoria em Grupo",
    name: "Decisões em Contexto",
    price: "R$ 450",
    period: "/mês",
    highlight: "Escolha este se você quer aprender com decisões reais de outros profissionais.",
    desc: "Aprenda com as decisões de outros profissionais",
    note: null,
    features: [
      "Grupo de 6 a 10 pessoas",
      "2 encontros por mês (90 min cada)",
      "Decisões reais em contexto coletivo",
      "Rede de profissionais em transição",
    ],
    result: "repertório de decisão + rede de pares.",
    recommended: false,
    buttonStyle: "bg-[#0f172a] hover:bg-[#1e293b] text-white",
  },
];

export function Pricing() {
  return (
    <section className="bg-white px-4 py-20" aria-label="Formatos e investimento">
      <div className="max-w-2xl mx-auto">
        <div className="text-center mb-4">
          <h2 className="text-3xl font-extrabold text-[#0f172a] mb-3">Formatos e investimento</h2>
          <p className="text-[#64748b] mb-2">Escolha o formato que faz sentido para sua situação</p>
          <p className="text-[#3b82f6] font-semibold text-sm">
            Primeira sessão de diagnóstico gratuita — depois, decidimos juntos o melhor plano.
          </p>
        </div>
        <div className="flex flex-col gap-6 mt-10">
          {plans.map((plan) => (
            <div
              key={plan.name}
              className={`relative rounded-2xl p-6 border shadow-sm ${
                plan.recommended
                  ? "border-[#3b82f6] border-2"
                  : "border-[#e2e8f0]"
              } bg-white`}
            >
              {plan.recommended && (
                <div className="absolute -top-3.5 left-1/2 -translate-x-1/2 bg-white px-3 py-0.5 text-[#3b82f6] text-xs font-bold border border-[#3b82f6] rounded-full">
                  Recomendado
                </div>
              )}
              <p className="text-[#64748b] text-sm mb-0.5">{plan.type}</p>
              <p className="font-extrabold text-[#0f172a] text-xl mb-3">{plan.name}</p>
              <p className="text-4xl font-extrabold text-[#0f172a] mb-1">
                {plan.price}
                {plan.period && (
                  <span className="text-xl font-medium text-[#64748b]">{plan.period}</span>
                )}
              </p>
              <p className="text-[#3b82f6] text-sm font-medium mb-2">{plan.highlight}</p>
              <p className="text-[#64748b] text-sm mb-3">{plan.desc}</p>
              {plan.note && (
                <p className="text-[#94a3b8] text-xs italic mb-3">{plan.note}</p>
              )}
              <ul className="flex flex-col gap-2 mb-4">
                {plan.features.map((f) => (
                  <li key={f} className="flex items-center gap-2 text-[#0f172a] text-sm">
                    <svg className="w-4 h-4 text-[#3b82f6] shrink-0" fill="none" stroke="currentColor" strokeWidth={2.5} viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                    </svg>
                    {f}
                  </li>
                ))}
              </ul>
              <p className="text-[#94a3b8] text-xs italic mb-5">
                Resultado: {plan.result}
              </p>
              <a
                href={WA_LINK}
                target="_blank"
                rel="noopener noreferrer"
                className={`block text-center font-bold py-3 rounded-full transition-colors ${plan.buttonStyle}`}
              >
                Aplicar para mentoria
              </a>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
