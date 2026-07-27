import { LanguageSwitcher } from '@/components/layout/language-switcher';

export default function AuthLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex min-h-screen">
      {/* Brand panel */}
      <div className="relative hidden w-1/2 flex-col justify-between bg-sidebar p-12 text-white lg:flex">
        <div className="flex items-center gap-2">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/logo.png" alt="Fynexa" className="h-10 w-10" />
          <span className="text-xl font-bold">Fynexa</span>
        </div>
        <div>
          <h2 className="text-3xl font-bold leading-tight">
            Prenez le contrôle de vos finances.
          </h2>
          <p className="mt-4 max-w-md text-white/60">
            Suivez vos revenus, dépenses et budgets, et laissez le coach IA vous aider à
            épargner davantage.
          </p>
        </div>
        <p className="text-sm text-white/40">© {new Date().getFullYear()} Fynexa</p>
      </div>

      {/* Form panel */}
      <div className="flex w-full flex-col lg:w-1/2">
        <div className="flex justify-end p-6">
          <LanguageSwitcher />
        </div>
        <div className="flex flex-1 items-center justify-center px-6 pb-16">
          <div className="w-full max-w-sm">{children}</div>
        </div>
      </div>
    </div>
  );
}
