import { NextRequest, NextResponse } from "next/server"

export async function POST(request: NextRequest) {
  const phone = process.env.CALLMEBOT_PHONE
  const apiKey = process.env.CALLMEBOT_API_KEY

  if (!phone || !apiKey) {
    return NextResponse.json(
      { error: "WhatsApp não configurado. Defina CALLMEBOT_PHONE e CALLMEBOT_API_KEY no .env.local" },
      { status: 400 }
    )
  }

  const body = await request.json()
  const { leadName, meetingTitle, date, time, link } = body

  const dateFormatted = new Date(date + "T00:00:00").toLocaleDateString("pt-BR", {
    weekday: "long",
    day: "2-digit",
    month: "long",
  })

  let message = `📅 *Lembrete de Reunião — Mentoria CRM*\n\n`
  message += `👤 Lead: *${leadName}*\n`
  message += `📌 ${meetingTitle}\n`
  message += `🗓 ${dateFormatted} às ${time}\n`
  if (link) message += `🔗 ${link}\n`

  const url = new URL("https://api.callmebot.com/whatsapp.php")
  url.searchParams.set("phone", phone)
  url.searchParams.set("text", message)
  url.searchParams.set("apikey", apiKey)

  try {
    const response = await fetch(url.toString())
    if (!response.ok) {
      return NextResponse.json({ error: "Falha ao enviar mensagem" }, { status: 500 })
    }
    return NextResponse.json({ success: true })
  } catch {
    return NextResponse.json({ error: "Erro de rede ao contatar CallMeBot" }, { status: 500 })
  }
}
