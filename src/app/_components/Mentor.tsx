const credentials = [
  { icon: "💼", text: "Senior Product Manager na Amazon" },
  { icon: "📈", text: "Experiência em produto, growth, inovação e UX/CX" },
  { icon: "👥", text: "+50 profissionais mentorados em decisões de carreira" },
  { icon: "🎯", text: "Atuação em contextos ambíguos com informação incompleta" },
];

export function Mentor() {
  return (
    <section className="bg-white px-4 py-20" aria-label="Quem é o mentor">
      <div className="max-w-2xl mx-auto">
        <div className="flex flex-col gap-6">
          <div className="flex flex-col items-start gap-4 sm:flex-row sm:items-center">
            <div className="w-32 h-32 rounded-2xl bg-[#e2e8f0] overflow-hidden shrink-0 flex items-center justify-center">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src="/foto-caiman.jpg"
                alt="Caiman Oliveira — Senior PM Amazon e mentor de carreira"
                className="w-full h-full object-cover"
              />
            </div>
            <div>
              <p className="text-[#64748b] text-xs font-semibold tracking-widest uppercase mb-1">
                Quem Mentora
              </p>
              <h2 className="text-2xl font-extrabold text-[#0f172a]">
                Por que confiar em mim para decidir?
              </h2>
            </div>
          </div>
          <ul className="flex flex-col gap-3">
            {credentials.map(({ icon, text }) => (
              <li key={text} className="flex items-center gap-3 text-[#0f172a]">
                <span className="text-xl w-7 shrink-0">{icon}</span>
                <span className="text-sm sm:text-base">{text}</span>
              </li>
            ))}
          </ul>
          <p className="text-[#64748b] leading-relaxed">
            Eu trabalho com produto e carreira do mesmo jeito: clareza, trade-offs e execução. A
            mentoria não é para te motivar — é para te dar direção.
          </p>
          <p className="text-[#3b82f6] font-semibold italic">&ldquo;Autonomia, não dependência.&rdquo;</p>
        </div>
      </div>
    </section>
  );
}
