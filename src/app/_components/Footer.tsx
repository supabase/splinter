const WA_LINK = "https://wa.me/5511940347276";

export function Footer() {
  return (
    <>
      {/* Final CTA */}
      <section
        className="bg-[#0f172a] text-white px-4 py-20 text-center"
        aria-label="Chamada para ação final"
      >
        <div className="max-w-md mx-auto flex flex-col items-center gap-6">
          <h2 className="text-3xl font-extrabold">Pronto para decidir com clareza?</h2>
          <p className="text-[#94a3b8]">
            Se você está travado em uma decisão importante de carreira, vamos conversar.
            Sem compromisso. Sem pressão.
          </p>
          <a
            href={WA_LINK}
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-2 bg-[#3b82f6] hover:bg-[#2563eb] text-white font-bold px-8 py-4 rounded-full transition-colors w-full max-w-xs justify-center"
          >
            Aplicar para mentoria →
          </a>
          <a
            href={WA_LINK}
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-2 text-[#94a3b8] hover:text-white transition-colors text-sm"
          >
            <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 24 24" aria-hidden="true">
              <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347z" /><path d="M12 0C5.373 0 0 5.373 0 12c0 2.123.554 4.118 1.528 5.852L0 24l6.335-1.508A11.95 11.95 0 0012 24c6.627 0 12-5.373 12-12S18.627 0 12 0zm0 22c-1.885 0-3.65-.49-5.19-1.352l-.37-.214-3.762.896.953-3.67-.242-.384A9.944 9.944 0 012 12C2 6.477 6.477 2 12 2s10 4.477 10 10-4.477 10-10 10z" />
            </svg>
            Conversar no WhatsApp
          </a>
          <address className="not-italic text-[#64748b] text-sm">
            <a
              href="mailto:mentoriacarreiraedecisao@gmail.com"
              className="flex items-center gap-2 hover:text-[#94a3b8] transition-colors justify-center"
            >
              <svg className="w-4 h-4" fill="none" stroke="currentColor" strokeWidth={1.5} viewBox="0 0 24 24" aria-hidden="true">
                <path strokeLinecap="round" strokeLinejoin="round" d="M21.75 6.75v10.5a2.25 2.25 0 01-2.25 2.25h-15a2.25 2.25 0 01-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0019.5 4.5h-15a2.25 2.25 0 00-2.25 2.25m19.5 0v.243a2.25 2.25 0 01-1.07 1.916l-7.5 4.615a2.25 2.25 0 01-2.36 0L3.32 8.91a2.25 2.25 0 01-1.07-1.916V6.75" />
              </svg>
              mentoriacarreiraedecisao@gmail.com
            </a>
          </address>
        </div>
      </section>

      {/* Footer */}
      <footer className="bg-white border-t border-[#e2e8f0] px-4 py-8">
        <div className="max-w-5xl mx-auto flex flex-col items-center gap-4">
          <div className="flex items-center gap-3">
            <div className="grid grid-cols-3 gap-0.5 w-8 h-8">
              {[...Array(9)].map((_, i) => (
                <div
                  key={i}
                  className={`rounded-sm ${i === 4 ? "bg-[#3b82f6]" : "bg-[#0f172a]"}`}
                />
              ))}
            </div>
            <div>
              <p className="font-bold text-[#0f172a] text-sm leading-tight">Mentoria</p>
              <p className="text-[#64748b] text-xs leading-tight">Carreira &amp; Decisão</p>
            </div>
          </div>
          <nav className="flex gap-6 text-sm text-[#64748b]" aria-label="Links do rodapé">
            <a
              href={WA_LINK}
              target="_blank"
              rel="noopener noreferrer"
              className="hover:text-[#0f172a] transition-colors"
            >
              WhatsApp
            </a>
            <a
              href="mailto:mentoriacarreiraedecisao@gmail.com"
              className="hover:text-[#0f172a] transition-colors"
            >
              Email
            </a>
          </nav>
          <p className="text-[#94a3b8] text-xs">
            &copy; {new Date().getFullYear()} Caiman Oliveira. Todos os direitos reservados.
          </p>
        </div>
      </footer>
    </>
  );
}
