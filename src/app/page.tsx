import { Faq } from "@/components/faq";
import { HowItWorks } from "@/components/how-it-works";
import { LeadForm } from "@/components/lead-form";
import { SiteHeader } from "@/components/site-header";

function firstParam(value: string | string[] | undefined) {
  const raw = Array.isArray(value) ? value[0] : value;
  return raw?.trim() ?? "";
}

export default async function Home({ searchParams }: PageProps<"/">) {
  const params = await searchParams;
  const transportadora = firstParam(params.transportadora).slice(0, 120);
  const transportadoraIdParam = firstParam(params.id);
  const transportadoraId = /^\d{1,12}$/.test(transportadoraIdParam) ? transportadoraIdParam : "";

  return (
    <div className="flex min-h-full w-full flex-col lg:min-h-screen lg:flex-row">
      <SiteHeader />

      <div className="flex w-full flex-col lg:w-[70%]">
        <main className="w-full max-w-4xl px-5 lg:px-14 lg:py-6 xl:px-20">
          <section className="pt-8 pb-2 lg:pt-14">
            <h1 className="text-[1.75rem] leading-tight font-semibold tracking-tight lg:text-5xl mb-8">
              Conheça a ViA, a nova agente inteligente do Transvias.
            </h1>
            <p className="mt-4 text-base leading-relaxed text-foreground/80 lg:text-lg max-w-2xl">
              Agora você pode responder pedidos de fretes diretamente do seu WhatsApp. <br />
              A ViA traz mais facilidade e oportunidades para o seu negócio.
            </p>
          </section>

          <HowItWorks />

          <section id="ativar" className="scroll-mt-6 py-8" aria-labelledby="ativar-titulo">
            <h2 id="ativar-titulo" className="text-2xl font-semibold tracking-tight">
              Ative a ViA
            </h2>
            <p className="mt-2 mb-6 text-base leading-relaxed text-foreground/80">
              Preencha para receber a ativação no seu WhatsApp.
            </p>
            <LeadForm transportadora={transportadora} transportadoraId={transportadoraId} />
          </section>

          <Faq />
        </main>

        <footer className="mt-auto w-full max-w-4xl px-5 py-10 text-center text-sm text-foreground/60 lg:px-14 lg:text-left xl:px-20">
          Copyright 2026 - Transvias - Todos os direitos reservados. Reprodução Proibida.
        </footer>
      </div>
    </div>
  );
}
