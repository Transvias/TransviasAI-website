"use client";

import Image from "next/image";
import { motion, useMotionValue, useReducedMotion, useSpring, useTransform } from "motion/react";
import { useEffect } from "react";

export function SiteHeader() {
  const reduceMotion = useReducedMotion();
  const pointerX = useMotionValue(0);
  const pointerY = useMotionValue(0);
  const smoothX = useSpring(pointerX, { stiffness: 55, damping: 18, mass: 0.7 });
  const smoothY = useSpring(pointerY, { stiffness: 55, damping: 18, mass: 0.7 });
  const rotateX = useTransform(smoothY, [-0.5, 0.5], [6, -6]);
  const rotateY = useTransform(smoothX, [-0.5, 0.5], [-8, 8]);
  const shiftX = useTransform(smoothX, [-0.5, 0.5], [-18, 18]);
  const shiftY = useTransform(smoothY, [-0.5, 0.5], [-12, 12]);

  useEffect(() => {
    if (reduceMotion) {
      return;
    }

    function onPointerMove(event: PointerEvent) {
      pointerX.set(event.clientX / window.innerWidth - 0.5);
      pointerY.set(event.clientY / window.innerHeight - 0.5);
    }

    window.addEventListener("pointermove", onPointerMove);
    return () => window.removeEventListener("pointermove", onPointerMove);
  }, [pointerX, pointerY, reduceMotion]);

  return (
    <header className="h-[300px] w-full shrink-0 lg:sticky lg:top-0 lg:h-screen lg:w-[30%]">
      <div className="relative h-full overflow-hidden [perspective:900px]">
        <motion.div
          className="absolute -inset-[14%]"
          style={reduceMotion ? undefined : { rotateX, rotateY, x: shiftX, y: shiftY }}
        >
          <div className="relative h-full w-full">
            <Image
              src="/brand/CircuitHighway.jpg"
              alt=""
              fill
              priority
              sizes="(min-width: 1024px) 40vw, 100vw"
              className="object-cover object-center"
            />
          </div>
        </motion.div>
        <div className="pointer-events-none absolute inset-x-0 bottom-0 z-10 h-1/2 bg-gradient-to-b from-transparent to-background" />
        <div className="absolute inset-x-0 bottom-0 z-10 flex justify-center">
          <Image
            src="/brand/Logo-Transvias-AI.svg"
            alt="Transvias AI"
            width={382}
            height={161}
            priority
            className="mb-5 h-[4.25rem] w-auto lg:mb-10 lg:h-20"
          />
        </div>
      </div>
    </header>
  );
}
