import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase-server";

export const metadata: Metadata = {
  title: "Portal do Mentorado | Mentoria Carreira & Decisão",
  robots: { index: false, follow: false },
};

const navItems = [
  { href: "/portal/dashboard", label: "Início", icon: "grid" },
  { href: "/portal/materiais", label: "Materiais", icon: "book" },
  { href: "/portal/tarefas", label: "Tarefas", icon: "check" },
  { href: "/portal/avaliacao", label: "Avaliação", icon: "chart" },
];

function NavIcon({ name }: { name: string }) {
  switch (name) {
    case "grid":
      return (
        <svg className="w-5 h-5" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24" aria-hidden="true">
          <rect x="3" y="3" width="7" height="7" rx="1" /><rect x="14" y="3" width="7" height="7" rx="1" />
          <rect x="3" y="14" width="7" height="7" rx="1" /><rect x="14" y="14" width="7" height="7" rx="1" />
        </svg>
      );
    case "book":
      return (
        <svg className="w-5 h-5" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24" aria-hidden="true">
          <path strokeLinecap="round" strokeLinejoin="round" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
        </svg>
      );
    case "check":
      return (
        <svg className="w-5 h-5" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24" aria-hidden="true">
          <path strokeLinecap="round" strokeLinejoin="round" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4" />
        </svg>
      );
    default:
      return (
        <svg className="w-5 h-5" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24" aria-hidden="true">
          <path strokeLinecap="round" strokeLinejoin="round" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
        </svg>
      );
  }
}

export default async function PortalLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) redirect("/portal/login");

  async function signOut() {
    "use server";
    const client = await createClient();
    await client.auth.signOut();
    redirect("/portal/login");
  }

  return (
    <div className="min-h-screen bg-[#F7F8FC]">
      {/* Top bar */}
      <header className="fixed top-0 left-0 right-0 h-14 bg-[#0f172a] flex items-center justify-between px-4 sm:px-6 z-50">
        <div className="flex items-center gap-2.5">
          <div className="grid grid-cols-3 gap-0.5 w-5 h-5 shrink-0">
            {[...Array(9)].map((_, i) => (
              <div key={i} className={`rounded-[1px] ${i === 4 ? "bg-[#1E88E5]" : "bg-white"}`} />
            ))}
          </div>
          <span className="text-white font-bold text-sm">Portal do Mentorado</span>
        </div>
        <form action={signOut}>
          <button type="submit" className="text-[#64748b] hover:text-white text-xs transition-colors">
            Sair
          </button>
        </form>
      </header>

      {/* Sidebar — desktop */}
      <aside className="hidden sm:flex fixed left-0 top-14 bottom-0 w-56 bg-white border-r border-[#e2e8f0] flex-col pt-4 z-40">
        <nav className="flex-1 px-3 flex flex-col gap-1">
          {navItems.map(({ href, label, icon }) => (
            <Link
              key={href}
              href={href}
              className="flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium text-[#475569] hover:bg-[#F7F8FC] hover:text-[#0f172a] transition-colors"
            >
              <NavIcon name={icon} />
              {label}
            </Link>
          ))}
        </nav>
        <div className="px-5 py-4 border-t border-[#e2e8f0]">
          <p className="text-[#94a3b8] text-xs text-center">Mentoria Carreira &amp; Decisão</p>
        </div>
      </aside>

      {/* Main content */}
      <main className="sm:ml-56 pt-14 pb-20 sm:pb-0 min-h-screen">
        <div className="p-4 sm:p-8">{children}</div>
      </main>

      {/* Bottom nav — mobile */}
      <nav className="sm:hidden fixed bottom-0 left-0 right-0 bg-white border-t border-[#e2e8f0] flex z-50" aria-label="Navegação principal">
        {navItems.map(({ href, label, icon }) => (
          <Link
            key={href}
            href={href}
            className="flex-1 flex flex-col items-center gap-1 py-2.5 text-[#64748b] hover:text-[#1E88E5] transition-colors"
          >
            <NavIcon name={icon} />
            <span className="text-[10px] font-medium">{label}</span>
          </Link>
        ))}
      </nav>
    </div>
  );
}
