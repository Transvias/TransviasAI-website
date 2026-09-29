import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";

const questions = [
  {
    question: "A ativação da ViA é gratuita?",
    answer:
      "Sim. Transportadoras que já anunciam no Transvias podem ativar a ViA sem custo.",
  },
  {
    question: "Onde eu recebo os pedidos de frete?",
    answer: "Direto no WhatsApp informado neste cadastro.",
  },
  {
    question: "Como eu negocio o frete?",
    answer:
      "Você recebe o pedido, aceita e negocia diretamente pelo WhatsApp.",
  },
  {
    question: "Quem pode participar?",
    answer: "Transportadoras que já anunciam no Transvias.",
  },
  {
    question: "O que acontece depois que eu envio o formulário?",
    answer:
      "A equipe do Transvias entra em contato pelo WhatsApp para ativar a ViA.",
  },
];

export function Faq() {
  return (
    <section className="py-8 mt-12" aria-labelledby="perguntas">
      <h2 id="perguntas" className="text-2xl font-semibold tracking-tight">
        Perguntas e respostas
      </h2>
      <Accordion className="mt-4">
        {questions.map((item) => (
          <AccordionItem key={item.question} className="border-white/15">
            <AccordionTrigger className="py-4 text-base hover:no-underline">
              {item.question}
            </AccordionTrigger>
            <AccordionContent className="text-base leading-relaxed text-foreground/80">
              {item.answer}
            </AccordionContent>
          </AccordionItem>
        ))}
      </Accordion>
    </section>
  );
}
