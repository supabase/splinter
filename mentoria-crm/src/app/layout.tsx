import type { Metadata } from "next"
import "./globals.css"
import { LayoutWrapper } from "@/components/layout/layout-wrapper"

export const metadata: Metadata = {
  title: "Mentoria CRM",
  description: "CRM para gestão de leads de mentoria",
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html lang="pt-BR" className="h-full">
      <body className="h-full bg-slate-50">
        <LayoutWrapper>{children}</LayoutWrapper>
      </body>
    </html>
  )
}
