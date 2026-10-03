import * as React from "react"
import { cn } from "@/lib/utils"

interface BadgeProps extends React.HTMLAttributes<HTMLSpanElement> {
  color?: string
}

export function Badge({ className, color, style, children, ...props }: BadgeProps) {
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-xs font-semibold",
        className
      )}
      style={{
        backgroundColor: color ? `${color}20` : undefined,
        color: color || undefined,
        ...style,
      }}
      {...props}
    >
      {children}
    </span>
  )
}
