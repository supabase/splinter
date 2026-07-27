const pains = [
  {
    quote: '"Estou travado e toda opção parece ruim"',
    sub: "Paralisia por excesso de análise ou medo de errar",
  },
  {
    quote: '"Quero transicionar para Produto mas não sei como me posicionar"',
    sub: "Vindo de CX, Design, Engenharia ou outras áreas",
  },
  {
    quote: '"Preciso tomar decisões profissionais com clareza"',
    sub: "Aceitar proposta, pedir promoção, mudar de empresa",
  },
  {
    quote: '"Quero crescer sem virar refém de validação"',
    sub: "Autonomia sobre sua própria carreira",
  },
  {
    quote: '"Tenho dúvidas recorrentes e não consigo agir"',
    sub: "O loop de indecisão que drena energia",
  },
  {
    quote: '"Recebi uma proposta e tenho poucos dias para decidir"',
    sub: "A pressão do prazo sem critério claro para avaliar",
  },
];

export function PainPoints() {
  return (
    <section className="bg-[#f8fafc] px-4 py-20" aria-label="Dores comuns de quem busca mentoria">
      <div className="max-w-2xl mx-auto">
        <div className="text-center mb-12">
          <h2 className="text-3xl font-extrabold text-[#0f172a] mb-3">
            Se você se reconhece aqui
          </h2>
          <p className="text-[#64748b]">Esses são os dilemas mais comuns de quem me procura</p>
        </div>
        <div className="flex flex-col gap-4">
          {pains.map(({ quote, sub }) => (
            <div
              key={quote}
              className="bg-white rounded-2xl p-5 border border-[#e2e8f0] shadow-sm"
            >
              <p className="font-bold text-[#0f172a] mb-1">{quote}</p>
              <p className="text-[#64748b] text-sm">{sub}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
