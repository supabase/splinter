"use client"

import { usePathname } from "next/navigation"
import { Sidebar } from "./sidebar"

export function LayoutWrapper({ children }: { children: React.ReactNode }) {
  const pathname = usePathname()
  const isAuthPage = pathname === "/login"

  if (isAuthPage) {
    return <>{children}</>
  }

  return (
    <>
      <Sidebar />
      <main className="ml-60 min-h-screen p-6">{children}</main>
    </>
  )
}
