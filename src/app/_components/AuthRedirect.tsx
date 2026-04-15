"use client";

import { useEffect } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { createClient } from "@/lib/supabase";

export function AuthRedirect() {
  const router = useRouter();
  const searchParams = useSearchParams();

  useEffect(() => {
    // PKCE flow — parâmetros na query string (?token_hash=...&type=...)
    const token_hash = searchParams.get("token_hash");
    const type = searchParams.get("type");
    const code = searchParams.get("code");

    if (token_hash && type) {
      router.replace(`/auth/callback?token_hash=${token_hash}&type=${type}`);
      return;
    }
    if (code) {
      router.replace(`/auth/callback?code=${code}`);
      return;
    }

    // Implicit flow — parâmetros no hash (#access_token=...)
    const hash = window.location.hash;
    if (hash && hash.includes("access_token")) {
      const supabase = createClient();
      const { data: { subscription } } = supabase.auth.onAuthStateChange(
        (event, session) => {
          if (session && (event === "SIGNED_IN" || event === "USER_UPDATED")) {
            subscription.unsubscribe();
            router.replace("/portal/dashboard");
          }
        }
      );
    }
  }, [router, searchParams]);

  return null;
}
