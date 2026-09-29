const steps = [
  "Ative a ViA gratuitamente",
  "Receba pedidos de fretes",
  "Aceite e negocie diretamente",
];

export function HowItWorks() {
  return (
    <section className="py-8 max-w-2xl" aria-labelledby="como-funciona">
      <h2 id="como-funciona" className="text-2xl font-semibold tracking-tight">
        Como funciona
      </h2>
      <ol className="flex flex-col gap-5 mt-12 lg:grid lg:grid-cols-3 lg:gap-8">
        {steps.map((step, index) => (
          <li key={step} className="flex items-center gap-4 lg:flex-col lg:gap-3 lg:text-center">
            <span className="flex size-9 shrink-0 items-center justify-center rounded-full bg-primary text-sm font-semibold text-primary-foreground">
              {index + 1}
            </span>
            <p className="text-base leading-snug lg:max-w-30">{step}</p>
          </li>
        ))}
      </ol>
    </section>
  );
}
