const forYou = [
  "Você é profissional pleno a sênior travado ou confuso sobre próximos passos",
  "Você está em transição estratégica de carreira",
  "Você precisa decidir: ficar ou sair, aceitar ou recusar, reposicionar-se",
  "Você quer transicionar para Produto com direção clara",
  "Você é junior em transição que acompanha conversas mais maduras",
  "Você é um profissional de tech (produto, design, engenharia, dados) navegando uma decisão estratégica",
];

const notForYou = [
  "Se você quer resposta pronta — eu não dou",
  "Se busca validação constante para se sentir seguro",
  "Se não pretende executar o que decidir",
  "Se quer fórmulas, atalhos ou promessas mágicas",
  "Se procura terapia ou suporte emocional prolongado",
];

export function Qualification() {
  return (
    <section className="bg-[#f8fafc] px-4 py-20" aria-label="Para quem é esta mentoria">
      <div className="max-w-2xl mx-auto">
        <div className="text-center mb-12">
          <h2 className="text-3xl font-extrabold text-[#0f172a] mb-3">
            Isso é para você — ou não é. Seja honesto.
          </h2>
          <p className="text-[#64748b]">Transparência desde o início. Trade-offs explícitos.</p>
        </div>
        <div className="flex flex-col gap-6">
          {/* É para você */}
          <div className="bg-white rounded-2xl p-6 border border-[#e2e8f0] shadow-sm">
            <div className="flex items-center gap-3 mb-4">
              <div className="w-9 h-9 rounded-full bg-blue-50 flex items-center justify-center">
                <svg className="w-5 h-5 text-[#3b82f6]" fill="none" stroke="currentColor" strokeWidth={2.5} viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                </svg>
              </div>
              <h3 className="font-bold text-[#0f172a] text-lg">É para você se...</h3>
            </div>
            <ul className="flex flex-col gap-3">
              {forYou.map((item) => (
                <li key={item} className="flex items-start gap-3 text-[#0f172a] text-sm">
                  <svg className="w-4 h-4 text-[#3b82f6] mt-0.5 shrink-0" fill="none" stroke="currentColor" strokeWidth={2.5} viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                  </svg>
                  {item}
                </li>
              ))}
            </ul>
          </div>

          {/* Não é para você */}
          <div className="bg-white rounded-2xl p-6 border border-red-100 shadow-sm">
            <div className="flex items-center gap-3 mb-4">
              <div className="w-9 h-9 rounded-full bg-red-50 flex items-center justify-center">
                <svg className="w-5 h-5 text-red-500" fill="none" stroke="currentColor" strokeWidth={2.5} viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </div>
              <h3 className="font-bold text-[#0f172a] text-lg">Não é para você se...</h3>
            </div>
            <ul className="flex flex-col gap-3">
              {notForYou.map((item) => (
                <li key={item} className="flex items-start gap-3 text-[#0f172a] text-sm">
                  <svg className="w-4 h-4 text-red-500 mt-0.5 shrink-0" fill="none" stroke="currentColor" strokeWidth={2.5} viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                  {item}
                </li>
              ))}
            </ul>
          </div>
        </div>
      </div>
    </section>
  );
}
