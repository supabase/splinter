export function DecisionCanvas() {
  const items = [
    { label: "DECISÃO", text: "Qual pergunta você precisa responder?" },
    { label: "OPÇÕES", text: "Quais são os caminhos possíveis?" },
    { label: "CRITÉRIOS", text: "O que importa para você?" },
    { label: "TRADE-OFF", text: "O que você está disposto a abrir mão?" },
    { label: "PRÓXIMO PASSO", text: "Qual ação testável você vai executar?" },
  ];

  return (
    <section className="bg-[#0f172a] px-4 pb-20" aria-label="Decision Canvas — o método">
      <div className="max-w-xl mx-auto">
        <div className="bg-[#1e293b] rounded-2xl p-6 border border-[#334155]">
          <p className="text-[#64748b] text-xs font-semibold tracking-widest uppercase mb-4">
            Decision Canvas
          </p>
          <div className="flex flex-col divide-y divide-[#334155]">
            {items.map(({ label, text }) => (
              <div key={label} className="py-4 first:pt-0 last:pb-0">
                <p className="text-[#64748b] text-xs font-semibold tracking-widest uppercase mb-1">
                  {label}
                </p>
                <p className="text-white text-base">{text}</p>
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
