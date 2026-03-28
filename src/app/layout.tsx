import type { Metadata } from "next";
import "./globals.css";

const SITE_URL = "https://mentoria.caimanoliveira.com";

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: {
    default: "Mentoria de Carreira & Decisão | Caiman Oliveira",
    template: "%s | Mentoria de Carreira & Decisão",
  },
  description:
    "Mentoria de carreira para profissionais de tech que precisam tomar decisões estratégicas com clareza. Método Decision Canvas. Senior PM Amazon. Primeira sessão gratuita.",
  keywords: [
    "mentoria de carreira",
    "transição de carreira",
    "product manager",
    "decisão de carreira",
    "mentoria tech",
    "Decision Canvas",
    "mentoria PM",
    "carreira em produto",
    "mentoria profissional",
    "clareza de carreira",
  ],
  authors: [{ name: "Caiman Oliveira" }],
  creator: "Caiman Oliveira",
  openGraph: {
    type: "website",
    locale: "pt_BR",
    url: SITE_URL,
    siteName: "Mentoria de Carreira & Decisão",
    title: "Decisões de carreira não precisam de mais informação. Precisam de método.",
    description:
      "O Decision Canvas transforma dilemas paralisantes em decisões claras — com critérios explícitos, trade-offs reais e um próximo passo executável. Senior PM Amazon • +50 profissionais mentorados.",
  },
  twitter: {
    card: "summary_large_image",
    title: "Mentoria de Carreira & Decisão | Caiman Oliveira",
    description:
      "Método Decision Canvas para decisões de carreira claras. Primeira sessão de diagnóstico gratuita.",
  },
  alternates: {
    canonical: SITE_URL,
  },
  robots: {
    index: true,
    follow: true,
    googleBot: { index: true, follow: true },
  },
};

const jsonLd = {
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "Person",
      "@id": `${SITE_URL}/#mentor`,
      name: "Caiman Oliveira",
      jobTitle: "Senior Product Manager",
      worksFor: { "@type": "Organization", name: "Amazon" },
      description:
        "Senior Product Manager na Amazon com experiência em produto, growth, inovação e UX/CX. Mentor de carreira especializado no método Decision Canvas para profissionais de tech.",
      knowsAbout: [
        "Product Management",
        "Career Mentorship",
        "Decision Making",
        "Career Transition",
        "UX/CX",
        "Growth",
      ],
      email: "mentoriacarreiraedecisao@gmail.com",
      url: SITE_URL,
    },
    {
      "@type": "Service",
      "@id": `${SITE_URL}/#service`,
      name: "Mentoria de Carreira & Decisão",
      provider: { "@id": `${SITE_URL}/#mentor` },
      description:
        "Mentoria individual para profissionais de tech (produto, design, engenharia, dados) que precisam tomar decisões estratégicas de carreira com clareza. Usando o método Decision Canvas.",
      serviceType: "Career Mentoring",
      areaServed: { "@type": "Country", name: "Brazil" },
      inLanguage: "pt-BR",
      offers: [
        {
          "@type": "Offer",
          name: "Sessão Única — Decisão",
          price: "600",
          priceCurrency: "BRL",
          description: "1 sessão de 90 minutos com foco em 1 decisão real usando o Decision Canvas.",
        },
        {
          "@type": "Offer",
          name: "Ciclo 1:1 — Travessia",
          price: "2000",
          priceCurrency: "BRL",
          description: "4 sessões de 60 minutos em 4 a 6 semanas com suporte assíncrono e kits específicos.",
        },
        {
          "@type": "Offer",
          name: "Mentoria em Grupo — Decisões em Contexto",
          price: "450",
          priceCurrency: "BRL",
          description: "Grupo de 6 a 10 pessoas, 2 encontros por mês de 90 min. Decisões reais em contexto coletivo.",
        },
      ],
    },
    {
      "@type": "FAQPage",
      mainEntity: [
        {
          "@type": "Question",
          name: "O que é mentoria de carreira?",
          acceptedAnswer: {
            "@type": "Answer",
            text: "Mentoria de carreira é um processo estruturado onde um profissional experiente ajuda outro a tomar decisões estratégicas de carreira com clareza, usando critérios explícitos e trade-offs reais.",
          },
        },
        {
          "@type": "Question",
          name: "O que é o Decision Canvas?",
          acceptedAnswer: {
            "@type": "Answer",
            text: "O Decision Canvas é um framework que transforma dilemas paralisantes em decisões claras. Ele trabalha com 5 dimensões: a decisão principal, as opções disponíveis, os critérios que importam para você, os trade-offs que está disposto a aceitar, e o próximo passo executável.",
          },
        },
        {
          "@type": "Question",
          name: "Para quem é esta mentoria?",
          acceptedAnswer: {
            "@type": "Answer",
            text: "Para profissionais plenos a sêniores de tech (produto, design, engenharia, dados) que estão travados em decisões de carreira: transições, promoções, mudanças de empresa, reposicionamento estratégico.",
          },
        },
        {
          "@type": "Question",
          name: "Qual o valor da mentoria?",
          acceptedAnswer: {
            "@type": "Answer",
            text: "Sessão Única (Decisão): R$ 600. Ciclo 1:1 Travessia: R$ 2.000. Mentoria em Grupo: R$ 450/mês. A primeira sessão de diagnóstico é gratuita.",
          },
        },
        {
          "@type": "Question",
          name: "Como funciona a primeira sessão gratuita?",
          acceptedAnswer: {
            "@type": "Answer",
            text: "A primeira sessão é um diagnóstico gratuito, sem compromisso. Você explica sua situação e juntos identificamos qual é a decisão real que você precisa tomar. Depois decidimos o melhor formato para o seu caso.",
          },
        },
      ],
    },
  ],
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="pt-BR">
      <head>
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
        />
      </head>
      <body className="min-h-full flex flex-col">{children}</body>
    </html>
  );
}
