"use client";

import { useEffect } from "react";
import { useRouter, useSearchParams } from "next/navigation";

export function AuthRedirect() {
  const router = useRouter();
  const searchParams = useSearchParams();

  useEffect(() => {
    const token_hash = searchParams.get("token_hash");
    const type = searchParams.get("type");
    const code = searchParams.get("code");

    if (token_hash && type) {
      router.replace(`/auth/callback?token_hash=${token_hash}&type=${type}`);
    } else if (code) {
      router.replace(`/auth/callback?code=${code}`);
    }
  }, [router, searchParams]);

  return null;
}
