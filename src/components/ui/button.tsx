import * as React from "react";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";

const buttonVariants = cva(
  "inline-flex items-center justify-center gap-2 rounded-md text-sm font-medium transition disabled:pointer-events-none disabled:opacity-45",
  {
    variants: {
      variant: {
        primary:
          "border border-cyan-200/40 bg-cyan-300/14 px-3 py-2 text-cyan-50 shadow-[0_0_18px_rgba(34,211,238,0.15)] hover:bg-cyan-300/22",
        ghost: "px-3 py-2 text-slate-200 hover:bg-white/8",
        danger:
          "border border-rose-300/35 bg-rose-400/12 px-3 py-2 text-rose-100 hover:bg-rose-400/20"
      },
      size: {
        sm: "h-8 px-2.5 text-xs",
        md: "h-10",
        icon: "size-9 p-0"
      }
    },
    defaultVariants: {
      variant: "primary",
      size: "md"
    }
  }
);

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {}

export const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, ...props }, ref) => (
    <button className={cn(buttonVariants({ variant, size }), className)} ref={ref} {...props} />
  )
);

Button.displayName = "Button";
