export default function BrandLogo({ compact = false, className = '' }) {
  const iconSize = compact ? 'h-8 w-8' : 'h-10 w-10';
  const textSize = compact ? 'text-xl' : 'text-2xl sm:text-3xl';

  return (
    <div role="img" aria-label="TimeBoxer" className={`inline-flex items-center gap-2.5 ${className}`}>
      <svg className={`${iconSize} shrink-0 text-[#35d532]`} viewBox="0 0 48 48" fill="none" aria-hidden="true">
        <path d="M24 4 42 14.5v19L24 44 6 33.5v-19L24 4Z" stroke="currentColor" strokeWidth="3.2" strokeLinejoin="round" />
        <path d="m6.8 14.8 17.2 10 17.2-10M24 24.8V44" stroke="currentColor" strokeWidth="3.2" strokeLinejoin="round" />
      </svg>
      <div className={`${textSize} whitespace-nowrap font-black italic leading-none tracking-[-0.06em]`}>
        <span className="bg-gradient-to-b from-slate-500 to-slate-800 bg-clip-text text-transparent">TIME</span>
        <span className="text-[#35d532]">BOXER</span>
      </div>
    </div>
  );
}
