import { Navbar } from "./_components/Navbar";
import { Hero } from "./_components/Hero";
import { DecisionCanvas } from "./_components/DecisionCanvas";
import { PainPoints } from "./_components/PainPoints";
import { Method } from "./_components/Method";
import { Qualification } from "./_components/Qualification";
import { Mentor } from "./_components/Mentor";
import { Testimonials } from "./_components/Testimonials";
import { Pricing } from "./_components/Pricing";
import { Footer } from "./_components/Footer";

export default function Home() {
  return (
    <>
      <Navbar />
      <main>
        <Hero />
        <DecisionCanvas />
        <PainPoints />
        <Method />
        <Qualification />
        <Mentor />
        <Testimonials />
        <Pricing />
      </main>
      <Footer />
    </>
  );
}
