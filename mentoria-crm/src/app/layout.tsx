import type { Metadata } from "next"
import "./globals.css"
import { Sidebar } from "@/components/layout/sidebar"

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
        <Sidebar />
        <main className="ml-60 min-h-screen p-6">{children}</main>
      </body>
    </html>
  )
}
