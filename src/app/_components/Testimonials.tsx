const testimonials = [
  {
    quote:
      "A forma como ele estrutura o pensamento é impressionante. Saí da sessão com uma clareza que não tinha há meses.",
    author: "Product Designer em transição para PM",
  },
  {
    quote:
      "Me preparou para entrevistas de um jeito muito diferente. Não decorei respostas, entendi a estratégia por trás de cada pergunta.",
    author: "Analista de CX → Product Manager",
  },
  {
    quote:
      "Hypothesis-driven, data-informed. Foi a primeira vez que alguém me ajudou a pensar em carreira como se pensa em produto.",
    author: "Senior PM em Big Tech",
  },
  {
    quote:
      "A didática e paciência são raras. Ele não dá resposta — te ensina a chegar nela.",
    author: "Tech Lead considerando transição",
  },
  {
    quote: "Finalmente alguém que não me vendeu sonhos. Trade-offs reais, decisões reais.",
    author: "Gerente de Projetos em reposicionamento",
  },
];

export function Testimonials() {
  return (
    <section className="bg-[#f8fafc] px-4 py-20" aria-label="Depoimentos de mentorados">
      <div className="max-w-2xl mx-auto">
        <div className="text-center mb-12">
          <h2 className="text-3xl font-extrabold text-[#0f172a] mb-3">O que dizem</h2>
          <p className="text-[#64748b]">Depoimentos de pessoas que passaram pelo processo</p>
        </div>
        <div className="flex flex-col gap-4">
          {testimonials.map(({ quote, author }) => (
            <article
              key={author}
              className="bg-white rounded-2xl p-6 border border-[#e2e8f0] shadow-sm"
              itemScope
              itemType="https://schema.org/Review"
            >
              <p className="text-[#0f172a] leading-relaxed mb-3 italic" itemProp="reviewBody">
                &ldquo;{quote}&rdquo;
              </p>
              <p className="text-[#64748b] text-sm" itemProp="author">
                — {author}
              </p>
            </article>
          ))}
        </div>
        <p className="text-center text-[#64748b] text-sm mt-8 font-semibold tracking-wide uppercase">
          Senior PM na Amazon · +50 profissionais mentorados
        </p>
      </div>
    </section>
  );
}
